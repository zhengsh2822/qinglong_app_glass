import 'dart:async';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

/// ============================================================
/// 液态玻璃导航条 —— App 版（移植自 demos/liquid_glass_demo）
///
/// 核心设计（与 demo 一致）：
///  1. 滑块动画由 Flutter 内置 [AnimationController] 驱动（对齐顶部 tab
///     的做法）：快速切换时 controller 不中断、从当前实时视觉平滑接管新目标，
///     避免自定义 Ticker 频繁 stop/start 导致的卡顿。
///  2. 边界挤压等效公式（形变原点始终为中心）：
///       右边界溢出：translateX = maxX + compressRatio * 50
///       左边界溢出：translateX = -compressRatio * 50
///  3. 统一底层 Listener 监听指针，5px 阈值区分 拖拽/点击。
///  4. 拖拽过程中滑块划过哪个按钮，该按钮立即变 active（预览），
///     但 **只有松手才提交切换**（commit → onSelected），切页面发生在松手后。
///  5. 按压即轻微缩小（抓取预备反馈）；长按 500ms 进一步缩小到 0.85（抓取），
///     随后可拖动小胶囊，松手恢复 1.0。
///  6. 支持 onLongTap（按下 500ms 未移动触发）；长按同时进入抓取状态，之后
///     仍可拖动（不再像旧版那样阻止拖动）。
///  7. 图标为 IconData（与 demo 一致），文字随 active 变色。
/// ============================================================

/// 一帧滑块的实时视觉状态（百分比 + 缩放系数）。
class LiquidVisual {
  /// 滑块中心相对第 0 个 item 中心的位置，单位 %（0/100/200/300）。
  final double p;
  final double scaleX;
  final double scaleY;

  const LiquidVisual(this.p, {this.scaleX = 1.0, this.scaleY = 1.0});
}

/// 外部数据模型：label + 图标（与 demo 一致，IconData 随 active 着色）。
class LiquidNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const LiquidNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// ============================================================
/// 组件本体
/// ============================================================
class LiquidGlassNavBar extends StatefulWidget {
  final List<LiquidNavItem> items;
  final int initialIndex;
  final ValueChanged<int>? onSelected;

  /// 长按回调（按下 500ms 未移动触发）；触发后松手不再切换
  final ValueChanged<int>? onLongTap;

  final double dragThreshold;

  final Color activeColor;
  final Color inactiveColor;

  /// 大胶囊背景色（毛玻璃关闭 / demo 纯色模式使用）
  final Color barColor;

  /// 是否启用大胶囊毛玻璃（BackdropFilter 高斯模糊）
  final bool barGlass;

  /// 毛玻璃开启时大胶囊的半透明背景色
  final Color barGlassColor;

  /// 大胶囊边框
  final Border? barBorder;

  /// 大胶囊投影（null 用默认柔和同色投影）
  final List<BoxShadow>? barShadow;

  /// 小胶囊滑块颜色
  final Color sliderColor;

  /// 滑块边框
  final Border? sliderBorder;

  /// 滑块顶部高光（null 去掉）
  final Color? sliderTopGlow;

  /// 滑块底部内发光（null 去掉）
  final Color? sliderBottomGlow;

  /// 内部内容 padding
  final double padding;

  /// 文字大小
  final double labelSize;

  /// 图标大小
  final double iconSize;

  /// 滑块最大挤压 30%
  static const double _kMaxCompress = 0.30;

  /// 长按抓取时小胶囊缩小的目标比例（0.85，可看出被"抓取"）
  static const double _kGrabbedScale = 0.85;

  /// 长按判定时长
  static const Duration _kLongTapDuration = Duration(milliseconds: 500);

  const LiquidGlassNavBar({
    Key? key,
    required this.items,
    this.initialIndex = 0,
    this.onSelected,
    this.onLongTap,
    this.dragThreshold = 5,
    this.activeColor = Colors.black,
    this.inactiveColor = const Color(0xFF7B7B7B),
    this.barColor = Colors.white,
    this.barGlass = false,
    this.barGlassColor = Colors.transparent,
    this.barBorder,
    this.barShadow,
    this.sliderColor = Colors.transparent,
    this.sliderBorder,
    this.sliderTopGlow,
    this.sliderBottomGlow,
    this.padding = 6,
    this.labelSize = 11,
    this.iconSize = 22,
  }) : super(key: key);

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with TickerProviderStateMixin {
  late int _currentIndex;

  /// hover 预览下标（ValueNotifier 驱动，切换只重建文字层，不动大胶囊）
  final ValueNotifier<int> _hover = ValueNotifier<int>(0);

  Offset _downLocal = Offset.zero;
  bool _isInteracting = false;
  bool _isDragging = false;
  bool _longTapFired = false;
  Timer? _longTapTimer;

  // 实时视觉（百分比 + 缩放）
  // GPU 优化：滑块视觉由 ValueNotifier 驱动，动画期间只重建滑块层，
  // 大胶囊 + 图标文字等静态层不会每帧重建（对齐顶部 tab 的优化思路）。
  final ValueNotifier<LiquidVisual> _visual = ValueNotifier(
    const LiquidVisual(0),
  );

  // 位置动画：值直接映射滑块位置（%），用 animateTo 从当前动画值继续，
  // 快速连续切换时不重置、平滑接管新目标 —— 与 demo 一致，跟手流畅。
  late final AnimationController _pos;

  // 回弹挤压：0..1，0=挤压态，1=恢复（1.0/1.0）。挤压深度按 _lastAmp 缩放，
  // 位移越大挤压越明显（回弹力度随距离反馈）。
  late final AnimationController _sq;

  // 抓取缩放：0..1，0=正常（1.0），1=长按抓取（0.85）。
  // 按压时轻微缩小（0.5），长按后进一步缩小（1.0）作为"抓取"反馈，随后可拖动。
  late final AnimationController _grab;

  // 最近一次切换的回弹幅度（0.35~1.0）：挤压深度 + 过墙幅度都随它缩放
  double _lastAmp = 1.0;

  // 回弹序列令牌：新的切换会使旧序列的"落回阶段"失效，避免位置回跳。
  int _reboundToken = 0;

  // 按下原点（回弹距离/方向依据）：_currentIndex 在 _commit 会被覆盖成 target，
  // 故回弹必须用按下时滑块的真实位置来计算"真实导航距离"。
  double _pressP = 0;

  // 按下是否已触发切换（用于松手 tap 时避免对已切目标重复提交造成二次回弹）
  bool _downSwitched = false;

  // Layout 阶段记录的尺寸
  double _lastContentW = 0;
  bool _sizeInited = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _hover.value = _currentIndex;
    _pos = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      // 值直接映射滑块位置%（0/100/200/300）；放宽范围以容纳边界 tab
      // "冲撞过墙"的位置（-50 ~ maxP+50），否则过墙值被上界截断看不到回弹。
      lowerBound: -50,
      upperBound: (widget.items.length - 1) * 100.0 + 50,
    )..addListener(_onTick);
    _sq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_onTick);
    _grab = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(_onTick);
    _pos.value = _currentIndex * 100.0;
    // 初始滑块不挤压（_sq=1）
    _sq.value = 1.0;
  }

  /// 抓取缩放系数：0=正常 1.0，1=长按抓取 0.85
  double get _grabScale =>
      lerpDouble(1.0, LiquidGlassNavBar._kGrabbedScale, _grab.value) ?? 1.0;

  /// 动画每帧回调：位置 + 回弹挤压（深度随 _lastAmp）+ 抓取缩放写入 ValueNotifier
  void _onTick() {
    final double gs = _grabScale;
    // _sq=0 → 挤压态，深度随 _lastAmp：scaleX=1-0.22*amp，scaleY=1+0.05*amp
    final double sq = 1.0 - _sq.value;
    final double sx = 1.0 - 0.22 * _lastAmp * sq;
    final double sy = 1.0 + 0.05 * _lastAmp * sq;
    _visual.value = LiquidVisual(
      _pos.value,
      scaleX: sx * gs,
      scaleY: sy * gs,
    );
  }

  @override
  void didUpdateWidget(LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部驱动切换（如通知/深链跳转）：跟随吸附，但不触发 onSelected
    final newIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    if (newIndex != oldWidget.initialIndex && newIndex != _currentIndex) {
      _hover.value = newIndex;
      _commit(newIndex, notify: false);
    }
  }

  @override
  void dispose() {
    _longTapTimer?.cancel();
    _pos.dispose();
    _sq.dispose();
    _grab.dispose();
    _visual.dispose();
    _hover.dispose();
    super.dispose();
  }

  // ---------- 手势 ----------

  void _onPointerDown(PointerDownEvent e) {
    _isInteracting = true;
    _isDragging = false;
    _longTapFired = false;
    _pos.stop();
    _sq.stop();
    _downLocal = e.localPosition;
    // 记录按下原点：用于回弹的"真实导航距离/方向"（_currentIndex 在 _commit 里
    // 会先被覆盖成 target，不能拿来算回弹距离）
    _pressP = _visual.value.p;
    // 按下立即切页（最快）：落到不同 tab 就直接 onSelected 切页 + 平滑滑动，
    // 不等松手/长按，杜绝"长按延迟跳转"。同 tab 按下仅保留抓取预备反馈。
    final int downTarget = _indexAt(e.localPosition.dx);
    _hover.value = downTarget;
    _downSwitched = downTarget != _currentIndex;
    if (_downSwitched) {
      // 按下立即切页（最快）：起手仅"平滑滑动"，二段回弹留到松手再决定
      _commit(downTarget, bounce: false);
    }
    // 按压即轻微缩小（抓取预备反馈）
    _grab.animateTo(
      0.5,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
    // 长按计时：到达后进入"抓取"（小胶囊缩小），并可继续拖动。
    // 长按（未移动）立即跳转到按住的标签，避免"要滑动一下才跳"造成的
    // 小胶囊卡顿闪现；只有滑动选择（拖动）时才松手再跳转。
    _longTapTimer?.cancel();
    _longTapTimer = Timer(LiquidGlassNavBar._kLongTapDuration, () {
      if (!mounted || !_isInteracting || _isDragging) return;
      _longTapFired = true;
      _longTapTimer?.cancel();
      final target = _indexAt(e.localPosition.dx);
      _hover.value = target;
      widget.onLongTap?.call(target);
      if (target != _currentIndex) {
        // 长按不同标签：立即跳转（切换页面 + 回弹），不依赖后续拖动
        _commit(target);
      }
      // 长按：小胶囊缩小（抓取），随后可动画拖拽
      _grab.animateTo(
        1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  /// 把手指 x 坐标换算成"滑块中心 %"（未挤压）。
  double _rawPFromFinger(double localDx) {
    if (_lastContentW <= 0) return 0;
    final p = ((localDx - widget.padding) / _lastContentW).clamp(0.0, 1.0);
    final n = widget.items.length.toDouble();
    if (n <= 1) return 0;
    return (p - 0.5 / n) / (1 - 1 / n) * (n - 1) * 100.0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_isInteracting) return;
    final dx = (e.localPosition - _downLocal).dx;
    if (!_isDragging) {
      if (dx.abs() < widget.dragThreshold) return;
      _isDragging = true;
      _longTapTimer?.cancel();
      // 打断"按下即跳转"预览动画，改由手指直接驱动
      _pos.stop();
      _sq.stop();
    }

    final rawP = _rawPFromFinger(e.localPosition.dx);
    final maxP = (widget.items.length - 1) * 100.0;

    final double outP;
    double outScaleX = 1.0;
    if (rawP < 0) {
      final overflow = -rawP;
      final compress = _compressFor(overflow);
      outScaleX = 1 - compress;
      outP = -compress * 50;
    } else if (rawP > maxP) {
      final overflow = rawP - maxP;
      final compress = _compressFor(overflow);
      outScaleX = 1 - compress;
      outP = maxP + compress * 50;
    } else {
      outP = rawP;
    }

    final newHover = _indexAt(e.localPosition.dx);
    // 滑块视觉走 ValueNotifier（拖动实时跟随，带抓取缩放）；hover 只更新文字层
    final double gs = _grabScale;
    _visual.value = LiquidVisual(
      outP,
      scaleX: outScaleX * gs,
      scaleY: gs,
    );
    if (newHover != _hover.value) {
      _hover.value = newHover;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_isInteracting) return;
    _longTapTimer?.cancel();
    if (_longTapFired) {
      // 已长按（抓取）：拖拽过就提交切换，否则只恢复（onLongTap 动作已触发）
      if (_isDragging) {
        _commit(_hover.value);
      }
    } else if (!_isDragging) {
      // 未超阈值 → 判定为点击
      final target = _indexAt(e.localPosition.dx);
      if (_downSwitched) {
        // 按下已切页（平滑滑动），快速点击松手补一段"二段回弹"；
        // 长按时 _longTapFired 走上面分支，此处不触发 → 长按无回弹
        _startTo(target);
      } else {
        // 按下同 tab，走原逻辑（触发原有同 tab 交互）
        _commit(target);
      }
    } else {
      // 拖拽结束 → 吸附到 hoverIndex（松手才切页面）
      _commit(_hover.value);
    }
    // 松开恢复抓取缩放
    _grab.animateTo(
      0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
    _isInteracting = false;
    _isDragging = false;
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _longTapTimer?.cancel();
    if (_isInteracting && _isDragging) {
      _commit(_hover.value);
    }
    // 取消恢复抓取缩放
    _grab.animateTo(
      0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
    _isInteracting = false;
    _isDragging = false;
  }

  double _compressFor(double overflow) {
    const kRange = 50.0;
    final t = (overflow / kRange).clamp(0.0, 1.0);
    return t * LiquidGlassNavBar._kMaxCompress;
  }

  int _indexAt(double localDx) {
    if (_lastContentW <= 0) return 0;
    final p = (localDx - widget.padding) / _lastContentW;
    final clamped = p.clamp(0.0, 0.9999999);
    return (clamped * widget.items.length)
        .floor()
        .clamp(0, widget.items.length - 1);
  }

  void _commit(int target, {bool notify = true, bool bounce = true}) {
    _currentIndex = target;
    // hover 走 ValueNotifier：切换只重建文字层，大胶囊毛玻璃层不参与重建
    _hover.value = target;
    if (notify) {
      widget.onSelected?.call(target);
    }
    if (bounce) {
      _startTo(target);
    } else {
      _startPlainTo(target);
    }
  }

  /// 平滑滑动到目标（无二段回弹）：用于"按下立即切页"的起手，回弹与否在松手
  /// 再决定（长按→无回弹，快速点击→补一段二段回弹），避免长按时先弹再抓的怪感。
  void _startPlainTo(int target) {
    final targetP = target * 100.0;
    _pos.value = _visual.value.p; // 从当前实时视觉连续接管
    _sq.animateTo(
      1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    _pos.animateTo(
      targetP,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 启动一次切换动画（对齐 demo LiquidGlassNavBar 的方向性回弹）。
  ///
  /// 全部 tab 统一"两段式 easeOutCubic 干脆回弹"，去掉中间 tab 的慢启动 SpringCurve：
  ///  - 阶段1：先朝目标方向"过墙 + 挤压"（位置过墙 11%×幅度）
  ///  - 阶段2：落回 targetP 全面恢复
  ///
  /// 回弹幅度随位移距离反馈：amp = 0.35 + 0.65 * (dist / maxDist)，
  /// 位移越大回弹越明显（我的→定时任务幅度大，→环境变量次之，→配置文件最小）。
  ///
  /// 位置一律用 [AnimationController.animateTo]（从当前动画值继续，不重置），
  /// 快速连续切换时滑块一路平滑接管新目标、跟手；回弹走独立控制器，
  /// 两段式的"落回阶段"用令牌防打断回跳。
  void _startTo(int target) {
    final token = ++_reboundToken;
    final targetP = target * 100.0;
    final currentP = _visual.value.p;

    // 回弹幅度随真实导航距离反馈（用按下原点，而非 _currentIndex：
    // _currentIndex 在 _commit 已覆盖成 target，会让 dist 恒为 0 导致无回弹）
    final maxDist = widget.items.length - 1;
    final dist = (targetP - _pressP).abs() / 100.0;
    final amp = 0.35 + 0.65 * (maxDist > 0 ? dist / maxDist : 1.0);
    _lastAmp = amp;

    // 位置从当前实时视觉继续（拖拽松手 / 动画中途切换都无缝衔接）
    _pos.value = currentP;

    // 阶段1：朝目标方向过墙 + 挤压（过墙 11% × 幅度）
    final dir = targetP >= _pressP ? 1.0 : -1.0;
    final squeezeP = targetP + dir * 11.0 * amp;
    _sq.animateTo(
      0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
    final first = _pos.animateTo(
      squeezeP,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
    // 阶段2：落回 targetP 全面恢复（若已被新的切换打断则跳过）
    first.then((_) {
      if (!mounted || token != _reboundToken) return;
      _sq.animateTo(
        1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      _pos.animateTo(
        targetP,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final h = constraints.hasBoundedHeight ? constraints.maxHeight : 56.0;
        final pad = widget.padding;
        final contentW = (w - pad * 2).clamp(0.0, w);
        final contentH = (h - pad * 2).clamp(0.0, h);
        final itemW = items.isEmpty ? contentW : contentW / items.length;

        _lastContentW = contentW;

        if (!_sizeInited && w > 0) {
          _visual.value = LiquidVisual(_currentIndex * 100.0);
          _sizeInited = true;
        }

        final sliderW = itemW;
        final sliderH = contentH;

        return SizedBox(
          width: w,
          height: h,
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ---------- 大胶囊 ----------
                // RepaintBoundary 隔离重绘：滑块/文字层动画时，毛玻璃层不参与重绘
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(h / 2),
                        border: widget.barBorder,
                        boxShadow:
                            widget.barShadow ??
                            [
                              BoxShadow(
                                color: widget.barColor.withValues(alpha: 0.3),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(h / 2),
                        child: widget.barGlass
                            ? BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: Container(color: widget.barGlassColor),
                              )
                            : Container(color: widget.barColor),
                      ),
                    ),
                  ),
                ),

                // ---------- 滑块（动画层：仅此层随每帧视觉更新） ----------
                // 视觉由 ValueNotifier 驱动，动画期间大胶囊/图标文字静态层不重建，
                // 与顶部 tab 的"只重建动画部分"优化思路一致。
                ValueListenableBuilder<LiquidVisual>(
                  valueListenable: _visual,
                  child: Container(
                    width: sliderW,
                    height: sliderH,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.sliderColor,
                          widget.sliderColor.withValues(alpha: 0.35),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(sliderH / 2),
                      border:
                          widget.sliderBorder ??
                          Border.all(color: Colors.white70, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x2E000000),
                          blurRadius: sliderH * 0.22,
                          offset: const Offset(0, 5),
                        ),
                        if (widget.sliderTopGlow != null)
                          BoxShadow(
                            color: widget.sliderTopGlow!,
                            blurRadius: sliderH * 0.1,
                            offset: const Offset(0, -1),
                          ),
                        if (widget.sliderBottomGlow != null)
                          BoxShadow(
                            color: widget.sliderBottomGlow!,
                            blurRadius: sliderH * 0.15,
                            offset: const Offset(0, 1),
                          ),
                      ],
                    ),
                  ),
                  builder: (context, v, child) {
                    return Positioned(
                      left: pad + (v.p / 100.0) * itemW,
                      top: pad,
                      child: IgnorePointer(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..scale(v.scaleX, v.scaleY),
                          child: child,
                        ),
                      ),
                    );
                  },
                ),

                // ---------- tab 内容（滑块位置驱动：每个标签颜色随"距滑块距离"平滑渐变） ----------
                // 与顶部 tab 一致：颜色 = Color.lerp(选中色, 未选色, 滑块与该标签的距离)，
                // 滑块越近颜色越"选中"，越远越"未选"，滑动过程平滑过渡、快速切换也不跳色。
                Positioned(
                  left: pad,
                  top: pad,
                  child: SizedBox(
                    width: contentW,
                    height: contentH,
                    child: ValueListenableBuilder<LiquidVisual>(
                      valueListenable: _visual,
                      builder: (context, v, child) {
                        final double pos = v.p / 100.0; // 滑块中心（item 单位）
                        return Row(
                          children: List.generate(items.length, (i) {
                            final double distance = (pos - i).abs();
                            final double t = distance.clamp(0.0, 1.0);
                            final Color color = Color.lerp(
                              widget.activeColor,
                              widget.inactiveColor,
                              t,
                            )!;
                            final FontWeight weight = t < 0.5
                                ? FontWeight.w600
                                : FontWeight.w500;
                            return SizedBox(
                              width: itemW,
                              height: contentH,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 单图标（低开销）：空/实心按"距滑块最近"选（t<0.5 实心），颜色随距离
                                  // lerp。避免双图标交叉淡入的每帧重绘开销导致过中间标签卡顿，
                                  // 与 demo / 顶部 tab 的轻量标签层一致。
                                  Icon(
                                    t < 0.5 ? items[i].activeIcon : items[i].icon,
                                    color: color,
                                    size: widget.iconSize,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    items[i].label,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: widget.labelSize,
                                      color: color,
                                      fontWeight: weight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

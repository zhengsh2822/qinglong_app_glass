import 'dart:async';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:qinglong_app/base/ui/spring_curve.dart';

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

  // 回弹挤压：0..1，0=挤压态（scaleX 0.78 / scaleY 1.05），1=恢复（1.0/1.0）。
  // 边界 tab 冲撞回弹时压到 0 再恢复；中间 tab 保持 1（仅位置 spring 过冲）。
  late final AnimationController _sq;
  late final Animation<double> _sqCurveX;
  late final Animation<double> _sqCurveY;

  // 抓取缩放：0..1，0=正常（1.0），1=长按抓取（0.85）。
  // 按压时轻微缩小（0.5），长按后进一步缩小（1.0）作为"抓取"反馈，随后可拖动。
  late final AnimationController _grab;

  // 回弹序列令牌：新的切换会使旧序列的"落回阶段"失效，避免位置回跳。
  int _reboundToken = 0;

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
    // 挤压曲线：_sq=0 → 挤压态(0.78 / 1.05)，_sq=1 → 恢复(1.0 / 1.0)
    _sqCurveX = Tween(begin: 0.78, end: 1.0).animate(_sq);
    _sqCurveY = Tween(begin: 1.05, end: 1.0).animate(_sq);
    _grab = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(_onTick);
    _pos.value = _currentIndex * 100.0;
    // 初始滑块不挤压（_sq=1 → scaleX 1.0 / scaleY 1.0）
    _sq.value = 1.0;
  }

  /// 抓取缩放系数：0=正常 1.0，1=长按抓取 0.85
  double get _grabScale =>
      lerpDouble(1.0, LiquidGlassNavBar._kGrabbedScale, _grab.value) ?? 1.0;

  /// 动画每帧回调：位置 + 回弹挤压 + 抓取缩放写入 ValueNotifier，只重建滑块层
  void _onTick() {
    final double gs = _grabScale;
    _visual.value = LiquidVisual(
      _pos.value,
      scaleX: _sqCurveX.value * gs,
      scaleY: _sqCurveY.value * gs,
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
    // 按压即轻微缩小（抓取预备反馈）
    _grab.animateTo(
      0.5,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
    // 长按计时：到达后进入"抓取"（小胶囊缩小），并可继续拖动
    _longTapTimer?.cancel();
    _longTapTimer = Timer(LiquidGlassNavBar._kLongTapDuration, () {
      if (!mounted || !_isInteracting || _isDragging) return;
      _longTapFired = true;
      _longTapTimer?.cancel();
      widget.onLongTap?.call(_hover.value);
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
      _commit(target);
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

  void _commit(int target, {bool notify = true}) {
    _currentIndex = target;
    // hover 走 ValueNotifier：切换只重建文字层，大胶囊毛玻璃层不参与重建
    _hover.value = target;
    if (notify) {
      widget.onSelected?.call(target);
    }
    _startTo(target);
  }

  /// 启动一次切换动画（对齐 demo LiquidGlassNavBar 的方向性回弹）：
  ///  - 边界 tab（第 0 / 最后）：两段式"冲撞回弹" —— 先冲到"挤压位"（位置
  ///    过墙 11、scaleX 压扁 0.78、scaleY 拉长 1.05），再落回 targetP 恢复。
  ///    位置过墙的方向取决于冲向哪边，是"单侧冲撞"而非"两边对称收缩"。
  ///  - 中间 tab：位置用 spring 过冲曲线（cubic-bezier(0.34,1.56,0.64,1)），无挤压。
  ///
  /// 位置一律用 [AnimationController.animateTo]（从当前动画值继续，不重置），
  /// 快速连续切换时滑块一路平滑接管新目标、跟手；回弹走独立控制器，
  /// 边界两段式的"落回阶段"用令牌防打断回跳。
  void _startTo(int target) {
    final token = ++_reboundToken;
    final targetP = target * 100.0;
    final isBoundary = target == 0 || target == widget.items.length - 1;

    // 位置从当前实时视觉继续（拖拽松手 / 动画中途切换都无缝衔接）
    _pos.value = _visual.value.p;

    if (isBoundary) {
      // 边界：两段式冲撞回弹
      const squeezeScaleX = 0.78;
      final squeezeP = (target == 0)
          ? -(1 - squeezeScaleX) * 50 // 左边界：中心过墙向左 11
          : targetP + (1 - squeezeScaleX) * 50; // 右边界：中心过墙向右 11
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
    } else {
      // 中间 tab：位置 spring 轻过冲（300ms 快起步跟手 + 末端轻回弹），无挤压
      _sq.animateTo(1.0);
      _pos.animateTo(
        targetP,
        duration: const Duration(milliseconds: 300),
        curve: const SpringCurve(),
      );
    }
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

                // ---------- tab 内容（hover 驱动：切换只重建文字层） ----------
                Positioned(
                  left: pad,
                  top: pad,
                  child: SizedBox(
                    width: contentW,
                    height: contentH,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _hover,
                      builder: (context, hover, child) {
                        return Row(
                          children: List.generate(items.length, (i) {
                            final active = i == hover;
                            final color = active
                                ? widget.activeColor
                                : widget.inactiveColor;
                            final weight = active
                                ? FontWeight.w600
                                : FontWeight.w500;
                            return SizedBox(
                              width: itemW,
                              height: contentH,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    active
                                        ? items[i].activeIcon
                                        : items[i].icon,
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

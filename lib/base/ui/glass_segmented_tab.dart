import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/spring_curve.dart';

/// 顶部 Tab —— 液态玻璃风格（对齐 demos/liquid_glass_demo 顶部 tab 视觉）
///
/// 保持对外 API（tabs + tabController + editMode）不变，内部渲染改为：
///  - 大胶囊背景 + 液态滑块（渐变 + 边框 + 高光/内发光）
///  - 滑块位置由 tabController.animation 驱动（AnimatedBuilder）
///  - 点击调用 animateTo(300ms, easeOutCubic) 平滑滑动
///  - 赛博/苹果两套视觉参数与 demo 确认一致
class GlassSegmentedTab extends ConsumerStatefulWidget {
  final List<String> tabs;
  final TabController tabController;
  final bool editMode;

  const GlassSegmentedTab({
    super.key,
    required this.tabs,
    required this.tabController,
    this.editMode = false,
  });

  @override
  ConsumerState<GlassSegmentedTab> createState() => _GlassSegmentedTabState();
}

class _GlassSegmentedTabState extends ConsumerState<GlassSegmentedTab> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isReady = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final theme = ref.watch(themeProvider);

    // ===== 液态玻璃视觉参数（与 demo 顶部 tab 一致） =====
    // 大胶囊背景
    final Color bgColor = isCyber
        ? const Color(0xFF1A1A24)
        : AppleColors.bgTertiary;
    // 大胶囊边框（赛博：未置顶卡片青色；苹果白：1px 纯白边框）
    final Border? bgBorder = isCyber
        ? Border.all(color: CyberColors.cyan.withValues(alpha: 0.2), width: 1)
        : Border.all(color: Colors.white, width: 1);
    // 液态滑块底色（赛博全透明 + 内发光，与底部导航同款；苹果保持渐变底）
    final Color thumbColor = isCyber
        ? Colors.transparent
        : const Color(0xFFE5E5E5);
    // 滑块边框（赛博 #404040 细边框；苹果白色高光边框）
    final Border thumbBorder = isCyber
        ? Border.all(color: const Color(0xFF404040), width: 1)
        : Border.all(color: Colors.white70, width: 1);
    // 滑块顶部高光（苹果） / 底部内发光（赛博）
    final Color? thumbTopGlow =
        isCyber ? null : Colors.white.withValues(alpha: 0.9);
    final Color? thumbBottomGlow = isCyber
        ? const Color(0x22CCCCCC)
        : null;

    // 文字色（提示色统一走 primaryColor，参与主题切换颜色过渡）
    final Color activeColor = ref.watch(themeProvider).primaryColor;
    final Color inactiveColor = isCyber
        ? CyberColors.hintGray
        : theme.themeColor.title2Color();

    return SizedBox(
      // 大胶囊总高度 55：左右 15 padding + 大胶囊自身 43（GlassSegmentedTabDelegate 不再外层加 padding）
      height: 55,
      child: IgnorePointer(
        ignoring: widget.editMode,
        child: ColoredBox(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 15,
              right: 15,
              bottom: 6,
              top: 6,
            ),
            child: AnimatedOpacity(
              opacity: _isReady ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _LiquidTabBarSlider(
                tabs: widget.tabs,
                tabController: widget.tabController,
                bgColor: bgColor,
                bgBorder: bgBorder,
                thumbColor: thumbColor,
                thumbBorder: thumbBorder,
                thumbTopGlow: thumbTopGlow,
                thumbBottomGlow: thumbBottomGlow,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                isCyber: isCyber,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidTabBarSlider extends StatefulWidget {
  final List<String> tabs;
  final TabController tabController;
  final Color bgColor;
  final Border? bgBorder;
  final Color thumbColor;
  final Border thumbBorder;
  final Color? thumbTopGlow;
  final Color? thumbBottomGlow;
  final Color activeColor;
  final Color inactiveColor;
  final bool isCyber;

  const _LiquidTabBarSlider({
    required this.tabs,
    required this.tabController,
    required this.bgColor,
    required this.bgBorder,
    required this.thumbColor,
    required this.thumbBorder,
    required this.thumbTopGlow,
    required this.thumbBottomGlow,
    required this.activeColor,
    required this.inactiveColor,
    required this.isCyber,
  });

  @override
  State<_LiquidTabBarSlider> createState() => _LiquidTabBarSliderState();
}

class _LiquidTabBarSliderState extends State<_LiquidTabBarSlider>
    with TickerProviderStateMixin {
  // 回弹动画（本地控制器，不影响 TabController —— 页面内容走 TabBarView +
  // tabController.animation 保持平滑切换；回弹/挤压只作用于滑块视觉层）。
  late final AnimationController _rebound;
  // 抓取缩放（长按缩小，与底部导航交互一致）
  late final AnimationController _grab;

  bool _lastIsBoundary = false;
  double _boundaryDir = 1.0; // +1 向右过墙 / -1 向左过墙

  // 手势/拖拽状态
  bool _isInteracting = false;
  bool _isDragging = false;
  bool _longTapFired = false;
  double? _dragP; // 拖拽时滑块位置（index 单位）；提交后保留到页面到位
  int _dragHover = 0;
  Offset _downLocal = Offset.zero;
  Timer? _longTapTimer;
  double _lastTotalW = 0; // build 时记录的大胶囊宽度

  // 边界过墙量（tab 宽度比例，与底部导航 11% 一致）
  static const double _boundaryOvershoot = 0.11;
  // 进入拖拽的最小水平位移（水平需主导竖向，避免与页面竖向滚动冲突）
  static const double _dragThreshold = 5.0;
  // 长按判定时长（与底部导航一致）
  static const Duration _longTapDuration = Duration(milliseconds: 500);

  /// 抓取缩放：0=正常 1.0，1=长按抓取 0.85
  double get _grabScale =>
      lerpDouble(1.0, 0.85, _grab.value) ?? 1.0;

  @override
  void initState() {
    super.initState();
    _rebound = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _grab = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    // 页面动画到位后清除拖拽覆盖（避免滑块残留卡在拖拽位）
    widget.tabController.animation!.addStatusListener(_onTabStatus);
  }

  void _onTabStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_isDragging) {
      setState(() => _dragP = null);
    }
  }

  @override
  void dispose() {
    _longTapTimer?.cancel();
    widget.tabController.animation!.removeStatusListener(_onTabStatus);
    _rebound.dispose();
    _grab.dispose();
    super.dispose();
  }

  /// 点击/提交：页面切换 + 回弹。
  ///  - 边界 tab（全部/已禁用）：两段式冲撞（滑块本地过墙 + 挤压）。
  ///  - 中间 tab（运行中/未使用）：整段 spring 过冲 —— 直接作用在
  ///    tabController 上，页面与滑块一起单段连续回弹，不再"先到再弹"。
  void _onTap(int i) {
    _lastIsBoundary = i == 0 || i == widget.tabs.length - 1;
    _boundaryDir = i == 0 ? -1.0 : 1.0;
    if (_lastIsBoundary) {
      _rebound.forward(from: 0);
      widget.tabController.animateTo(
        i,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.tabController.animateTo(
        i,
        duration: const Duration(milliseconds: 300),
        curve: const SpringCurve(),
      );
    }
  }

  /// 提交（点击/拖拽松手/长按拖拽）：拖拽/抓取场景保留滑块在目标位，
  /// 等页面动画到位后再跟随，避免"拖到 2 又跳回 0"的跳变。
  void _commit(int i) {
    _dragP = (_isDragging || _longTapFired) ? i.toDouble() : null;
    _onTap(i);
  }

  // ---------- 手势（同步底部导航：按压缩小 → 长按抓取 → 可拖拽） ----------

  double _pFromFinger(double localDx) {
    final w = _lastTotalW;
    if (w <= 0) return 0;
    final p = (localDx / w).clamp(0.0, 1.0);
    return p * (widget.tabs.length - 1);
  }

  int _indexAt(double localDx) {
    final w = _lastTotalW;
    if (w <= 0) return 0;
    final p = (localDx / w).clamp(0.0, 0.9999);
    return (p * widget.tabs.length).floor().clamp(0, widget.tabs.length - 1);
  }

  void _onPointerDown(PointerDownEvent e) {
    _isInteracting = true;
    _isDragging = false;
    _longTapFired = false;
    _downLocal = e.localPosition;
    _dragP = null;
    // 按压即轻微缩小（抓取预备）
    _grab.animateTo(0.5, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    _longTapTimer?.cancel();
    _longTapTimer = Timer(_longTapDuration, () {
      if (!mounted || !_isInteracting || _isDragging) return;
      _longTapFired = true;
      _longTapTimer?.cancel();
      // 长按：小胶囊缩小（抓取），随后可拖动
      _grab.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_isInteracting) return;
    final delta = e.localPosition - _downLocal;
    if (!_isDragging) {
      // 水平主导才进入拖拽，避免与页面竖向滚动冲突
      if (delta.dx.abs() < _dragThreshold || delta.dx.abs() < delta.dy.abs()) {
        return;
      }
      _isDragging = true;
      _longTapTimer?.cancel();
    }
    _dragP = _pFromFinger(e.localPosition.dx);
    _dragHover = _indexAt(e.localPosition.dx);
    setState(() {});
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_isInteracting) return;
    _longTapTimer?.cancel();
    if (_longTapFired) {
      // 已长按（抓取）：拖拽过就提交，否则只恢复
      if (_isDragging) {
        _commit(_dragHover);
      }
    } else if (!_isDragging) {
      // 点击
      _commit(_indexAt(e.localPosition.dx));
    } else {
      // 拖拽松手
      _commit(_dragHover);
    }
    _grab.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic);
    _isInteracting = false;
    _isDragging = false;
    setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _longTapTimer?.cancel();
    if (_isInteracting && _isDragging) {
      _commit(_dragHover);
    }
    _grab.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic);
    _isInteracting = false;
    _isDragging = false;
    setState(() {});
  }

  /// 滑块过冲偏移（tab 宽度单位）
  double _offsetP() {
    if (!_lastIsBoundary) return 0.0; // 中间：spring 直接在 base 上过冲
    final double t = _rebound.value;
    final double p = t < 0.48 ? (t / 0.48) : (1 - (t - 0.48) / 0.52);
    return _boundaryDir * _boundaryOvershoot * p;
  }

  double _scaleX() {
    if (!_lastIsBoundary) return 1.0;
    final double t = _rebound.value;
    return t < 0.48
        ? lerpDouble(1.0, 0.78, t / 0.48)!
        : lerpDouble(0.78, 1.0, (t - 0.48) / 0.52)!;
  }

  double _scaleY() {
    if (!_lastIsBoundary) return 1.0;
    final double t = _rebound.value;
    return t < 0.48
        ? lerpDouble(1.0, 1.05, t / 0.48)!
        : lerpDouble(1.05, 1.0, (t - 0.48) / 0.52)!;
  }

  @override
  Widget build(BuildContext context) {
    // GPU 优化：LayoutBuilder 必须放在 AnimatedBuilder 外层（只在大胶囊尺寸
    // 变化时重算几何，动画期间不重新布局）。
    // 同时必须放在大胶囊 Container 内部：Container 带边框（赛博 1px）时
    // child 区域会被边框内缩（两侧各 1px），若在外层取 constraints.maxWidth
    // 会拿到含边框的整宽，而文字 Row 实际用的是内缩后的窄宽度，导致滑块
    // 随索引逐渐偏右（运行中/未使用/已禁用 越靠右越明显）。
    final int count = widget.tabs.length;

    // 统一底层 Listener 处理 点击/长按抓取/拖拽（与底部导航一致）
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 43,
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(22),
          border: widget.bgBorder,
          boxShadow: widget.isCyber
              ? null
              : const [
                  BoxShadow(
                    color: AppleColors.cardShadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            final double tabWidth = totalWidth / count;
            const double horizontalPadding = 3.0;
            final double thumbWidth = tabWidth - horizontalPadding * 2;
            _lastTotalW = totalWidth;

            return AnimatedBuilder(
              animation: Listenable.merge([
                widget.tabController.animation!,
                _rebound,
                _grab,
              ]),
              builder: (context, child) {
                final double base = widget.tabController.animation!.value;
                // 拖拽/提交中：保留滑块在拖拽位，直到页面动画到位
                final bool holdDrag =
                    _dragP != null &&
                    (_isDragging || (base - _dragP!).abs() > 0.02);
                final double displayP = holdDrag ? _dragP! : base + _offsetP();
                final double gs = _grabScale;
                final double sx = holdDrag ? gs : _scaleX() * gs;
                final double sy = holdDrag ? gs : _scaleY() * gs;
                final double thumbLeft =
                    horizontalPadding + displayP * tabWidth;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ---------- 液态滑块 ----------
                    Positioned(
                      left: thumbLeft,
                      top: 2,
                      bottom: 2,
                      width: thumbWidth,
                      child: IgnorePointer(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..scale(sx, sy),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  widget.thumbColor,
                                  widget.thumbColor.withValues(alpha: 0.35),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(17.5),
                              border: widget.thumbBorder,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x2E000000),
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                                if (widget.thumbTopGlow != null)
                                  BoxShadow(
                                    color: widget.thumbTopGlow!,
                                    blurRadius: 4,
                                    offset: const Offset(0, -1),
                                  ),
                                if (widget.thumbBottomGlow != null)
                                  BoxShadow(
                                    color: widget.thumbBottomGlow!,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ---------- 文字 ----------
                    Row(
                      children: List.generate(count, (i) {
                        // 文字跟随滑块位置变色（拖拽时随手指滑动）
                        final double distance = (displayP - i).abs();
                        final double t = distance.clamp(0.0, 1.0);
                        final Color textColor = Color.lerp(
                          widget.activeColor,
                          widget.inactiveColor,
                          t,
                        )!;

                        return Expanded(
                          child: Center(
                            child: Text(
                              widget.tabs[i],
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class GlassSegmentedTabDelegate extends SliverPersistentHeaderDelegate {
  final List<String> tabs;
  final TabController tabController;
  final bool editMode;

  const GlassSegmentedTabDelegate({
    required this.tabs,
    required this.tabController,
    this.editMode = false,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // 不再额外包 Padding / Transform —— 与其他顶部 tab 页面（env_page/config_page 等）
    // 使用 GlassSegmentedTab 原始默认行为，保持完全一致（搜索框↔大胶囊↔卡片 间距统一）
    return GlassSegmentedTab(
      tabs: tabs,
      tabController: tabController,
      editMode: editMode,
    );
  }

  @override
  bool shouldRebuild(covariant GlassSegmentedTabDelegate oldDelegate) {
    return editMode != oldDelegate.editMode ||
        tabs.length != oldDelegate.tabs.length;
  }

  @override
  double get maxExtent => 55;

  @override
  double get minExtent => 55;
}

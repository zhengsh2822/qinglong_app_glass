import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/container_reveal.dart';
import 'package:qinglong_app/base/ui/page_tap_origin.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

/// 主题版全局容器展开转场路由（同步自壁纸版 WallpaperPageRoute，剔除
/// 壁纸背景/结霜模糊——主题版卡片为纯色卡，无壁纸层）。
///
/// 旧行为：CupertinoPageRoute，所有页面从右侧滑入。
/// 新行为：以「最后一次点击命中的视觉卡片矩形」为来源展开页面，
/// 返回时沿同一来源收回；取不到时回退到点击点 64x64 圆角源。
///
/// 转场动画开关（设置页「经典页面转场」）：构造时读一次 SP——开启后本路由
/// 不做容器展开，改为经典右侧滑入 + 下层视差压暗（delegatedTransition 注入
/// 下层「左移 30% + scrim 0.28」，用户选型）；关闭（默认）保持容器展开。
/// 全项目所有二级页 push 都经本构造（routes.dart 路由表 + 各页直接调用），
/// 因此开关零调用点改动、每次进页即时生效。
/// 账号页切换走独立的 ContainerTransformRoute，不受本开关影响。
///
/// 注意：继承 [PageRoute] 而不是 CupertinoPageRoute——后者构造函数
/// `assert(opaque)`，而本路由 opaque=false（容器展开需要透出下层页面），
/// debug 模式必崩（壁纸版已踩过并修复的 assert(opaque) 历史雷）。所以经典
/// 模式不委托 CupertinoPageRoute，而是本类内部直接以 SlideTransition 复刻
/// 右侧滑入（opaque 恒 false 两种模式通用，页面本身即全屏不透明内容）。
///
/// 结构：
/// - 页面内容全程实时渲染（不做快照、不加透明度包裹），内容在展开窗口
///   内以全透明度直接呈现，收回时由容器整体同步溶解（reverseFade）；
/// - 转场节奏由共用组件 [ContainerReveal] 提供，与账号页精确来源转场
///   （ContainerTransformRoute）完全一致；
/// - 容器底色取当前主题 scaffoldBackgroundColor（赛博=深空黑），
///   描边取 CapsuleGlowCard 同款（赛博青色/苹果白色）；
/// - 容器展开**收回可打断**：收回中 IgnorePointer（不再吃输入）+ 重开
///   同来源时从旧收回进度无缝续播（见 [_collapsing]/[ContainerCollapseTracker]），
///   与展开中可打断返回（Flutter 原生 controller 反向）对称。
class ContainerPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  /// 显式指定的来源（CardTransitionSource 精确卡片矩形）。
  final Rect? sourceRect;
  final Widget? sourceChild;
  final double sourceRadius;
  final double sourceHighlightOpacity;
  final Color? sourceBorderColor;

  /// 是否走经典右侧滑入（构造时读一次 SP，本次路由生命周期内不变）。
  final bool _classic;

  @override
  final String? title;

  /// 构造时捕获的点击来源（由根部 PageTapScope 记录）。
  final TapOriginData? _tapOrigin;

  /// 最近一次进入收回中的容器展开路由（由 [ContainerCollapseTracker] 维护），
  /// 供「收回中重开同来源」无缝续播。
  static ContainerPageRoute<dynamic>? _collapsing;

  /// 收回被打断重开时的起始进度（0~1，构造时从旧路由捕获）：
  /// createAnimationController 设为初值，didPush 的 forward() 从此续播。
  double _initialRevealProgress = 0;

  /// 被本路由接管的收回中旧路由（install 时同帧移除，避免双窗口叠影）。
  ContainerPageRoute<dynamic>? _interrupted;

  /// 来源标识：同卡片重开判定用（Rect/Offset 均为值相等）。
  Object? get _originKey => sourceRect ?? _tapOrigin?.rect ?? _tapOrigin?.point;

  ContainerPageRoute({
    required this.builder,
    this.title,
    super.settings,
    super.fullscreenDialog = false,
    this.sourceRect,
    this.sourceChild,
    this.sourceRadius = 18,
    this.sourceHighlightOpacity = 0,
    this.sourceBorderColor,
  }) : _classic = SpUtil.getBool(spClassicPageTransition, defValue: false),
       _tapOrigin = PageTapOrigin.lastFresh {
    // 收回打断：同来源的容器展开正在收回 → 新路由从旧进度无缝续播
    final ContainerPageRoute<dynamic>? collapsing = _collapsing;
    final Animation<double>? anim = collapsing?.animation;
    if (collapsing != null &&
        !collapsing._classic &&
        anim != null &&
        anim.status == AnimationStatus.reverse &&
        anim.value > 0 &&
        collapsing._originKey == _originKey) {
      _initialRevealProgress = anim.value;
      _interrupted = collapsing;
    }
  }

  @override
  AnimationController createAnimationController() {
    final AnimationController controller = super.createAnimationController();
    // createAnimationController 在 install() 阶段执行，早于 didPush() 的
    // forward()——先设初值，展开即从旧收回位置续播
    if (_initialRevealProgress > 0) {
      controller.value = _initialRevealProgress.clamp(0.0, 1.0);
    }
    return controller;
  }

  @override
  void install() {
    super.install();
    if (_interrupted != null) {
      // push 与 removeRoute 同帧：新路由首帧即渲染旧收回位置的窗口，
      // 旧路由立刻消失，视觉零差异
      navigator?.removeRoute(_interrupted!);
      _interrupted = null;
    }
  }

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => _classic
      ? const Duration(milliseconds: 400)
      : const Duration(milliseconds: 480);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // 页面全程实时渲染，不做快照、不加透明度包裹：透明度 <1 的包裹层
    // 会产生 saveLayer 隔离，玻璃组件（液态玻璃导航等）转场期间采样不到
    // 背景，出现「展开完才恢复」的跳变（壁纸版实测结论，同步适用）。
    return builder(context);
  }

  /// 经典模式：向下层页面注入「左移 30% + 压暗 0.28」视差变换（用户选型，
  /// CupertinoPageTransition.delegatedTransition 同款机制）。delegated 由
  /// 上层路由提供下层变换，与下层页面自身路由类型无关；SDK 会自动抑制下层
  /// 原有 secondary 变换，不会双重叠加。容器展开模式返回 null，下层保持
  /// 原行为（容器转场不依赖下层变换）。
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _classic ? _classicDelegatedTransition : null;

  static Widget? _classicDelegatedTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.30, 0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.linearToEaseOut,
        reverseCurve: Curves.easeInToLinear,
      )),
      transformHitTests: false,
      child: AnimatedBuilder(
        animation: secondaryAnimation,
        builder: (context, page) {
          final double t = Curves.easeOut.transform(secondaryAnimation.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              page!,
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.28 * t),
                  ),
                ),
              ),
            ],
          );
        },
        child: child,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 经典模式：右侧滑入/滑出（复刻 CupertinoPageRoute 节奏），返回时
    // 随动画反向自动滑回右侧，无需单独处理 pop
    if (_classic) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.linearToEaseOut),
        ),
        child: child,
      );
    }

    final Size screen = MediaQuery.sizeOf(context);
    final ThemeData theme = Theme.of(context);
    final Color pageBackground = theme.scaffoldBackgroundColor;
    // 与 CapsuleGlowCard 同款描边：深色背景（赛博）→ 青色，浅色 → 白色。
    // scaffoldBackgroundColor 亮度是可靠的主题模式信号（避免引入 Consumer）。
    final Color stroke = theme.scaffoldBackgroundColor.computeLuminance() < 0.2
        ? CyberColors.cyan.withValues(alpha: 0.2)
        : Colors.white;

    // 收回阶段整页 IgnorePointer：正在溶解的面板不应再吃输入，否则收回
    // 期间点下层页面无响应（表现=收回不支持打断）。展开与静止阶段保持
    // 可交互（展开中可打断返回）。
    return IgnorePointer(
      ignoring: animation.status == AnimationStatus.reverse,
      child: ContainerReveal(
        animation: animation,
        originRect: _resolveOrigin(screen),
        sourceChild: sourceChild,
        sourceRadius: sourceRadius,
        // 材质复刻（同步壁纸版配方，2026-11-06）：窗口前段为实时毛玻璃，
        // 采样旧页面（含卡片本体）→ 窗口首帧读作「糊化的卡片」=卡片直接
        // 展开，而非不透明面板叠加展开。sigma 取壁纸版默认 10（主题版无
        // 卡片模糊设置项，用常量）。
        sourceBlurSigma: 10,
        sourceHighlightOpacity: sourceHighlightOpacity,
        sourceBorderColor: sourceBorderColor ?? stroke,
        pageBackground: pageBackground,
        // reverseFade：收回方向内容随窗口收缩逐渐溶解，避免路由移除瞬间
        // 内容才消失产生闪烁（页面无自带入场动画，由容器代管收回淡出）。
        reverseFade: true,
        child: child,
      ),
    );
  }

  Rect _resolveOrigin(Size screen) {
    final Rect screenRect = Offset.zero & screen;

    final Rect? explicit = sourceRect;
    if (explicit != null) {
      final Rect clipped = explicit.intersect(screenRect);
      if (!clipped.isEmpty) return clipped;
    }

    final Rect? cardRect = _tapOrigin?.rect;
    if (cardRect != null) {
      final Rect clipped = cardRect.intersect(screenRect);
      if (!clipped.isEmpty) return clipped;
    }

    final Offset? point = _tapOrigin?.point;
    if (point != null) {
      final Rect rect = Rect.fromCenter(
        center: point,
        width: 64,
        height: 64,
      ).intersect(screenRect);
      if (!rect.isEmpty) return rect;
    }

    return Rect.fromCenter(
      center: screen.center(Offset.zero),
      width: 64,
      height: 64,
    );
  }
}

/// 注册到 MaterialApp.navigatorObservers：记录收回中的容器展开路由，
/// 供「收回中重开同来源」无缝续播（收回打断，与展开打断对称）。
///
/// 展开支持打断是 Flutter 原生能力（推入中 pop，controller 从当前值反向）；
/// 收回原本不行——收回中的页面盖在下层上吃输入，重开也是双窗口叠影。
/// 配合 ContainerPageRoute 构造器的同来源检测（initialRevealProgress +
/// install 时 removeRoute 旧路由）实现无缝续播。
class ContainerCollapseTracker extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ContainerPageRoute<dynamic> && !route._classic) {
      ContainerPageRoute._collapsing = route;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(ContainerPageRoute._collapsing, route)) {
      ContainerPageRoute._collapsing = null;
    }
  }
}

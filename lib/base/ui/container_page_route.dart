import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ui/container_reveal.dart';
import 'package:qinglong_app/base/ui/page_tap_origin.dart';

/// 主题版全局容器展开转场路由（同步自壁纸版 WallpaperPageRoute，剔除
/// 壁纸背景/结霜模糊——主题版卡片为纯色卡，无壁纸层）。
///
/// 旧行为：CupertinoPageRoute，所有页面从右侧滑入。
/// 新行为：以「最后一次点击命中的视觉卡片矩形」为来源展开页面，
/// 返回时沿同一来源收回；取不到时回退到点击点 64x64 圆角源。
///
/// 注意：继承 [PageRoute] 而不是 CupertinoPageRoute——后者构造函数
/// `assert(opaque)`，而本路由 opaque=false（容器展开需要透出下层页面），
/// debug 模式必崩（壁纸版已踩过并修复的 assert(opaque) 历史雷）。
///
/// 结构：
/// - 页面内容全程实时渲染（不做快照、不加透明度包裹），内容在展开窗口
///   内以全透明度直接呈现，收回时由容器整体同步溶解（reverseFade）；
/// - 转场节奏由共用组件 [ContainerReveal] 提供，与账号页精确来源转场
///   （ContainerTransformRoute）完全一致；
/// - 容器底色取当前主题 scaffoldBackgroundColor（赛博=深空黑），
///   描边取 CapsuleGlowCard 同款（赛博青色/苹果白色）。
class ContainerPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  /// 显式指定的来源（CardTransitionSource 精确卡片矩形）。
  final Rect? sourceRect;
  final Widget? sourceChild;
  final double sourceRadius;
  final double sourceHighlightOpacity;
  final Color? sourceBorderColor;

  @override
  final String? title;

  /// 构造时捕获的点击来源（由根部 PageTapScope 记录）。
  final TapOriginData? _tapOrigin;

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
  }) : _tapOrigin = PageTapOrigin.lastFresh;

  @override
  bool get opaque => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 480);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 480);

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

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Size screen = MediaQuery.sizeOf(context);
    final ThemeData theme = Theme.of(context);
    final Color pageBackground = theme.scaffoldBackgroundColor;
    // 与 CapsuleGlowCard 同款描边：深色背景（赛博）→ 青色，浅色 → 白色。
    // scaffoldBackgroundColor 亮度是可靠的主题模式信号（避免引入 Consumer）。
    final Color stroke = theme.scaffoldBackgroundColor.computeLuminance() < 0.2
        ? CyberColors.cyan.withValues(alpha: 0.2)
        : Colors.white;

    return ContainerReveal(
      animation: animation,
      originRect: _resolveOrigin(screen),
      sourceChild: sourceChild,
      sourceRadius: sourceRadius,
      // 主题版无结霜层：纯色卡片没有 BackdropFilter 材质需要复刻，
      // 保持 0（ContainerReveal 内部 withBlur=false 跳过模糊层）。
      sourceBlurSigma: 0,
      sourceHighlightOpacity: sourceHighlightOpacity,
      sourceBorderColor: sourceBorderColor ?? stroke,
      pageBackground: pageBackground,
      // reverseFade：收回方向内容随窗口收缩逐渐溶解，避免路由移除瞬间
      // 内容才消失产生闪烁（页面无自带入场动画，由容器代管收回淡出）。
      reverseFade: true,
      child: child,
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

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ui/blur_effect.dart';

/// 毛玻璃卡片组件
///
/// 根据 [blurEffectProvider] 决定是否使用 BackdropFilter 高斯模糊：
/// - 开启：ClipRRect + BackdropFilter 模糊 + 半透明背景色
/// - 关闭：纯色背景（不透明，GPU 零模糊开销）
///
/// 用法：
/// ```dart
/// CyberGlassCard(
///   child: ...,
///   borderRadius: 12,
/// )
/// ```
class CyberGlassCard extends ConsumerWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Border? border;
  final VoidCallback? onTap;

  const CyberGlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 18,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.border,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blurEnabled = ref.watch(blurEffectProvider);

    final cardContent = Container(
      decoration: BoxDecoration(
        // 关闭毛玻璃时提高背景不透明度保证可读性
        color:
            backgroundColor ??
            (blurEnabled
                ? const Color(0x20FFFFFF)
                : const Color(0xFF12121A)),
        borderRadius: BorderRadius.circular(borderRadius),
        border:
            border ??
            Border.all(color: CyberColors.borderGlow, width: 0.5),
      ),
      padding: padding,
      child:
          onTap != null
              ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: child,
                ),
              )
              : child,
    );

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child:
            blurEnabled
                ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 20,
                    sigmaY: 20,
                  ),
                  child: cardContent,
                )
                : cardContent,
      ),
    );
  }
}

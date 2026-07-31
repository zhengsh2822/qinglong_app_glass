import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';

/// "我的"页面通用卡片
///
/// 替代 other_page.dart 中重复 4 次的手写 Container 卡片样式：
/// - cyber 模式: CyberColors.cardBg + 青色微光边框
/// - 非 cyber 模式: AppleColors.bgSecondary + 柔和阴影
///
/// 圆角统一为 [AppleColors.radiusCard] (18)，水平 margin 统一为
/// [AppleColors.spaceMd] (16)。
class OtherPageCard extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// cyber 模式下是否裁剪子组件（用于配合发光边框视觉效果）
  final bool clipInCyber;

  const OtherPageCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
    this.clipInCyber = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      clipBehavior: isCyber && clipInCyber ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppleColors.radiusCard),
        color: isCyber ? CyberColors.cardBg : AppleColors.bgSecondary,
        border: isCyber
            ? Border.all(color: CyberColors.borderGlow, width: 1)
            : null,
        boxShadow: isCyber
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: onTap == null
          ? (padding == null ? child : Padding(padding: padding as EdgeInsets, child: child))
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppleColors.radiusCard),
                child: padding == null
                    ? child
                    : Padding(padding: padding as EdgeInsets, child: child),
              ),
            ),
    );
  }
}

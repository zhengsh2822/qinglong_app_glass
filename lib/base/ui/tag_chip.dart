import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';

/// 只读标签 chip 组件
///
/// 用于展示已选中的权限/分类等只读标签，与 [SelectableChip] 风格协调：
/// - 矩形圆角 5（参考壁纸版本设计）
/// - 主题色高亮背景 + 主题色文字
/// - 无勾选图标（只读展示，不可点击）
///
/// 使用场景：
/// - 应用管理列表项的权限范围标签
/// - 应用详情页的权限标签
class TagChip extends ConsumerWidget {
  final String label;

  const TagChip({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;

    final Color accentColor =
        isCyber ? CyberColors.cyan : AppleColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: accentColor,
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../theme.dart';

/// 上传胶囊按钮（"上传脚本" / "上传配置文件" 等共用）
///
/// 视觉：主题色 12% 透明底 + 45% 边框 + 微光晕，内容 `+ 上传`（图标主题色、文字主色）
/// 原 UploadScriptWidget 与 AddConfigPage 各自实现同款按钮，提取为公共组件复用。
class UploadPillButton extends ConsumerWidget {
  final VoidCallback onTap;
  final String label;

  const UploadPillButton({
    super.key,
    required this.onTap,
    this.label = "上传",
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final Color accent = isCyber
        ? CyberColors.cyan
        : ref.watch(themeProvider).primaryColor;
    final Color iconColor = isCyber
        ? CyberColors.titleWhite
        : ref.watch(themeProvider).themeColor.titleColor();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.2),
                blurRadius: 6,
                spreadRadius: 0.3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.add, size: 18, color: accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

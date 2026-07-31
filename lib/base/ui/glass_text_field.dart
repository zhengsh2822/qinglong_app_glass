import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';

/// 胶囊形输入框
///
/// 统一封装：Container(borderRadius 24) + 描边
/// 符合项目规范：所有输入框必须是胶囊形（border radius 24）
/// 不使用 BackdropFilter，避免高刷新率屏幕 GPU 过载
class GlassTextField extends ConsumerWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextAlignVertical? textAlignVertical;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final EdgeInsets padding;
  final List<TextInputFormatter>? inputFormatters;

  const GlassTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.maxLines,
    this.minLines,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType,
    this.textAlignVertical,
    this.onChanged,
    this.onEditingComplete,
    this.textInputAction,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).themeMode;
    final isDark = themeMode == modeDark || themeMode == modeCyber;
    // 与卡片同色系描边，但宽度更细（0.5 vs 卡片 1.0）
    final borderColor = isDark ? CyberColors.borderGlow : AppleColors.cardBorder;
    const radius = 24.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? CyberColors.cardBg.withOpacity(0.5)
            : AppleColors.bgSecondary,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      padding: padding,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        minLines: minLines,
        autofocus: autofocus,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textAlignVertical: textAlignVertical,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        textInputAction: textInputAction,
        style: style,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/blur_effect.dart';
import 'package:qinglong_app/base/ui/other_page_card.dart';

/// 通用弹窗选择器（参考 push_setting_page 的"选择通知方式"）
///
/// 用于替代原生 DropdownButtonFormField 等"下来下拉"控件，
/// 弹出一个 iOS 风格的圆角弹窗（赛博模式为霓虹边框，非赛博模式为白底圆角）。
///
/// 设计规范（与 push_setting_page 保持一致）：
/// - 顶部 40x4 圆角拖拽条
/// - 标题栏 + 右上角关闭按钮
/// - 选项列表最大高度 = 屏幕高 * 0.55，超出可滚动
/// - 选中项：文字加粗 + 主色高亮 + 右侧对勾
/// - 弹窗外边距 12，顶部 0
/// - 弹窗圆角 18
///
/// 已被以下场景使用：
/// - push_setting_page：选择通知方式
/// - upload_script_widget：选择脚本父目录
///
/// 复制 2 处相同弹窗后抽出，避免后续再有第三次复制。
class SelectorOption<T> {
  final T value;
  final String label;
  final String? subtitle;

  const SelectorOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

/// 显示通用弹窗选择器
///
/// 弹出后用户选择一个 [SelectorOption.value]，通过 [onSelected] 回调。
/// 如果用户点击空白/关闭按钮，弹窗关闭但 [onSelected] 不会触发。
Future<void> showSelectorSheet<T>({
  required BuildContext context,
  required String title,
  required List<SelectorOption<T>> options,
  required T? selectedValue,
  required ValueChanged<T> onSelected,
}) async {
  // 同步读取主题/毛玻璃状态（在弹窗弹出前一次性读取，避免异步内 ref 失效）
  final ProviderContainer container = ProviderScope.containerOf(context);
  final bool isCyber = container.read(themeProvider).themeMode == modeCyber;
  final bool blurEnabled = container.read(blurEffectProvider);
  // 弹窗列表项文案：选中态 = 主题色（保持）；未选中态 = 跟随自定义字体色
  //   - 主标题（label）→ 主字体色 titleColor
  //   - 副标题（subtitle）→ 次字体色 descColor
  final Color mainTextColor = container
      .read(themeProvider)
      .themeColor
      .titleColor();
  final Color subTextColor = container
      .read(themeProvider)
      .themeColor
      .descColor();

  await showCupertinoModalPopup<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: OptionalBlur(
            sigma: 20,
            child: Container(
              decoration: BoxDecoration(
                color: isCyber
                    ? Colors.black.withValues(alpha: blurEnabled ? 0.5 : 1.0)
                    : Colors.white.withValues(
                        alpha: blurEnabled ? 0.85 : 1.0,
                      ),
                borderRadius: BorderRadius.circular(18),
                border: isCyber
                    ? Border.all(
                        color: CyberColors.cyan.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : Border.all(
                        color: Colors.black.withValues(alpha: 0.1),
                        width: 0.5,
                        style: BorderStyle.solid,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部拖拽条
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    decoration: BoxDecoration(
                      color: isCyber
                          ? CyberColors.cyan.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isCyber
                                ? CyberColors.cyan
                                : AppleColors.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 22,
                            color: isCyber
                                ? CyberColors.titleWhite.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 0.5,
                    color: isCyber
                        ? CyberColors.cyan.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                  // 选项列表（最大高度 55% 屏幕高）
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = option.value == selectedValue;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onSelected(option.value);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        option.label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          // 选中 = 主题色（cyber cyan / accent，保持不变）
                                          // 未选中 = 跟随主字体色
                                          color: selected
                                              ? (isCyber
                                                    ? CyberColors.cyan
                                                    : AppleColors.accent)
                                              : mainTextColor,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                      if (option.subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          option.subtitle!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            // 副标题 = 次字体色（跟随）
                                            color: subTextColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    CupertinoIcons.checkmark_alt,
                                    size: 18,
                                    color: isCyber
                                        ? CyberColors.cyan
                                        : AppleColors.accent,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 弹窗选择器触发卡片（参考 push_setting_page "选择通知方式"）
///
/// 整张卡显示当前选中值的文字，点击后弹出 [showSelectorSheet] 让用户重新选择。
/// 圆角与其他 OtherPageCard 保持一致（18），与下拉框外观区分。
class SelectorFieldCard extends ConsumerWidget {
  final String hintText;
  final String currentValue;
  final String emptyHint;
  final VoidCallback onTap;

  const SelectorFieldCard({
    super.key,
    required this.hintText,
    required this.currentValue,
    required this.emptyHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final String displayText =
        currentValue.isEmpty ? emptyHint : currentValue;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: OtherPageCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  // 选择器当前显示值：非空时跟随主字体色，空值占位（如"根目录"）跟随次字体色
                  // 赛博/非赛博都走 themeColor，方便统一跟随用户自定义字体色
                  color: currentValue.isEmpty
                      ? ref.watch(themeProvider).themeColor.descColor()
                      : ref.watch(themeProvider).themeColor.titleColor(),
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              size: 16,
              color: isCyber ? CyberColors.cyan : null,
            ),
          ],
        ),
      ),
    );
  }
}

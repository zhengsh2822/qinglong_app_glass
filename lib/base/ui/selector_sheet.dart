import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glow_sheet.dart';
import 'package:qinglong_app/base/ui/other_page_card.dart';

/// 通用弹窗选择器（参考 push_setting_page 的"选择通知方式"）
///
/// 用于替代原生 DropdownButtonFormField 等"下来下拉"控件，
/// 弹出一个高光内发光风格的圆角弹窗（赛博模式为青色发光边框，非赛博模式为纯色高光卡片）。
///
/// 设计规范（对齐项目高光内发光设计语言）：
/// - 顶部 40x4 圆角拖拽条
/// - 标题栏 + 右上角关闭按钮
/// - 选项列表最大高度 = 屏幕高 * 0.5，超出可滚动
/// - 选中项：主色圆点标记 + 文字加粗高亮 + 右侧对勾 + 行背景微色
/// - 分隔线左右对称居中，只在选项之间显示
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
  // 同步读取主题状态（在弹窗弹出前一次性读取，避免异步内 ref 失效）
  final ProviderContainer container = ProviderScope.containerOf(context);
  final bool isCyber = container.read(themeProvider).themeMode == modeCyber;
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
  final Color accent = isCyber
      ? CyberColors.cyan
      : container.read(themeProvider).primaryColor;
  final Color dividerColor =
      isCyber ? const Color(0x22FFFFFF) : const Color(0xFFE5E5EA);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    isScrollControlled: true,
    enableDrag: true,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlowSheetContainer(
            isCyber: isCyber,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DragHandle(isCyber: isCyber),
                // 标题栏
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isCyber
                                ? CyberColors.cyan
                                : AppleColors.textPrimary,
                          ),
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
                Divider(height: 0.5, color: dividerColor),
                // 选项列表（最大高度 50% 屏幕高）
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final selected = option.value == selectedValue;
                      return _SelectorRow(
                        option: option,
                        selected: selected,
                        isCyber: isCyber,
                        mainTextColor: mainTextColor,
                        subTextColor: subTextColor,
                        dividerColor: dividerColor,
                        accent: accent,
                        showDivider: index != options.length - 1,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onSelected(option.value);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SelectorRow<T> extends StatelessWidget {
  final SelectorOption<T> option;
  final bool selected;
  final bool isCyber;
  final Color mainTextColor;
  final Color subTextColor;
  final Color dividerColor;
  final Color accent;
  final bool showDivider;
  final VoidCallback onTap;

  const _SelectorRow({
    required this.option,
    required this.selected,
    required this.isCyber,
    required this.mainTextColor,
    required this.subTextColor,
    required this.dividerColor,
    required this.accent,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: selected ? accent.withValues(alpha: 0.08) : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // 选中标记圆点
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? accent : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? accent
                            : (isCyber
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.25)),
                        width: selected ? 0 : 1.5,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            CupertinoIcons.checkmark_alt,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected ? accent : mainTextColor,
                          ),
                        ),
                        if (option.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            option.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(CupertinoIcons.checkmark_alt, size: 18, color: accent),
                ],
              ),
            ),
          ),
        ),
        // 分隔线左右对称居中，只在选项之间显示
        if (showDivider)
          Divider(height: 0.5, indent: 46, endIndent: 46, color: dividerColor),
      ],
    );
  }
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

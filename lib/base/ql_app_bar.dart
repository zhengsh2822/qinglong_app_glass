import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

class QlAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? backCall;
  final bool canBack;
  final Widget? backWidget;
  final bool canClick2Vip;
  /// 自定义 leading 区域宽度（默认 null 走 AppBar 默认 56）。当 backWidget
  /// 含多个按钮（如"编辑 + 名称排序"）时需传足够宽度避免截断。
  final double? leadingWidth;

  const QlAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backCall,
    this.canBack = true,
    this.backWidget,
    this.canClick2Vip = true,
    this.leadingWidth,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget back;

    if (backWidget != null) {
      back = backWidget!;
    } else {
      back = CupertinoButton(
        color: Colors.transparent,
        padding: EdgeInsets.zero,
        onPressed: () {
          if (backCall != null) {
            backCall!();
          } else {
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Center(
            child: Icon(
              CupertinoIcons.left_chevron,
              color: Theme.of(context).appBarTheme.iconTheme?.color,
            ),
          ),
        ),
      );
    }

    Widget appBar = AppBar(
      backgroundColor: Colors.transparent,
      leading: canBack ? back : null,
      leadingWidth: leadingWidth,
      automaticallyImplyLeading: canBack,
      title: GestureDetector(
        onTap: () {
          if (!canClick2Vip) return;
          if (SpUtil.getBool(spSingleInstance, defValue: false)) return;
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation1, animation2) =>
                      const ChangeAccountPage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        },
        child: Text(title),
      ),
      centerTitle: true,
      actions: [...?actions],
    );

    final themeMode = ref.watch(themeProvider).themeMode;
    final isWhite = themeMode == modeWhite;

    return Container(
      decoration: BoxDecoration(
        color: isWhite ? AppleColors.bgPrimary : null,
        gradient:
            isWhite
                ? null
                : LinearGradient(
                  colors: ref.watch(themeProvider).themeColor.appBarBg(),
                ),
        // 非赛博（苹果白）模式：顶部导航加 1px 纯白边框，与卡片高光语言一致
        border: isWhite ? Border.all(color: Colors.white, width: 1) : null,
      ),
      child: appBar,
    );
  }
}

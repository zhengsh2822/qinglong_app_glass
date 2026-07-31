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

  const QlAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backCall,
    this.canBack = true,
    this.backWidget,
    this.canClick2Vip = true,
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
      ),
      child: appBar,
    );
  }
}

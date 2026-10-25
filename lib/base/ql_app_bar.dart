import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/account_page_transition.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

class QlAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
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
  ConsumerState<QlAppBar> createState() => _QlAppBarState();
}

class _QlAppBarState extends ConsumerState<QlAppBar> {
  /// 标题区域（含左右空白）：共享转场的源矩形
  final GlobalKey _titleKey = GlobalKey();
  bool _opening = false;

  void _openAccountPage() {
    if (_opening) return;
    if (!widget.canClick2Vip) return;
    if (SpUtil.getBool(spSingleInstance, defValue: false)) return;

    final RenderBox? box =
        _titleKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      // 兜底：布局未完成时保持原行为（零时长直切）
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder:
              (context, animation1, animation2) => const ChangeAccountPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      return;
    }

    final Rect rect = box.localToGlobal(Offset.zero) & box.size;
    final TextStyle style = DefaultTextStyle.of(context).style;

    HapticFeedback.lightImpact();
    setState(() => _opening = true);

    pushAccountPageFromTitle(
      context: context,
      sourceRect: rect,
      sourceChild: Center(
        child: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _opening = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget back;

    if (widget.backWidget != null) {
      back = widget.backWidget!;
    } else {
      back = CupertinoButton(
        color: Colors.transparent,
        padding: EdgeInsets.zero,
        onPressed: () {
          if (widget.backCall != null) {
            widget.backCall!();
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
      leading: widget.canBack ? back : null,
      leadingWidth: widget.leadingWidth,
      automaticallyImplyLeading: widget.canBack,
      // 标题区域整体作为账号页共享转场的源（含左右空白）：
      // 点击 → 容器从标题矩形展开成账号页，返回时收回标题
      title: GestureDetector(
        key: _titleKey,
        onTap: _openAccountPage,
        behavior: HitTestBehavior.opaque,
        child: Text(widget.title),
      ),
      centerTitle: true,
      // titleSpacing 默认 16 会吃中间区 32px：360 逻辑宽设备上 env 页标题被截断成"环境…"，
      // 收窄至 4 给标题让出空间（标题与左右按钮实际间隙由各页 leading/actions 间距控制）
      titleSpacing: 4,
      actions: [...?widget.actions],
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

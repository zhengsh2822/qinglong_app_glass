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

  /// 标题槽内捕获的 DefaultTextStyle（= AppBar 标题样式）；
  /// 共享转场的幽灵标题必须用同款样式，否则字号/字重不一致产生错位感
  TextStyle? _titleStyle;

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
    // 必须用标题槽内捕获的样式（_titleStyle），
    // 外层 context 的 DefaultTextStyle 是正文字体（字号/字重都不对）
    final TextStyle style =
        _titleStyle ?? DefaultTextStyle.of(context).style;

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
      // 标题收缩包裹（文字本身）：centerTitle 在整个工具栏宽度上居中标题。
      // 若做成全宽触发区，无限宽组件无法被居中——文字会在不对称空隙里
      // 居中导致标题偏移。空白区域的账号页触发由 flexibleSpace 手势层承担。
      title: Builder(
        builder: (titleContext) {
          final TextStyle style = DefaultTextStyle.of(titleContext).style;
          _titleStyle = style;
          return GestureDetector(
            key: _titleKey,
            behavior: HitTestBehavior.opaque,
            onTap: _openAccountPage,
            // 转场期间隐藏真标题（与幽灵标题同款式同位置，只留一份）
            child: Opacity(
              opacity: _opening ? 0 : 1,
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          );
        },
      ),
      centerTitle: true,
      // titleSpacing 默认 16 会吃中间区 32px：360 逻辑宽设备上 env 页标题被截断成"环境…"，
      // 收窄至 4 给标题让出空间（标题与左右按钮实际间隙由各页 leading/actions 间距控制）
      titleSpacing: 4,
      actions: [...?widget.actions],
      // AppBar 空白区域（状态栏下沿、标题两侧）也统一触发账号页：
      // flexibleSpace 在 toolbar 下层，返回键/标题/actions 命中时优先响应，
      // 仅空白处落到这里
      flexibleSpace: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openAccountPage,
        child: const SizedBox.expand(),
      ),
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

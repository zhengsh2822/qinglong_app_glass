import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../theme.dart';

/// 固定顶部悬浮搜索框
///
/// 对齐 demos/search_bar_demo 的设计：
///  - 单层胶囊（不再"框中框"）
///  - 苹果模式：纯白不透明背景 + 极浅边框 + 内高光/内发光 + 柔和外投影（悬浮感）
///  - 赛博模式：深色不透明背景 + 青色发光边框 + 青色内发光 + 青色外发光（悬浮感）
///  - 图标在左 + 文字左对齐 + hint"搜索"
///
/// 注意：本组件**不使用 BackdropFilter 毛玻璃**。
/// 背景必须不透明，避免半透明 + 模糊导致"胶囊"看起来是"空心"，
/// 进而产生"下方紧贴色块"的视觉错觉（与底部导航悬浮效果对比）。
class SearchCell extends ConsumerStatefulWidget {
  final TextEditingController controller;

  const SearchCell({Key? key, required this.controller}) : super(key: key);

  @override
  ConsumerState createState() => _SearchCellState();
}

class _SearchCellState extends ConsumerState<SearchCell> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final bool isCyber = theme.themeMode == modeCyber;

    final Color bgColor =
        isCyber ? const Color(0xFF12121A) : Colors.white;
    final Color borderColor =
        isCyber
            ? CyberColors.cyan.withValues(alpha: 0.28)
            : const Color(0xFFF2F2F4);
    final Color textColor =
        isCyber ? CyberColors.titleWhite : AppleColors.textPrimary;
    final Color hintColor =
        isCyber ? CyberColors.hintGray : AppleColors.textHint;
    final Color iconColor = isCyber ? CyberColors.cyan : AppleColors.textHint;

    // 单层胶囊的悬浮外投影（按模式）
    final List<BoxShadow> boxShadows =
        isCyber
            ? [
                // 顶部青色高光（内发光）
                BoxShadow(
                  color: CyberColors.cyan.withValues(alpha: 0.18),
                  blurRadius: 2,
                  spreadRadius: 0.1,
                  offset: const Offset(0, -1),
                ),
                // 底部青色内发光
                BoxShadow(
                  color: CyberColors.cyan.withValues(alpha: 0.06),
                  blurRadius: 4,
                  spreadRadius: 0.2,
                  offset: const Offset(0, 1),
                ),
                // 青色外发光（悬浮）
                BoxShadow(
                  color: CyberColors.cyan.withValues(alpha: 0.04),
                  blurRadius: 7,
                  spreadRadius: 0.2,
                  offset: const Offset(0, 3),
                ),
                // 青色远投影
                BoxShadow(
                  color: CyberColors.cyan.withValues(alpha: 0.015),
                  blurRadius: 11,
                  spreadRadius: 0.3,
                  offset: const Offset(0, 5),
                ),
              ]
            : [
                // 顶部浅灰高光（内发光）
                BoxShadow(
                  color: const Color(0xFFFAFAFA).withValues(alpha: 0.6),
                  blurRadius: 2,
                  spreadRadius: 0.1,
                  offset: const Offset(0, -1),
                ),
                // 底部纯白内发光
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 3,
                  spreadRadius: 0.2,
                  offset: const Offset(0, 1),
                ),
                // 柔和外投影（极弱，几乎不遮下方列表第一项）
                BoxShadow(
                  color: const Color(0x0A000000),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: const Color(0x05000000),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: isCyber ? 0.5 : 1),
        boxShadow: boxShadows,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.search, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: 1,
              textAlign: TextAlign.left,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(fontSize: 14, color: textColor),
              cursorColor: iconColor,
              decoration: InputDecoration(
                hintText: "搜索",
                hintStyle: TextStyle(fontSize: 14, color: hintColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                widget.controller.text = "";
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  CupertinoIcons.clear_circled_solid,
                  size: 16,
                  color: iconColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:qinglong_app/utils/share_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/ui/pauseable_timer_mixin.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/log_scroll_button.dart';
import 'package:qinglong_app/module/scan_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../../../base/commit_button.dart';
import '../../../base/http/api.dart';
import '../../../base/theme.dart';
import '../../../base/ui/log_text_view.dart';

class InTimeLogPage extends ConsumerStatefulWidget {
  final String cronId;
  final bool needTimer;
  final String title;
  final String? command;

  const InTimeLogPage(
    this.cronId,
    this.needTimer,
    this.title, {
    Key? key,
    this.command,
  }) : super(key: key);

  @override
  _InTimeLogPageState createState() => _InTimeLogPageState();
}

class _InTimeLogPageState extends ConsumerState<InTimeLogPage>
    with LazyLoadState<InTimeLogPage>, PauseableTimerMixin<InTimeLogPage> {
  String? content;

  /// 传给 LogTextView 的渲染内容：超长日志仅渲染尾部（实时页自动滚底，
  /// 完整内容仍可分享），避免 2s 轮询的全量重建成本随日志增长无上限
  String? _renderContent;

  bool isRequest = false;
  bool canRequest = true;
  int _emptyCount = 0;
  bool alwaysAuthScroll = false;

  ScrollController? controller = ScrollController();
  bool showVIPReminder = false;

  getLogData() async {
    if (!canRequest) return;
    if (isRequest) return;
    if (!mounted) return;
    isRequest = true;
    HttpResponse<String> response = await SingleAccountPageState.ofApi(
      context,
    ).inTimeLog(widget.cronId);

    if (!mounted) return;
    isRequest = false;
    if (response.success) {
      if (!mounted) return;
      String? newContent = response.bean;
      if (newContent == null || newContent.isEmpty) {
        _emptyCount++;
        if (_emptyCount >= 3) {
          stopPauseableTimer();
          canRequest = false;
          content = "";
          _renderContent = "";
          if (!mounted) return;
          setState(() {});
        }
        return;
      }
      final bool changed = newContent != content;
      if (changed) {
        _emptyCount = 0;
      }
      final String prev = content ?? "";
      content = newContent;

      if (changed) {
        // 依赖检测只跑新增增量：全量正则随日志增长变慢（MB 级日志每 2s 全量
        // 扫描曾把主线程卡到 ANR），且依赖报错只会出现在新增输出里
        final String delta =
            (newContent.length >= prev.length && newContent.endsWith(prev))
                ? newContent.substring(prev.length)
                : newContent;
        List<String> foundDeps = ScanPageState.foundAllReg(delta);
        if (foundDeps.isNotEmpty &&
            widget.command != null &&
            (widget.command!.endsWith(".js") ||
                widget.command!.endsWith(".ts") ||
                widget.command!.endsWith(".py")) &&
            SpUtil.getInt(spVIP, defValue: typeNormal) != typeNormal) {
          Api api = Api(SingleAccountPageState.of(context)?.index ?? 0);
          bool isPy = widget.command!.endsWith(".py");
          for (String found in foundDeps) {
            var result = await ScanPageState.autoInstallFounded(
              api,
              found,
              isPy,
            );
            if (result == true) {
              "已安装依赖 $found".toast();
            }
          }
        }
      }

      if (changed && alwaysAuthScroll) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          if (!mounted) return;
          if ((controller?.hasClients ?? false)) {
            controller!.animateTo(
              controller!.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.linear,
            );
          }
        });
      }

      // 渲染裁剪：仅渲染尾部 96KB；内容未变时不再 setState 重建
      // （修复：任务持续输出时每 2s 全量重建巨大日志文本 → 主线程卡死 ANR）
      final String? newRender =
          (newContent.length > 98304)
              ? newContent.substring(newContent.length - 98304)
              : newContent;
      if (newRender != _renderContent) {
        _renderContent = newRender;
        if (!mounted) return;
        setState(() {});
      }
    } else {
      if (!hasToastedFailed) {
        hasToastedFailed = true;
        response.message?.toast();
      }
    }
  }

  bool hasToastedFailed = false;

  @override
  void dispose() {
    cancelPauseableTimer();
    controller?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    return Builder(
      builder: (context) {
        return Scaffold(
          floatingActionButton: LogScrollButton(
            active: alwaysAuthScroll,
            onTap: () {
              setState(() {
                alwaysAuthScroll = !alwaysAuthScroll;
              });
            },
          ),
          appBar: QlAppBar(
            canBack: true,
            actions: [
              CommitButton(
                title: "分享",
                onTap: () {
                  ShareUtils.share(content ?? "");
                },
              ),
            ],
            title: widget.title,
          ),
          body:
              (content == null)
                  ? const Center(child: LoadingWidget())
                  : CupertinoScrollbar(
                    child: LogTextView(
                      content: _renderContent ?? content,
                      accountIndex:
                          SingleAccountPageState.of(context)?.index ?? 0,
                      scrollController: controller,
                    ),
                  ),
        );
      },
    );
  }

  @override
  void onLazyLoad() {
    alwaysAuthScroll = SpUtil.getBool(spLogAutoJump2Bottom, defValue: false);
    if (widget.needTimer) {
      // 金标联盟公平调度：使用可暂停的周期 Timer，应用进入后台时自动暂停
      startPauseableTimer(const Duration(seconds: 2), () => getLogData());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        getLogData();
      });
    }
  }
}

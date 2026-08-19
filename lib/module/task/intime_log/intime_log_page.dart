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
          if (!mounted) return;
          setState(() {});
        }
        return;
      }
      if (content != newContent) {
        _emptyCount = 0;
      }
      content = newContent;

      // 使用新的 foundAllReg 同时搜索 NodeJS 和 Python 缺失依赖
      List<String> foundDeps = ScanPageState.foundAllReg(content ?? "");
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
      if (alwaysAuthScroll) {
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
      if (!mounted) return;
      setState(() {});
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
                        content: content,
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

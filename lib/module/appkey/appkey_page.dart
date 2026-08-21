import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/base_state_widget.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/capsule_glow_card.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_slide_action.dart';
import 'package:qinglong_app/base/ui/floating_search_bar_area.dart';
import 'package:qinglong_app/base/ui/tag_chip.dart';
import 'package:qinglong_app/module/appkey/appkey_detail_page.dart';
import 'package:qinglong_app/module/appkey/appkey_viewmodel.dart';
import 'package:qinglong_app/utils/utils.dart';

import 'add_appkey_page.dart';

class AppKeyPage extends ConsumerStatefulWidget {
  const AppKeyPage({Key? key}) : super(key: key);

  @override
  _AppKeyPageState createState() => _AppKeyPageState();
}

class _AppKeyPageState extends ConsumerState<AppKeyPage> {
  TextEditingController searchText = TextEditingController();
  Timer? _searchDebounce;

  ScrollController controller = ScrollController();

  bool buttonshow = false;

  void scrollToTop() {
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(floatingButtonVisibility);
    searchText.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        setState(() {});
      });
    });
  }

  void floatingButtonVisibility() {
    double y = controller.offset;
    if (y > MediaQuery.of(context).size.height / 2) {
      if (buttonshow == true) return;
      setState(() {
        buttonshow = true;
      });
    } else {
      if (buttonshow == false) return;
      setState(() {
        buttonshow = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    Widget scaffold = Scaffold(
      // 赛博模式下设为透明，让 CyberBackground 的渐变背景透出；苹果模式用主题默认背景
      backgroundColor: isCyber ? Colors.transparent : null,
      floatingActionButton: Visibility(
        visible: buttonshow,
        child: FloatingActionButton(
          mini: true,
          onPressed: () {
            scrollToTop();
          },
          elevation: 2,
          backgroundColor: Colors.white,
          child: const Icon(CupertinoIcons.up_arrow),
        ),
      ),
      appBar: QlAppBar(
        title: "应用管理",
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.of(context)
                  .push(
                    CupertinoPageRoute(
                      builder: (context) => const AddAppKeyPage(bean: {}),
                    ),
                  )
                  .then((value) {
                    if (value != null && value == true) {
                      ref
                          .read(
                            SingleAccountPageState.ofAppKeyProvider(context)(
                              getProviderName(context),
                            ),
                          )
                          .loadData(context);
                    }
                  });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Center(child: Icon(CupertinoIcons.add, size: 24)),
            ),
          ),
        ],
      ),
      body: BaseStateWidget<AppKeyViewModel>(
        builder: (ref, model, child) {
          return body(model, getListByType(model), ref);
        },
        model: SingleAccountPageState.ofAppKeyProvider(context)(
          getProviderName(context),
        ),
        lazyLoad: true,
        onReady: (viewModel) {
          viewModel.loadData(context);
        },
      ),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  Widget body(
    AppKeyViewModel model,
    List<Map<String, dynamic>> list,
    WidgetRef ref,
  ) {
    return FloatingSearchBarArea(
      controller: searchText,
      listView: RefreshIndicator(
        color: Theme.of(context).primaryColor,
        onRefresh: () async {
          return model.loadData(context, false);
        },
        child: IconTheme(
          data: const IconThemeData(size: 25),
          child: SlidableAutoCloseBehavior(
            child: ListView.separated(
              // 顶部间距 64 = 搜索框区域(10+44) + 间距10，放在列表内部（滚动时被内容填充，无背景色块）
              padding: const EdgeInsets.only(top: 64, bottom: 80),
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              itemBuilder: (context, index) {
                Map<String, dynamic> item = list[index];
                if (searchText.text.isEmpty ||
                    (item["name"]?.toLowerCase().contains(
                          searchText.text.toLowerCase(),
                        ) ??
                        false)) {
                  return AppKeyItemCell(item, ref);
                } else {
                  return const SizedBox.shrink();
                }
              },
              itemCount: list.length,
              separatorBuilder: (BuildContext context, int index) {
                Map<String, dynamic> item = list[index];
                if (searchText.text.isEmpty ||
                    (item["name"]?.toLowerCase().contains(
                          searchText.text.toLowerCase(),
                        ) ??
                        false)) {
                  return const SizedBox(height: 12);
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchText.dispose();
    controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getListByType(AppKeyViewModel model) {
    return model.list;
  }
}

class AppKeyItemCell extends StatelessWidget {
  final Map<String, dynamic> bean;
  final WidgetRef ref;

  const AppKeyItemCell(this.bean, this.ref, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    // 纯内容卡片（无独立阴影；阴影/高光由外层 CapsuleGlowCard 承载，
    // 与 subscribe/env 页面统一，避免阴影被 ClipRRect 裁切）
    Widget cardChild = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppleColors.radiusCard),
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => AppKeyDetailDetailPage(bean),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bean["name"] ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ref.watch(themeProvider).themeColor.titleColor(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  runSpacing: 6,
                  spacing: 6,
                  children: AppKeyViewModel.getScopeNames(
                    (bean["scopes"] as List<dynamic>?),
                  ).map((e) => TagChip(label: e)).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // 统一结构：CapsuleGlowCard（外层阴影/高光，赛博/非赛博一致）→
    // ClipRRect(18) → Slidable → 纯内容卡片（与 subscribe/env 对齐）
    return CapsuleGlowCard(
      isCyber: isCyber,
      isPinned: false,
      margin: const EdgeInsets.symmetric(horizontal: AppleColors.spaceMd),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppleColors.radiusCard),
        child: Slidable(
          key: ValueKey(getAppKeyId(bean)),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.55,
            children: [
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFF00F0FF) : const Color(0xff5D5E70),
                icon: CupertinoIcons.pencil_outline,
                label: '编辑',
                cyberMode: isCyber,
                width: double.infinity,
                cornerRadius: 12,
                iconSize: 22,
                outerGap: 4,
                innerGap: 6,
                onTap: () {
                  Navigator.of(context)
                      .push(
                        CupertinoPageRoute(
                          builder: (context) => AddAppKeyPage(bean: bean),
                        ),
                      )
                      .then((value) {
                        if (value != null && value == true) {
                          ref
                              .read(
                                SingleAccountPageState.ofAppKeyProvider(
                                  context,
                                )(getProviderName(context)),
                              )
                              .loadData(context);
                        }
                      });
                },
              ),
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFFA356D6) : const Color(0xffA356D6),
                icon: CupertinoIcons.arrow_2_circlepath,
                label: '重置',
                cyberMode: isCyber,
                width: double.infinity,
                cornerRadius: 12,
                iconSize: 22,
                outerGap: 4,
                innerGap: 6,
                onTap: () {
                  WidgetsBinding.instance.endOfFrame.then((value) {
                    _reset(context);
                  });
                },
              ),
              AppSlideButton(
                context: context,
                color: isCyber ? const Color(0xFFFF3D5C) : const Color(0xffEA4D3E),
                icon: CupertinoIcons.delete,
                label: '删除',
                cyberMode: isCyber,
                width: double.infinity,
                cornerRadius: 12,
                iconSize: 22,
                outerGap: 4,
                innerGap: 6,
                onTap: () {
                  WidgetsBinding.instance.endOfFrame.then((value) {
                    _del(context, ref);
                  });
                },
              ),
            ],
          ),
          child: cardChild,
        ),
      ),
    );
  }

  void _del(BuildContext context1, WidgetRef ref) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    if (isCyber) {
      showCyberConfirmDialog(
        context1,
        title: "确认删除",
        content: "确认删除应用 ${bean["name"] ?? ""} 吗",
        danger: true,
      ).then((confirmed) {
        if (confirmed == true) {
          ref
              .read(
                SingleAccountPageState.ofAppKeyProvider(context1)(
                  getProviderName(context1),
                ),
              )
              .delAppKey(context1, getAppKeyId(bean));
        }
      });
      return;
    }
    showCupertinoDialog(
      context: context1,
      useRootNavigator: false,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text("确认删除"),
            content: Text("确认删除应用 ${bean["name"] ?? ""} 吗"),
            actions: [
              CupertinoDialogAction(
                child: const Text(
                  "取消",
                  style: TextStyle(color: Color(0xff999999)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              CupertinoDialogAction(
                child: Text(
                  "确定",
                  style: TextStyle(
                    color: ref.watch(themeProvider).primaryColor,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(
                        SingleAccountPageState.ofAppKeyProvider(context1)(
                          getProviderName(context1),
                        ),
                      )
                      .delAppKey(context1, getAppKeyId(bean));
                },
              ),
            ],
          ),
    );
  }

  void _reset(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    if (isCyber) {
      showCyberConfirmDialog(
        context,
        title: "确认重置应用 ${bean["name"]} 的Secret吗",
        content: "重置Secret会让当前应用所有token失效",
        danger: true,
      ).then((confirmed) {
        if (confirmed == true) {
          ref
              .read(
                SingleAccountPageState.ofAppKeyProvider(context)(
                  getProviderName(context),
                ),
              )
              .resetAppKey(context, getAppKeyId(bean));
        }
      });
      return;
    }
    showCupertinoDialog(
      context: context,
      useRootNavigator: false,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text("确认重置应用 ${bean["name"]} 的Secret吗"),
            content: const Text("重置Secret会让当前应用所有token失效"),
            actions: [
              CupertinoDialogAction(
                child: const Text(
                  "取消",
                  style: TextStyle(color: Color(0xff999999)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              CupertinoDialogAction(
                child: Text(
                  "确定",
                  style: TextStyle(
                    color: ref.watch(themeProvider).primaryColor,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(
                        SingleAccountPageState.ofAppKeyProvider(context)(
                          getProviderName(context),
                        ),
                      )
                      .resetAppKey(context, getAppKeyId(bean));
                },
              ),
            ],
          ),
    );
  }
}

String getAppKeyId(Map<String, dynamic> bean) {
  if (bean.containsKey("_id")) {
    return bean["_id"] ?? "";
  }
  return bean["id"]?.toString() ?? "";
}

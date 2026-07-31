import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/other_page_card.dart';
import 'package:qinglong_app/module/in_app_purchase_page.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';
import 'package:qinglong_app/module/others/sort_account_page.dart';
import 'package:qinglong_app/module/others/text_size_page.dart';
import 'package:qinglong_app/module/others/update_password_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/floating_clock_service.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:path/path.dart' as ints;

import '../../main.dart';
import '../appkey/appkey_page.dart';
import '../home/system_bean.dart';
import '../poet_page.dart';
import '../push_setting_page.dart';
import '../scan_page.dart';
import '../task/task_page.dart';
import '../update_max_account_page.dart';

class OtherPage extends ConsumerStatefulWidget {
  const OtherPage({Key? key}) : super(key: key);

  @override
  OtherPageState createState() => OtherPageState();
}

class OtherPageState extends ConsumerState<OtherPage>
    with LazyLoadState<OtherPage> {
  var toggleValue = false;
  String? userIcon;
  String userName = "青龙客户端";
  var desc = "欢迎使用青龙客户端".obs;
  Map<String, dynamic> poetData = {};

  @override
  void initState() {
    super.initState();
    delLogsByExperiedDate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  final ScrollController _scrollController = ScrollController();
  GlobalKey<RefreshIndicatorState> refreshKey = GlobalKey();

  Future<void> move2Top() async {
    if (_scrollController.offset !=
        _scrollController.position.minScrollExtent) {
      await scrollToTop();
    } else {
      if (refreshKey.currentState?.mounted ?? false) {
        await refreshKey.currentState?.show();
      }
    }
  }

  Future<void> scrollToTop() async {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  /// 长按修改账号名称（别名）
  void _editAlias() {
    final userInfo = SingleAccountPageState.ofUserInfo(context);
    final currentIndex = SingleAccountPageState.of(context)?.index ?? 0;
    final currentAlias = userInfo.alias ?? "";
    showInputDialog(
      context,
      title: '修改名称',
      hintText: '请输入名称',
      initialValue: currentAlias,
    ).then((newAlias) {
      if (newAlias == null) return;
      final trimmed = newAlias.trim();
      if (trimmed == currentAlias) return;
      final alias = trimmed.isEmpty ? null : trimmed;
      // 更新当前账号的别名（含持久化）
      userInfo.updateToken(
        currentIndex,
        userInfo.host,
        userInfo.token,
        userInfo.useSecretLogined,
        alias,
      );
      // 同步更新历史账号的别名
      final multiVM = getIt<MultiAccountUserInfoViewModel>();
      for (final bean in multiVM.historyAccounts) {
        if (bean.host == userInfo.host) {
          bean.alias = alias;
          multiVM.save2HistoryAccount(bean);
          break;
        }
      }
      "名称已更新".toast();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    Widget body = RefreshIndicator(
      key: refreshKey,
      onRefresh: () async {
        await loadPoet();
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom:
                MediaQuery.of(context).viewPadding.bottom +
                kBottomNavigationBarHeight +
                50,
          ),
          child: Column(
            children: [
              // 顶部用户信息卡片（替代原 250px 色块，与下方卡片样式统一）
              OtherPageCard(
                margin: const EdgeInsets.fromLTRB(
                  AppleColors.spaceMd,
                  AppleColors.spaceMd,
                  AppleColors.spaceMd,
                  0,
                ),
                padding: const EdgeInsets.fromLTRB(15, 20, 15, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (SpUtil.getInt(spVIP, defValue: typeNormal) ==
                            typeNormal) {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder:
                                  (context) => const InAppPurchasePage(
                                    fromDirectly: true,
                                  ),
                            ),
                          );
                          return;
                        } else {
                          if (SpUtil.getBool(
                            spSingleInstance,
                            defValue: false,
                          )) {
                            return;
                          }
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation1, animation2) =>
                                      const ChangeAccountPage(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        }
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                (userIcon != null && userIcon!.isNotEmpty)
                                    ? Image.network(
                                      userIcon!,
                                      width: 60,
                                      height: 60,
                                      errorBuilder: (_, __, ___) {
                                        return Image.asset(
                                          getImageByVIPLogo(),
                                          width: 60,
                                          height: 60,
                                        );
                                      },
                                    )
                                    : Image.asset(
                                      getImageByVIPLogo(),
                                      width: 60,
                                      height: 60,
                                    ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                GestureDetector(
                                  onLongPress: () => _editAlias(),
                                  child: Text(
                                    (SingleAccountPageState.ofUserInfo(
                                                  context,
                                                ).alias ==
                                                null ||
                                            SingleAccountPageState.ofUserInfo(
                                              context,
                                            ).alias!.isEmpty)
                                        ? userName
                                        : SingleAccountPageState.ofUserInfo(
                                          context,
                                        ).alias!,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color:
                                          isCyber
                                              ? CyberColors.titleWhite
                                              : ref
                                                  .watch(themeProvider)
                                                  .themeColor
                                                  .titleColor(),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Obx(
                                  () => GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (poetData.isEmpty) return;
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder:
                                              (context) =>
                                                  PoetPage(data: poetData),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      desc.value,
                                      style: TextStyle(
                                        color:
                                            isCyber
                                                ? CyberColors.descColor
                                                : AppleColors.textSecondary,
                                        fontSize: isCyber ? 12 : 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFeatureButton(
                          title: "仪表盘",
                          imagePath: "assets/images/icon_c.png",
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed(Routes.routeDashboard);
                          },
                        ),
                        _buildFeatureButton(
                          title:
                              getIt<SystemBean>(
                                    instanceName:
                                        (SingleAccountPageState.of(
                                                  context,
                                                )?.index ??
                                                0)
                                            .toString(),
                                  ).isUpperVersion2_13_0()
                                  ? "订阅管理"
                                  : "拉库管理",
                          imagePath: "assets/images/icon_subsctibe.png",
                          onTap: () {
                            if (getIt<SystemBean>(
                              instanceName:
                                  (SingleAccountPageState.of(
                                            context,
                                          )?.index ??
                                          0)
                                      .toString(),
                            ).isUpperVersion2_13_0()) {
                              Navigator.of(
                                context,
                              ).pushNamed(Routes.routeSubscribeList);
                            } else {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder:
                                      (context) => const TaskPage(
                                        onlyShowPullRepo: true,
                                      ),
                                ),
                              );
                            }
                          },
                        ),
                        _buildFeatureButton(
                          title: "脚本管理",
                          imagePath: "assets/images/icon_s.png",
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed(Routes.routeScript);
                          },
                        ),
                        _buildFeatureButton(
                          title: "依赖管理",
                          imagePath: "assets/images/icon_d.png",
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed(Routes.routeDependency);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              OtherPageCard(
                margin: const EdgeInsets.only(
                  left: AppleColors.spaceMd,
                  right: AppleColors.spaceMd,
                  top: AppleColors.spaceLg,
                ),
                onTap: () {
                  Navigator.of(context)
                      .push(
                        CupertinoPageRoute(
                          builder:
                              (context) =>
                                  const InAppPurchasePage(fromDirectly: true),
                        ),
                      )
                      .then((value) {
                        setState(() {});
                      });
                },
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 15,
                ),
                child: Row(
                  children: [
                    Text(
                      "APP功能介绍",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isCyber ? 16 : 17,
                        color:
                            isCyber
                                ? CyberColors.titleWhite
                                : AppleColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: AppleColors.spaceLg),
              OtherPageCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    Text(
                      "多帐号设置/第三方功能",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isCyber ? 16 : 17,
                        color:
                            isCyber
                                ? CyberColors.titleWhite
                                : AppleColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: buildOtherFun2(
                            "多账号数",
                            CupertinoIcons.infinite,
                            () {
                              if (SpUtil.getBool(
                                spSingleInstance,
                                defValue: false,
                              )) {
                                '请先进入 系统设置 关闭单实例模式'.toast();
                                return;
                              }

                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder:
                                      (context) => const UpdateMaxAccountPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: buildOtherFun2(
                            "京东助手",
                            CupertinoIcons.gift,
                            () {
                              Navigator.of(context).pushNamed(Routes.routeJdck);
                            },
                          ),
                        ),
                        Expanded(
                          child: buildOtherFun2(
                            "悬浮时间",
                            CupertinoIcons.clock,
                            () async {
                              final started =
                                  await FloatingClockService.toggleFloating();
                              if (!started) {
                                '请授予悬浮窗权限后再次点击'.toast();
                              } else {
                                '悬浮时钟已开启'.toast();
                              }
                            },
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppleColors.spaceLg),
              OtherPageCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    Text(
                      "高级功能",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isCyber ? 16 : 17,
                        color:
                            isCyber
                                ? CyberColors.titleWhite
                                : AppleColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildOtherFun2(
                          "扫描依赖",
                          CupertinoIcons.doc_text_search,
                          () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => const ScanPage(),
                              ),
                            );
                          },
                        ),
                        buildOtherFun2(
                          "字体大小",
                          CupertinoIcons.textformat_size,
                          () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => const TextSizePage(),
                              ),
                            );
                          },
                        ),
                        buildOtherFun2("文件备份", CupertinoIcons.cloud_upload, () {
                          Navigator.of(context).pushNamed(Routes.routeICloud);
                        }),
                        if (!SpUtil.getBool(spSingleInstance, defValue: false))
                          buildOtherFun2("账号排序", CupertinoIcons.arrow_swap, () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => const SortAccountPage(),
                              ),
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              const SizedBox(height: AppleColors.spaceLg),
              OtherPageCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    Text(
                      "基础功能",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isCyber ? 16 : 17,
                        color:
                            isCyber
                                ? CyberColors.titleWhite
                                : AppleColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildOtherFun2(
                          "任务日志",
                          CupertinoIcons.square_stack_3d_down_right,
                          () {
                            Navigator.of(
                              context,
                            ).pushNamed(Routes.routeTaskLog);
                          },
                        ),
                        buildOtherFun2(
                          "登录日志",
                          CupertinoIcons.text_badge_checkmark,
                          () {
                            if (SingleAccountPageState.ofUserInfo(
                              context,
                            ).useSecretLogined) {
                              "使用client_id方式登录无法获取登录日志".toast();
                            } else {
                              Navigator.of(
                                context,
                              ).pushNamed(Routes.routeLoginLog);
                            }
                          },
                        ),
                        buildOtherFun2("应用设置", CupertinoIcons.gear_alt, () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => const AppKeyPage(),
                            ),
                          );
                        }),
                        buildOtherFun2("通知设置", CupertinoIcons.envelope, () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => const PushSettingPage(),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildOtherFun2("修改密码", CupertinoIcons.lock_shield, () {
                          if (SingleAccountPageState.ofUserInfo(
                            context,
                          ).useSecretLogined) {
                            "使用client_id方式登录无法修改密码".toast();
                          } else {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder:
                                    (context) => const UpdatePasswordPage(),
                              ),
                            );
                          }
                        }),
                        buildOtherFun2(
                          "日志设置",
                          CupertinoIcons.gobackward_30,
                          () {
                            _delLog(context);
                          },
                        ),
                        buildOtherFun2(
                          "系统设置",
                          CupertinoIcons.shield_lefthalf_fill,
                          () {
                            Navigator.of(
                              context,
                            ).pushNamed(Routes.routeSetting);
                          },
                        ),
                        buildOtherFun2("关于软件", CupertinoIcons.info_circle, () {
                          Navigator.of(context).pushNamed(Routes.routeAbout);
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height:
                    kBottomNavigationBarHeight +
                    MediaQuery.of(context).viewPadding.bottom,
              ),
            ],
          ),
        ),
      ),
    );
    if (isCyber) {
      body = CyberBackground(child: body);
    }
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          isCyber
              ? CyberColors.bg
              : ref.watch(themeProvider).themeColor.bg2Color(),
      body: body,
    );
  }

  void _delLog(BuildContext context) async {
    // 立即弹窗（用默认值 30 占位），通过 valueLoader 异步加载当前频率
    // 避免冷启动首次点击时"等网络请求才弹窗"的延迟感
    final days = await showFrequencyDialog(
      context,
      title: '日志删除频率',
      initialValue: 30,
      maxValue: 1000,
      valueLoader: () async {
        var response = await SingleAccountPageState.ofApi(context).logDel();
        if (response.success) {
          final bean = response.bean;
          if (bean != null) {
            // 新版青龙 API: GET /api/system/config 返回 info.logRemoveFrequency
            // 旧版兼容: 顶层 frequency 或 info.frequency
            final freq = bean.info?.logRemoveFrequency ??
                bean.frequency ??
                bean.info?.frequency;
            if (freq != null) {
              return freq;
            }
          }
        }
        return null;
      },
    );
    if (days != null) {
      commitLogDel(days);
    }
  }

  void commitLogDel(int time) async {
    var response = await SingleAccountPageState.ofApi(context).logDelTime(time);
    if (response.success) {
      "修改成功".toast();
    } else {
      response.message?.toast();
    }
  }

  /// 功能按钮（带图片 + 文字，AppleUI 风格）
  /// 用于 4 按钮和 8 按钮卡片，4 个按钮用 spaceEvenly 紧凑排列
  Widget _buildFeatureButton({
    required String title,
    required String imagePath,
    required GestureTapCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 直接显示原图，保留图片细节（水滴/书签/文档/齿轮等）
            // 不使用 ColorFiltered+srcIn，否则图片内部白色细节会变纯色
            Image.asset(imagePath, width: 28, height: 28, fit: BoxFit.contain),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: ref.watch(themeProvider).themeColor.titleColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOtherFun(String title, String icon, GestureTapCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
          child: Column(
            children: [
              // 直接显示原图，保留图片细节
              Image.asset(icon, width: 24, fit: BoxFit.cover),
              const SizedBox(height: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: ref.watch(themeProvider).themeColor.titleColor(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildOtherFun2(String title, IconData icon, GestureTapCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
          child: Column(
            children: [
              Icon(
                icon,
                color: ref.watch(themeProvider).primaryColor,
                size: 24,
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: ref.watch(themeProvider).themeColor.titleColor(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String getImageByVIP() {
    return "assets/images/normal.png";
  }

  String getImageByVIPLogo() {
    return "assets/images/ql.png";
  }

  @override
  void onLazyLoad() async {
    var response = await SingleAccountPageState.ofApi(context).user();

    if (response.success) {
      userIcon = response.bean?.avatar;
      userName = response.bean?.username ?? "青龙客户端";
      if (userIcon != null && userIcon!.isNotEmpty) {
        userIcon =
            "${SingleAccountPageState.ofUserInfo(context).host}/api/static/$userIcon";
      }
      setState(() {});
    }
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      loadPoet();
    });
  }

  void delLogsByExperiedDate() async {
    try {
      int before = SpUtil.getInt(
        spLocalBackUpFileExperiedTime,
        defValue: getDefaultLogExperiedTime(),
      );
      String now = DateFormat('yyyy-MM-dd').format(DateTime.now()); //获取多少天前的日期

      print("...$before天之前的文件全部删除");

      Directory directory = Directory(
        "${await FileUtil(SingleAccountPageState.of(context)?.index ?? 0).localPath}/",
      );

      List<FileSystemEntity> list = directory.listSync();

      for (FileSystemEntity file in list) {
        String date = ints.basename(file.path);
        var a = DateTime.tryParse(date);
        var b = DateTime.tryParse(now);

        if (a != null && b != null) {
          if (b.difference(a).inDays > before) {
            if (await file.exists()) {
              await file.delete(recursive: true);
              print("删除成功${file.path}");
            }
          } else {
            print("不用删除${file.path}");
          }
        } else {
          print("时间格式出错${file.path}");
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> loadPoet() async {
    try {
      Dio dio = Dio(
        BaseOptions(
          receiveTimeout: Duration(milliseconds: 10000),
          connectTimeout: Duration(milliseconds: 10000),
        ),
      );

      if (!SpUtil.haveKey(spPoetToken)) {
        var tokenResponse = await dio.get("https://v2.jinrishici.com/token");

        if (tokenResponse.statusCode == 200) {
          String? token = tokenResponse.data["data"];
          if (token != null && token.isNotEmpty) {
            SpUtil.putString(spPoetToken, token);
          }
        }
      }

      var response = await dio.get(
        "https://v2.jinrishici.com/one.json",
        options: Options(
          headers: {
            "X-User-Token": SpUtil.getString(spPoetToken, defValue: ""),
          },
        ),
      );
      if (response.statusCode == 200) {
        poetData.clear();
        poetData.addAll(response.data as Map<String, dynamic>);
        desc.value = poetData["data"]?["content"]?.toString() ?? "欢迎使用青龙客户端";
      }
    } catch (e) {}
  }
}

int getDefaultLogExperiedTime() {
  int count = 5;
  if (SpUtil.getInt(spVIP, defValue: typeNormal) == typeVIP) {
    count = 5;
  } else {
    count = 30;
  }
  return count;
}

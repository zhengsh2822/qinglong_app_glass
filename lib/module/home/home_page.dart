import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/liquid_glass_nav_bar.dart';
import 'package:qinglong_app/base/ui/blur_effect.dart';
import 'package:qinglong_app/base/ui/slidable_close_notifier.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/config_page.dart';
import 'package:qinglong_app/module/env/env_page.dart';
import 'package:qinglong_app/module/home/version_history_bean.dart';
import 'package:qinglong_app/module/others/other_page.dart';
import 'package:qinglong_app/module/task/task_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/login_helper.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../../base/multi_account_userinfo_viewmodel.dart';
import '../../base/userinfo_viewmodel.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  List<IndexBean> titles = [];

  // 底部 tab 页面控制器：与顶部 TabBar 同机制（PageView + animateToPage）
  // NeverScrollableScrollPhysics 禁手势，仅由底部 tab 点击驱动平滑滑动
  // 惰性初始化：initialPage 需读 provider，需等 build 有 context 后创建
  PageController? _pageController;

  @override
  void initState() {
    initTitles();
    super.initState();
    SingleAccountPageState.of(context)?.registerICloud();
    SingleAccountPageState.of(
      context,
    )?.registerHttp(SingleAccountPageState.ofUserInfo(context).host!);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      getSystemBean(context);
    });
  }

  static void updateVersionHistory(VersionHistoryBean versionHistoryBean) {
    String json = SpUtil.getString(spVersioCodeHistory, defValue: "[]");
    List<dynamic> temp = jsonDecode(json) as List<dynamic>;
    temp.add(versionHistoryBean.toJson());
    SpUtil.putString(spVersioCodeHistory, jsonEncode(temp));
  }

  static String? getCurrentVersion(String? host) {
    if (host != null && host.isNotEmpty) {
      String json = SpUtil.getString(spVersioCodeHistory, defValue: "[]");

      List<dynamic> temp = jsonDecode(json) as List<dynamic>;

      if (temp.isNotEmpty) {
        var list = temp.map((e) => VersionHistoryBean.fromJson(e)).toList();

        String? version =
            list
                .firstWhere(
                  (element) => element.host == host,
                  orElse: () {
                    return VersionHistoryBean();
                  },
                )
                .version;
        return version;
      }
    }
    return null;
  }

  bool getSystemBeanSuccess = false;

  void updateSystemBean() {
    setState(() {
      getSystemBeanSuccess = true;
    });
  }

  void getSystemBean(BuildContext context) async {
    var bean = await SingleAccountPageState.ofApi(context).system();

    if (!bean.success) {
      String? host = SingleAccountPageState.ofUserInfo(context).host;

      String? version = getCurrentVersion(host);

      if (version == null || version.isEmpty) {
        "获取版本号失败，请前往应用设置中添加".toast();
        updateVersionHistory(
          VersionHistoryBean(
            host: SingleAccountPageState.ofUserInfo(context).host,
            version: "2.10.13",
          ),
        );
        SingleAccountPageState.of(
          context,
        )?.registerSystemBean(bean.bean?.version ?? "2.10.13", false);
        updateSystemBean();
        return;
      }
    }

    if (bean.bean == null || bean.bean?.version == null) {
      //从历史记录里找版本号
      String? host = SingleAccountPageState.ofUserInfo(context).host;

      String? version = getCurrentVersion(host);

      if (version != null && version.isNotEmpty) {
        SingleAccountPageState.of(context)?.registerSystemBean(version, false);
        updateSystemBean();
        return;
      }

      "获取版本号失败，请手动配置".toast();
      TextEditingController controller = TextEditingController(text: "");
      showCupertinoDialog(
        useRootNavigator: false,
        context: context,
        builder:
            (context1) => CupertinoAlertDialog(
              title: const Text("请输入版本号:"),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: TextField(
                      textAlign: TextAlign.center,
                      controller: controller,
                      autofocus: false,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .title2Color(),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                ref
                                    .watch(themeProvider)
                                    .themeColor
                                    .title2Color(),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text(
                    "取消",
                    style: TextStyle(color: Color(0xff999999)),
                  ),
                  onPressed: () {
                    Navigator.of(context1).pop();
                    "已默认为2.10.13版本".toast();
                    updateVersionHistory(
                      VersionHistoryBean(host: host, version: "2.10.13"),
                    );
                    SingleAccountPageState.of(context)?.registerSystemBean(
                      bean.bean?.version ?? "2.10.13",
                      false,
                    );
                    updateSystemBean();
                  },
                ),
                CupertinoDialogAction(
                  child: Text(
                    "确定",
                    style: TextStyle(
                      color: ref.watch(themeProvider).primaryColor,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(context1).pop();
                    updateVersionHistory(
                      VersionHistoryBean(
                        host: host,
                        version: controller.text.trim(),
                      ),
                    );
                    SingleAccountPageState.of(
                      context,
                    )?.registerSystemBean(controller.text.trim(), false);
                    updateSystemBean();
                  },
                ),
              ],
            ),
      ).whenComplete(() {
        controller.dispose();
      });
    } else {
      SingleAccountPageState.of(
        context,
      )?.registerSystemBean(bean.bean?.version ?? "2.10.13", true);
      updateSystemBean();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    MultiAccountPageState.clearAction();
    super.dispose();
  }

  bool showMask = false;

  GlobalKey<TaskPageState> taskKey = GlobalKey();
  GlobalKey<EnvPageState> envKey = GlobalKey();
  GlobalKey<OtherPageState> meKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final int homeIndex = ref.watch<int>(
      SingleAccountPageState.ofHomeIndexProvider(context)(getProviderName(context)),
    );
    // 惰性创建 PageController（首次 build 时 provider 才可读）
    final PageController pageController =
        _pageController ??= PageController(initialPage: homeIndex);
    // provider 为唯一数据源：底部 tab 点击/外部跳转改 index，统一驱动平滑滑动
    ref.listen<int>(
      SingleAccountPageState.ofHomeIndexProvider(context)(getProviderName(context)),
      (previous, next) {
        if (!pageController.hasClients) return;
        if (pageController.page?.round() != next) {
          // 与顶部 tab（GlassSegmentedTab）一致：300ms + easeOutCubic
          // easeOutCubic 起步快、收尾缓，切换更跟手
          pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      },
    );
    // 底部导航"我的"按钮几何（与 _buildBottomNav 的胶囊侧边距 16 +
    // LiquidGlassNavBar.padding=4 保持一致），用于长按"我的"弹窗对齐悬浮"我的"位置
    final double screenW = MediaQuery.of(context).size.width;
    const double navSide = 16.0;
    const double navInnerPad = 4.0;
    final double navItemW = (screenW - navSide * 2 - navInnerPad * 2) / 4;
    final double meCenter = navSide + navInnerPad + 3.5 * navItemW;
    return PopScope(
      canPop: true,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            RepaintBoundary(
              child: Scaffold(
                extendBody: true,
                // 与顶部 TabBar 同机制：PageView 轨道式整页滑动切换
                // 页面保活见各页面 AutomaticKeepAliveClientMixin（滚动位置不丢）
                //
                // 功耗优化：TickerMode 包裹非当前 tab，切走后自动暂停该页
                // 全部动画 ticker（AnimationController/Slidable 弹簧等），
                // 静止时零动画重绘；TickerMode 不影响 paint，滑动切入时正常显示
                body: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    TickerMode(
                      enabled: homeIndex == 0,
                      child: TaskPage(
                        key: taskKey,
                        loading: !getSystemBeanSuccess,
                      ),
                    ),
                    TickerMode(
                      enabled: homeIndex == 1,
                      child: EnvPage(key: envKey),
                    ),
                    TickerMode(
                      enabled: homeIndex == 2,
                      child: const ConfigPage(),
                    ),
                    TickerMode(
                      enabled: homeIndex == 3,
                      child: OtherPage(key: meKey),
                    ),
                  ],
                ),
                bottomNavigationBar: _buildBottomNavigationBar(context),
              ),
            ),
            Visibility(
              visible: showMask,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  setState(() {
                    showMask = false;
                  });
                },
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).viewPadding.bottom,
              child: Visibility(
                visible: showMask,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      // 右缘对齐"我的"按钮右缘，弹窗锚定在悬浮"我的"上
                      margin: EdgeInsets.only(
                        right: screenW - meCenter - navItemW / 2,
                      ),
                      width: MediaQuery.of(context).size.width / 2,
                      child: _buildOtherAccounts(),
                    ),
                    _buildOtherWidget(meCenter: meCenter),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建底部导航栏容器（悬浮大胶囊，无整块背景色块）
  ///
  /// 悬浮胶囊直接浮在页面内容之上：去掉整块色块背景与毛玻璃结构，
  /// 大胶囊自带深色悬浮投影（由 LiquidGlassNavBar.barShadow 提供）。
  Widget _buildBottomNavigationBar(BuildContext context) {
    // 高度 = 悬浮胶囊(75) + 上边距(14) + 下边距(2) + 底部安全区
    return Container(
      height: 91.0 + MediaQuery.of(context).padding.bottom,
      width: MediaQuery.of(context).size.width,
      color: Colors.transparent,
      child: _buildBottomNav(context),
    );
  }

  /// 构建底部导航栏内容
  Widget _buildBottomNav(BuildContext context) {
    final isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final theme = ref.watch(themeProvider);
    final bool blurEnabled = ref.watch(blurEffectProvider);
    final homeIndex = ref.watch<int>(
      SingleAccountPageState.ofHomeIndexProvider(context)(
        getProviderName(context),
      ),
    );

    // 液态玻璃导航条：赛博/苹果 两套视觉参数（与 demo 确认效果一致）
    final activeColor = isCyber ? CyberColors.cyan : theme.primaryColor;
    final inactiveColor = isCyber
        ? CyberColors.hintGray
        : AppleColors.textSecondary;

    // 大胶囊：毛玻璃开启 = 半透明玻璃色 + BackdropFilter；关闭 = 纯色
    // 悬浮投影：胶囊自带深色投影（无需外层色块）
    final Color barColor = isCyber
        ? CyberColors.cardBg
        : AppleColors.bgSecondary;
    final List<BoxShadow> barShadow =
        isCyber
            ? const [
              BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 10)),
              BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 4)),
            ]
            : const [
              BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10)),
              BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
            ];

    // 悬浮布局：胶囊水平左右留 16，上 14 下 2（较之前整体下移 10px，降低悬浮高度）
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        2 + MediaQuery.of(context).padding.bottom,
      ),
      child: LiquidGlassNavBar(
      items:
          titles
              .asMap()
              .entries
              .map((entry) {
                // 底部导航图标与 demo 一致（Material Icons，随 active 着色）
                const icons = [
                  (Icons.schedule_outlined, Icons.schedule),
                  (Icons.settings_ethernet_outlined, Icons.settings_ethernet),
                  (Icons.description_outlined, Icons.description),
                  (Icons.person_outline, Icons.person),
                ];
                final e = entry.value;
                return LiquidNavItem(
                  label: e.title,
                  icon: icons[entry.key].$1,
                  activeIcon: icons[entry.key].$2,
                );
              })
              .toList(),
      initialIndex: homeIndex,
      onSelected: (index) async {
        final currentIdx = ref.read<int>(
          SingleAccountPageState.ofHomeIndexProvider(context)(
            getProviderName(context),
          ),
        );
        if (currentIdx == index) {
          if (index == 0) {
            await taskKey.currentState?.move2Top();
          } else if (index == 1) {
            await envKey.currentState?.move2Top();
          } else if (index == 3) {
            await meKey.currentState?.move2Top();
          }
          return;
        } else {
          // 切换 tab 时关闭所有打开的 Slidable 卡片
          SlidableCloseNotifier.notify();
          ref
              .read(
                SingleAccountPageState.ofHomeIndexProvider(context)(
                  getProviderName(context),
                ).notifier,
              )
              .state = index;
        }
      },
      onLongTap: (index) async {
        if (index == 3) {
          HapticFeedback.mediumImpact();
          setState(() {
            showMask = true;
          });
        }
      },
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      padding: 4,
      labelSize: 11,
      // 大胶囊：毛玻璃（跟随开关）+ 深色悬浮投影
      barColor: barColor,
      barGlass: blurEnabled,
      barGlassColor: isCyber
          ? CyberColors.cardBg.withValues(alpha: 0.7)
          : AppleColors.bgSecondary.withValues(alpha: 0.75),
      barShadow: barShadow,
      barBorder: isCyber
          ? Border.all(
              color: CyberColors.cyan.withValues(alpha: 0.2),
              width: 1.5,
            )
          : null,
      // 小胶囊：赛博全透明滑块（保留内发光）；苹果风格保持原样（渐变+顶部高光）
      sliderColor: isCyber
          ? Colors.transparent
          : const Color(0xFFE5E5E5),
      sliderBorder: isCyber
          ? Border.all(color: const Color(0xFF404040), width: 1)
          : Border.all(color: Colors.white70, width: 1),
      sliderTopGlow: isCyber ? null : Colors.white.withValues(alpha: 0.9),
      sliderBottomGlow: isCyber ? const Color(0x22CCCCCC) : null,
      ),
    );
  }

  void initTitles() {
    titles.clear();
    titles.add(
      IndexBean(
        "assets/images/icon_cron.png",
        "assets/images/icon_cron_checked.png",
        "定时任务",
      ),
    );
    titles.add(
      IndexBean(
        "assets/images/icon_env.png",
        "assets/images/icon_env_checked.png",
        "环境变量",
      ),
    );
    titles.add(
      IndexBean(
        "assets/images/icon_file.png",
        "assets/images/icon_file_checked.png",
        "配置文件",
      ),
    );
    titles.add(
      IndexBean(
        "assets/images/icon_other.png",
        "assets/images/icon_other_checked.png",
        "我的",
      ),
    );
  }

  Widget _buildOtherWidget({double? meCenter}) {
    if (!showMask) return const SizedBox.shrink();
    final double w = MediaQuery.of(context).size.width;
    final double cx = meCenter ?? w / 2;
    return SizedBox(
      width: w,
      height: kBottomNavigationBarHeight,
      child: Stack(
        children: [
          // "我的"指针：改用与底部导航一致的新图标，水平居中于悬浮"我的"按钮
          Positioned(
            left: cx - 20,
            width: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Icon(Icons.person, size: 20, color: Colors.white),
                SizedBox(height: 2),
                Text(
                  "我的",
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherAccounts() {
    if (!showMask) return const SizedBox.shrink();
    final isCyber = ref.watch(themeProvider).themeMode == modeCyber;
    final cardRadius = isCyber ? 10.0 : AppleColors.radiusCard;
    int count = getIt<MultiAccountUserInfoViewModel>().tokenBeans.length + 1;
    if (count > MultiAccountUserInfoViewModel.maxAccount) {
      count = MultiAccountUserInfoViewModel.maxAccount;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height - kToolbarHeight * 2,
        ),
        decoration: BoxDecoration(
          color: ref.watch(themeProvider).themeColor.settingBgColor(),
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        child: SingleChildScrollView(
          child: Column(
            children:
                SpUtil.getBool(spSingleInstance, defValue: false) == true
                    ? _buildSingleInstance()
                    : List.generate(count, (index) {
                      if (index >=
                              getIt<MultiAccountUserInfoViewModel>()
                                  .tokenBeans
                                  .length ||
                          (getIt<MultiAccountUserInfoViewModel>()
                                      .tokenBeans
                                      .length <
                                  count &&
                              index == count - 1)) {
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              dismissMask();
                              WidgetsBinding.instance.addPostFrameCallback((
                                timeStamp,
                              ) {
                                context
                                    .findAncestorStateOfType<
                                      MultiAccountPageState
                                    >()
                                    ?.updateIndex(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.add,
                                    size: 15,
                                    color:
                                        ref
                                            .watch(themeProvider)
                                            .themeColor
                                            .titleColor(),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "添加账户",
                                    style: TextStyle(
                                      color:
                                          ref
                                              .watch(themeProvider)
                                              .themeColor
                                              .titleColor(),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      var userInfo = getIt<UserInfoViewModel>(
                        instanceName: index.toString(),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                dismissMask();
                                WidgetsBinding.instance.addPostFrameCallback((
                                  timeStamp,
                                ) {
                                  context
                                      .findAncestorStateOfType<
                                        MultiAccountPageState
                                      >()
                                      ?.updateIndex(index);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 12,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  userInfo.host
                                          ?.replaceAll("http://", "")
                                          .replaceAll("https://", "") ??
                                      "",
                                  maxLines: 1,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        ref
                                            .watch(themeProvider)
                                            .themeColor
                                            .titleColor(),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Divider(indent: 15, height: 1),
                        ],
                      );
                    }),
          ),
        ),
      ),
    );
  }

  void dismissMask() {
    setState(() {
      showMask = false;
    });
  }

  List<Widget> _buildSingleInstance() {
    int count = getIt<MultiAccountUserInfoViewModel>().historyAccounts.length;

    if (SpUtil.getInt(spVIP, defValue: typeNormal) == typeVIP) {
      if (count > 3) {
        count = 3;
      }
    }

    return List.generate(count + 1, (index) {
      if (index >= count) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              dismissMask();
              WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                Navigator.of(
                  context,
                ).pushNamed(Routes.routeLogin, arguments: true);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.add,
                    size: 15,
                    color: ref.watch(themeProvider).themeColor.titleColor(),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "添加账户",
                    style: TextStyle(
                      color: ref.watch(themeProvider).themeColor.titleColor(),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      var userInfo =
          getIt<MultiAccountUserInfoViewModel>().historyAccounts[index];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                dismissMask();

                if (SingleAccountPageState.ofHttp(context)?.host ==
                    userInfo.host)
                  return;

                WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
                  await EasyLoading.show(status: " 登录中");

                  LoginHelper loginHelper = LoginHelper(
                    userInfo.host!,
                    userInfo.userName!,
                    userInfo.password!,
                    true,
                    userInfo.alias,
                  );
                  var response = await loginHelper.login(context);

                  EasyLoading.dismiss();

                  dealLoginResponse(loginHelper, response);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  userInfo.host
                          ?.replaceAll("http://", "")
                          .replaceAll("https://", "") ??
                      "",
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        SingleAccountPageState.ofHttp(context)?.host ==
                                userInfo.host
                            ? ref.watch(themeProvider).primaryColor
                            : ref.watch(themeProvider).themeColor.titleColor(),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const Divider(indent: 15, height: 1),
        ],
      );
    });
  }

  void twoFact(LoginHelper helper) {
    String twoFact = "";
    showCupertinoDialog(
      useRootNavigator: false,
      context: context,
      builder:
          (_) => CupertinoAlertDialog(
            title: const Text("两步验证"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: TextField(
                    onChanged: (value) {
                      twoFact = value;
                    },
                    maxLines: 1,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                      hintText: "请输入code",
                    ),
                    autofocus: true,
                  ),
                ),
              ],
            ),
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
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  var response = await helper.loginTwice(context, twoFact);
                  dealLoginResponse(helper, response);
                },
              ),
            ],
          ),
    ).then((value) {});
  }

  void dealLoginResponse(LoginHelper hepler, int response) {
    if (response == LoginHelper.success) {
      Navigator.of(context).pushReplacementNamed(Routes.routeHomePage);
    } else if (response == LoginHelper.failed) {
      EasyLoading.showError("登录失败，请检查账号");
    } else {
      twoFact(hepler);
    }
  }
}

class IndexBean {
  String icon;
  String checkedIcon;
  String title;
  String celebrate;

  IndexBean(this.icon, this.checkedIcon, this.title, {this.celebrate = ""});
}

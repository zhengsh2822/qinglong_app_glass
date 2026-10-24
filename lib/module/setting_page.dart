import 'dart:io';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/blur_effect.dart';
import 'package:qinglong_app/base/ui/button.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/settings_widgets.dart';
import 'package:qinglong_app/base/ui/other_page_card.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/home/home_page.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/home/version_history_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import '../base/ql_app_bar.dart';

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  ConsumerState createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage>
    with TickerProviderStateMixin {
  // ===== 主题切换羽化圆形扩散（demos/theme_circular_reveal_demo 验收参数）=====
  static const double _revealFeather = 100;
  static const Duration _revealDuration = Duration(milliseconds: 1000);

  final GlobalKey _captureKey = GlobalKey();
  ui.Image? _revealImage;
  AnimationController? _revealController;
  Offset _revealOrigin = Offset.zero;
  double _revealMaxR = 0;
  int _revealFromMode = modeLight;
  int _revealTargetMode = modeCyber;
  double _revealSegmentTarget = 1;
  Offset? _lastPressPosition;
  bool _revealPreparing = false;
  bool _revealCompleting = false;
  /// 本次扩散开始前的「跟随系统」开关值（取消时回滚）
  bool _revealFollowSystemBefore = false;
  /// 快照捕获期间收到的第二次点击（快速双点打断）
  bool _pendingInterrupt = false;
  /// 遮罩收尾帧期间收到的切换目标（避免快速点击丢动画）
  int? _pendingTarget;
  bool _pendingDisableFollowSystem = true;

  void _onThemePointerDown(PointerDownEvent event) {
    _lastPressPosition = event.position;
    debugPrint(
      '[REVEAL] pointerDown global=${event.position} '
      'active=${_revealController != null} '
      'preparing=$_revealPreparing completing=$_revealCompleting',
    );
  }

  /// 主题开关的显示值（用于 value）
  ///
  /// 扩散期间跟随当前分段目标：正向=目标主题，反向立即回到原主题。
  /// 这样开关本身也能被打断——双击后开关立刻回位，而不是等动画结束才回位。
  int get _displayThemeMode {
    if (_revealController != null) {
      return _revealSegmentTarget >= 1 ? _revealTargetMode : _revealFromMode;
    }
    return ref.read(themeProvider).themeMode;
  }

  /// 切换主题并播放羽化圆形扩散
  ///
  /// 实现：旧主题整页快照置于上层（IgnorePointer），用 radial 遮罩打洞，
  /// 下层是已即时切换的新主题实时页；半径 = （触点到最远角落 + 羽化宽度）* easeInOutCubic。
  /// 动画中再次点击开关：不换圆心、不跳变，从当前进度反向/继续。
  Future<void> _switchThemeWithReveal(
    int target, {
    bool disableFollowSystem = true,
    bool? followSystemBefore,
  }) async {
    debugPrint(
      '[REVEAL] switchTheme target=$target '
      'active=${_revealController != null} '
      'preparing=$_revealPreparing completing=$_revealCompleting '
      'seg=$_revealSegmentTarget from=$_revealFromMode',
    );
    // 扩散进行中 → 翻转分段目标（打断），不换圆心、不换快照
    if (_revealController != null) {
      debugPrint('[REVEAL] branch=interrupt -> segment ${_revealSegmentTarget >= 1 ? 0 : 1}');
      if (disableFollowSystem) SpUtil.putBool(spThemeFollowSystem, false);
      _runRevealSegment(_revealSegmentTarget >= 1 ? 0 : 1);
      return;
    }
    // 遮罩收尾帧（约 2 帧）：记下目标，收尾后再起一段，避免快速点击丢动画
    if (_revealCompleting) {
      debugPrint('[REVEAL] branch=pending(completing) target=$target');
      _pendingTarget = target;
      _pendingDisableFollowSystem = disableFollowSystem;
      return;
    }
    // 快照捕获中：记下反向意图，扩散启动后立即反向（保证快速双点一定可打断）
    if (_revealPreparing) {
      debugPrint('[REVEAL] branch=pendingInterrupt(preparing)');
      _pendingInterrupt = true;
      return;
    }

    // 先记录操作前的跟随系统状态（取消扩散时回滚），再按本次操作关闭
    final bool followBefore =
        followSystemBefore ??
        SpUtil.getBool(spThemeFollowSystem, defValue: false);
    if (disableFollowSystem) SpUtil.putBool(spThemeFollowSystem, false);

    final ThemeViewModel model = ref.read(themeProvider.notifier);
    final int from = ref.read(themeProvider).themeMode;
    debugPrint('[REVEAL] branch=fresh from=$from target=$target');
    if (from == target) {
      debugPrint('[REVEAL] skip: from == target');
      _revealFollowSystemBefore = followBefore;
      return;
    }
    _revealFollowSystemBefore = followBefore;

    _revealPreparing = true;
    ui.Image? image;
    Offset? origin;
    double maxR = 0;
    try {
      // 等上一帧绘制完成，保证 RepaintBoundary 可截图
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      final RenderRepaintBoundary? boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      final RenderBox? pageBox = context.findRenderObject() as RenderBox?;
      if (boundary == null || pageBox == null || !pageBox.hasSize) {
        throw StateError('页面未完成布局，无法捕获主题快照');
      }
      final Size pageSize = pageBox.size;
      final Offset global =
          _lastPressPosition ??
          pageBox.localToGlobal(pageSize.center(Offset.zero));
      Offset local = pageBox.globalToLocal(global);
      local = Offset(
        local.dx.clamp(0.0, pageSize.width),
        local.dy.clamp(0.0, pageSize.height),
      );
      origin = local;
      final double dx = math.max(local.dx, pageSize.width - local.dx);
      final double dy = math.max(local.dy, pageSize.height - local.dy);
      maxR = math.sqrt(dx * dx + dy * dy);
      final double dpr = MediaQuery.of(context).devicePixelRatio;
      final double pixelRatio = dpr.clamp(1.0, 2.0);
      // 快照最多重试 3 次：偶发 needs-paint 时下一帧即可成功，避免退化成硬切
      for (int attempt = 0; attempt < 3 && image == null; attempt++) {
        if (attempt > 0) await SchedulerBinding.instance.endOfFrame;
        if (!mounted) return;
        try {
          image = await boundary.toImage(pixelRatio: pixelRatio);
        } catch (e) {
          debugPrint('主题扩散快照第 ${attempt + 1} 次捕获失败: $e');
        }
      }
    } catch (e) {
      debugPrint('主题扩散快照失败，回退普通过渡: $e');
    } finally {
      _revealPreparing = false;
    }

    if (!mounted) {
      _pendingInterrupt = false;
      image?.dispose();
      return;
    }
    if (image == null || origin == null) {
      // 捕获期间用户又点了一次（快速双点）→ 视为取消，不做硬切
      if (_pendingInterrupt) {
        _pendingInterrupt = false;
        image?.dispose();
        return;
      }
      image?.dispose();
      model.changeTheme(target);
      return;
    }
    // 捕获期间收到第二次点击 → 取消本次切换（双点 = 取消，避免硬切）
    if (_pendingInterrupt) {
      _pendingInterrupt = false;
      image.dispose();
      return;
    }

    final AnimationController controller = AnimationController(vsync: this);
    setState(() {
      _revealImage = image;
      _revealController = controller;
      _revealOrigin = origin!;
      _revealMaxR = maxR;
      _revealFromMode = from;
      _revealTargetMode = target;
      _revealSegmentTarget = 1;
      _revealCompleting = false;
    });
    // 主框架立即应用新主题（duration=0），视觉过渡由遮罩完成
    ref.read(themeRevealActiveProvider.notifier).state = true;
    model.changeThemeInstant(target);
    debugPrint(
      '[REVEAL] started from=$from target=$target origin=$_revealOrigin maxR=$_revealMaxR',
    );
    _runRevealSegment(1);
  }

  void _runRevealSegment(double target) {
    final AnimationController? controller = _revealController;
    if (controller == null) return;
    _revealSegmentTarget = target;
    final double travel = (target - controller.value).abs();
    if (travel < 0.001) {
      _completeReveal(target);
      return;
    }
    // 恒定速度：按剩余行程比例缩短时长（与 demo 一致，下限 120ms）
    final int ms = (_revealDuration.inMilliseconds * travel)
        .round()
        .clamp(120, _revealDuration.inMilliseconds);
    debugPrint(
      '[REVEAL] segment target=$target value=${controller.value} travel=$travel ms=$ms',
    );
    // 用 TickerFuture 判定自然结束，不能用 AnimationStatus：
    // Flutter 的 animateTo 方向恒为 forward，反向走到 0 时状态仍是 completed，
    // 会被误判为「完成并保留新主题」，导致双击打断后硬切回目标主题。
    // 被打断的旧动画其 TickerFuture 永不完结，因此不会误触发。
    controller
        .animateTo(
          target,
          duration: Duration(milliseconds: ms),
          curve: Curves.linear,
        )
        .then((_) {
          if (!mounted || !identical(controller, _revealController)) return;
          _completeReveal(target);
        });
  }

  void _completeReveal(double at) {
    debugPrint(
      '[REVEAL] complete at=$at from=$_revealFromMode '
      'theme=${ref.read(themeProvider).themeMode} completing=$_revealCompleting',
    );
    if (_revealCompleting || _revealImage == null) return;
    _revealCompleting = true;
    final ui.Image? image = _revealImage;
    final AnimationController? controller = _revealController;
    if (at < 0.5) {
      // 反向完成：遮罩此刻仍全屏覆盖，先恢复原主题，下一帧再撤掉遮罩
      ref.read(themeProvider.notifier).changeThemeInstant(_revealFromMode);
      // 取消扩散 = 取消本次操作：跟随系统开关也回滚到操作前的值
      SpUtil.putBool(spThemeFollowSystem, _revealFollowSystemBefore);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 页面已销毁：dispose() 已释放快照/控制器，这里不能重复释放
      if (!mounted) return;
      setState(() {
        _revealImage = null;
        _revealController = null;
      });
      // 再等一帧：确保 AnimatedTheme（duration=0）已把最终色应用到实时页
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        image?.dispose();
        controller?.dispose();
        _revealCompleting = false;
        ref.read(themeRevealActiveProvider.notifier).state = false;
        // 收尾帧期间被点掉的切换目标：现在补一段完整扩散
        final int? pending = _pendingTarget;
        _pendingTarget = null;
        if (pending != null) {
          debugPrint(
            '[REVEAL] consume pending=$pending theme=${ref.read(themeProvider).themeMode}',
          );
        }
        if (pending != null && pending != ref.read(themeProvider).themeMode) {
          final bool disableFollowSystem = _pendingDisableFollowSystem;
          _pendingDisableFollowSystem = true;
          _switchThemeWithReveal(
            pending,
            disableFollowSystem: disableFollowSystem,
          );
        }
      });
    });
  }

  /// 羽化圆形遮罩：圆心透明（露出下层新主题）→ 向外渐层 → 完全不透明（旧主题快照）
  Widget _buildRevealMask() {
    final AnimationController? controller = _revealController;
    final ui.Image? image = _revealImage;
    if (controller == null || image == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final double p = controller.value.clamp(0.0, 1.0);
        final double radius =
            (_revealMaxR + _revealFeather) *
            Curves.easeInOutCubic.transform(p);
        // 半径 0：整页仍由旧主题快照覆盖
        if (radius <= 0.5) return child!;
        final double core = math.max(0.0, radius - _revealFeather);
        final List<Color> colors;
        final List<double> stops;
        if (core <= 0.5) {
          colors = const <Color>[
            Color(0x00000000),
            Color(0x47000000),
            Color(0x9E000000),
            Color(0xE0000000),
            Color(0xFF000000),
          ];
          stops = const <double>[0, 0.35, 0.65, 0.85, 1];
        } else {
          final double span = radius - core;
          colors = const <Color>[
            Color(0x00000000),
            Color(0x00000000),
            Color(0x47000000),
            Color(0x9E000000),
            Color(0xE0000000),
            Color(0xFF000000),
          ];
          stops = <double>[
            0,
            (core / radius).clamp(0.0, 1.0),
            ((core + span * 0.35) / radius).clamp(0.0, 1.0),
            ((core + span * 0.65) / radius).clamp(0.0, 1.0),
            ((core + span * 0.85) / radius).clamp(0.0, 1.0),
            1,
          ];
        }
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback:
              (Rect bounds) =>
                  ui.Gradient.radial(_revealOrigin, radius, colors, stops),
          child: child,
        );
      },
      child: RawImage(image: image, fit: BoxFit.fill),
    );
  }

  @override
  void dispose() {
    _revealController?.dispose();
    _revealController = null;
    _revealImage?.dispose();
    _revealImage = null;
    // 扩散中途页面被销毁：解除主框架的即时主题模式（微任务避免在销毁期触发重建）
    if (ref.read(themeRevealActiveProvider)) {
      final StateController<bool> flag = ref.read(
        themeRevealActiveProvider.notifier,
      );
      Future.microtask(() => flag.state = false);
    }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    SystemBean? systemBean;

    try {
      systemBean = getIt<SystemBean>(
        instanceName:
            (SingleAccountPageState.of(context)?.index ?? 0).toString(),
      );
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }

    // 赛博模式下背景设为透明，让 CyberBackground 的渐变透出
    final scaffold = Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          isCyber
              ? Colors.transparent
              : ref.watch(themeProvider).themeColor.bg2Color(),
      appBar: QlAppBar(title: "系统设置"),
      body: SingleChildScrollView(
        primary: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible:
                  Platform.isIOS ||
                  SpUtil.getInt(spVIP, defValue: typeNormal) != typeNormal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 15),
                  const SectionHeader(title: "VIP功能"),
                  const SizedBox(height: 10),
                  OtherPageCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingsSwitchRow(
                          icon: CupertinoIcons.smiley,
                          title: "使用Face ID解锁",
                          value: SpUtil.getBool(spOpenAuth, defValue: false),
                          onChanged: (open) async {
                            await SpUtil.putBool(spOpenAuth, open);
                            setState(() {});
                          },
                        ),
                        settingsDivider,
                        SettingsSwitchRow(
                          icon: CupertinoIcons.wand_stars_inverse,
                          title: "单实例模式",
                          value: SpUtil.getBool(
                            spSingleInstance,
                            defValue: false,
                          ),
                          onChanged: (open) async {
                            SpUtil.putBool(spSingleInstance, open);
                            setState(() {});
                          },
                          trailing: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              showConfirmDialog(
                                context,
                                title: '温馨提示',
                                content:
                                    '开启后可关闭多容器同时在线功能，减少APP对系统内存的消耗，通过长按首页 我的 切换账号',
                                cancelLabel: '知道了',
                                confirmLabel: '确定',
                                danger: false,
                              );
                            },
                            child: const Icon(
                              CupertinoIcons.question_circle,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        settingsDivider,
                        // 指针按下位置作为扩散圆心（行内任意位置按下均可记录）
                        Listener(
                          onPointerDown: _onThemePointerDown,
                          child: SettingsSwitchRow(
                            icon: CupertinoIcons.sun_max,
                            title: "白色主题",
                            // 显示值跟随扩散分段目标：反向时开关立刻回位（按钮本身也可打断）
                            value: _displayThemeMode == modeWhite,
                            onChanged: (_) {
                              final int current = _displayThemeMode;
                              debugPrint(
                                '[REVEAL] whiteRow tap display=$current '
                                'active=${_revealController != null} seg=$_revealSegmentTarget',
                              );
                              _switchThemeWithReveal(
                                current == modeWhite ? modeLight : modeWhite,
                              );
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const SectionHeader(title: "通用功能"),
            const SizedBox(height: 10),
            OtherPageCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsSwitchRow(
                    icon: CupertinoIcons.doc_text,
                    title: "任务自动弹出日志",
                    value: SpUtil.getBool(spAutoShowLog, defValue: true),
                    onChanged: (open) async {
                      await SpUtil.putBool(spAutoShowLog, open);
                      setState(() {});
                    },
                  ),
                  settingsDivider,
                  SettingsSwitchRow(
                    icon: Icons.abc_sharp,
                    title: "代码显示行号",
                    value: SpUtil.getBool(spShowLine, defValue: false),
                    onChanged: (open) async {
                      await SpUtil.putBool(spShowLine, open);
                      setState(() {});
                    },
                  ),
                  settingsDivider,
                  SettingsSwitchRow(
                    icon: CupertinoIcons.arrow_down_doc,
                    title: "日志内容自动滚动",
                    value: SpUtil.getBool(
                      spLogAutoJump2Bottom,
                      defValue: false,
                    ),
                    onChanged: (open) async {
                      await SpUtil.putBool(spLogAutoJump2Bottom, open);
                      setState(() {});
                    },
                  ),
                  settingsDivider,
                  // 指针按下位置作为扩散圆心；切换走羽化圆形扩散
                  Listener(
                    onPointerDown: _onThemePointerDown,
                    child: SettingsSwitchRow(
                      icon: CupertinoIcons.moon_circle,
                      title: "赛博模式",
                      // 显示值跟随扩散分段目标：反向时开关立刻回位（按钮本身也可打断）
                      value: _displayThemeMode == modeCyber,
                      onChanged: (_) {
                        final int current = _displayThemeMode;
                        debugPrint(
                          '[REVEAL] cyberRow tap display=$current '
                          'active=${_revealController != null} seg=$_revealSegmentTarget',
                        );
                        _switchThemeWithReveal(
                          current == modeCyber ? modeLight : modeCyber,
                        );
                        setState(() {});
                      },
                    ),
                  ),
                  settingsDivider,
                  // 毛玻璃效果开关
                  SettingsSwitchRow(
                    icon: CupertinoIcons.sparkles,
                    title: "毛玻璃效果",
                    value: SpUtil.getBool(spBlurEffect, defValue: true),
                    onChanged: (open) async {
                      await setBlurEffect(ref, open);
                      setState(() {});
                    },
                  ),
                  settingsDivider,
                  // 跟随系统也走同一套羽化圆形扩散（指针位置为圆心）
                  Listener(
                    onPointerDown: _onThemePointerDown,
                    child: SettingsSwitchRow(
                      icon:
                          SchedulerBinding.instance.window.platformBrightness ==
                                  Brightness.dark
                              ? CupertinoIcons.moon_circle
                              : CupertinoIcons.sun_max,
                      title: "跟随系统",
                      value: SpUtil.getBool(
                        spThemeFollowSystem,
                        defValue: false,
                      ),
                      onChanged: (_) async {
                        // 以真实开关状态取反，避免依赖可能滞后的回调值
                        final bool enable = !SpUtil.getBool(
                          spThemeFollowSystem,
                          defValue: false,
                        );
                        SpUtil.putBool(spThemeFollowSystem, enable);
                        if (enable) {
                          // 开启跟随系统：按系统亮度切主题，复用同一套扩散动画
                          final ThemeViewModel model = ref.read(
                            themeProvider.notifier,
                          );
                          final int target = model.systemThemeMode;
                          if (target != model.themeMode) {
                            _switchThemeWithReveal(
                              target,
                              disableFollowSystem: false,
                              followSystemBefore: false,
                            );
                          }
                        } else if (_revealController != null) {
                          // 关闭跟随系统时正在扩散 → 反向取消
                          _switchThemeWithReveal(
                            ref.read(themeProvider).themeMode,
                            disableFollowSystem: false,
                          );
                        }
                        setState(() {});
                      },
                    ),
                  ),
                  Visibility(
                    visible: !(systemBean.fromAutoGet ?? false),
                    child: settingsDivider,
                  ),
                  Visibility(
                    visible: !(systemBean.fromAutoGet ?? false),
                    child: SettingsTapRow(
                      icon: CupertinoIcons.paperplane,
                      title: "变更服务器版本号",
                      onTap: () => _updateVersion(context),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "(${systemBean.version})",
                            style: TextStyle(
                              color:
                                  ref
                                      .watch(themeProvider)
                                      .themeColor
                                      .descColor(),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 40,
                child: ButtonWidget(
                  title: "退出登录",
                  onTap: () {
                    showConfirmDialog(
                      context,
                      title: '确认退出登录吗?',
                      content: '',
                      danger: true,
                      confirmLabel: '退出',
                    ).then((confirmed) {
                      if (confirmed == true) {
                        SingleAccountPageState.ofUserInfo(context).updateToken(
                          SingleAccountPageState.of(context)?.index ?? 0,
                          SingleAccountPageState.ofUserInfo(context).host,
                          "",
                          false,
                          SingleAccountPageState.ofUserInfo(context).alias,
                        );
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.routeLogin,
                          (p) {
                            return false;
                          },
                        );
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 40,
                child: ButtonWidget(
                  title: "退出登录并清空本地数据",
                  onTap: () {
                    showConfirmDialog(
                      context,
                      title: '确认退出登录并清空账号本地数据吗?',
                      content: '',
                      danger: true,
                      confirmLabel: '清空并退出',
                    ).then((confirmed) {
                      if (confirmed == true) {
                        clearData(context);
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.routeLogin,
                          (p) {
                            return false;
                          },
                        );
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
    final Widget page = isCyber ? CyberBackground(child: scaffold) : scaffold;
    // 主题扩散：下层为实时新主题页，上层为旧主题整页快照（IgnorePointer 便于打断点击）
    return Stack(
      children: [
        RepaintBoundary(key: _captureKey, child: page),
        if (_revealImage != null && _revealController != null)
          Positioned.fill(
            child: IgnorePointer(child: _buildRevealMask()),
          ),
      ],
    );
  }

  void clearData(BuildContext context) {
    getIt<MultiAccountUserInfoViewModel>().removeHistoryAccount(
      SingleAccountPageState.ofUserInfo(context).host,
    );
    SingleAccountPageState.ofUserInfo(
      context,
    ).clearCurrentInfo(SingleAccountPageState.of(context)?.index ?? 0);
  }

  void _updateVersion(BuildContext context) async {
    String? host = SingleAccountPageState.ofUserInfo(context).host;

    String currentVersion =
        getIt<SystemBean>(
          instanceName:
              (SingleAccountPageState.of(context)?.index ?? 0).toString(),
        ).version ??
        '';

    final result = await showInputDialog(
      context,
      title: '请输入版本号',
      content: '当前版本: $currentVersion',
      hintText: '请输入版本号',
      initialValue: currentVersion,
    );

    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty) return;

    HomePageState.updateVersionHistory(
      VersionHistoryBean(host: host, version: trimmed),
    );
    SingleAccountPageState.of(context)?.registerSystemBean(trimmed, false);
    setState(() {});
  }

  void commitLogDel(int time) async {
    var response = await SingleAccountPageState.ofApi(context).logDelTime(time);
    if (response.success) {
      "修改成功".toast();
    } else {
      response.message?.toast();
    }
  }
}

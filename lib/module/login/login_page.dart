import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animator/flutter_animator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/confirm_dialog.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_glass_card.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/in_app_purchase_page.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/login_helper.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';
import 'package:flip_card/flip_card.dart';

import '../others/change_account_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  final bool fromAddNewAccount;

  const LoginPage({Key? key, this.fromAddNewAccount = false}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _cIdController = TextEditingController();
  final TextEditingController _cSecretController = TextEditingController();
  GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();

  bool rememberPassword = false;

  @override
  void initState() {
    super.initState();
    if (!widget.fromAddNewAccount) {
      _hostController.text =
          SingleAccountPageState.ofUserInfo(context).host ?? "";
      if (SingleAccountPageState.ofUserInfo(context).userName != null &&
          SingleAccountPageState.ofUserInfo(context).userName!.isNotEmpty) {
        if (SingleAccountPageState.ofUserInfo(context).useSecretLogined) {
          _cIdController.text =
              SingleAccountPageState.ofUserInfo(context).userName!;
        } else {
          _userNameController.text =
              SingleAccountPageState.ofUserInfo(context).userName!;
        }
        rememberPassword = true;
      } else {
        rememberPassword = false;
      }
      if (SingleAccountPageState.ofUserInfo(context).passWord != null &&
          SingleAccountPageState.ofUserInfo(context).passWord!.isNotEmpty) {
        if (SingleAccountPageState.ofUserInfo(context).useSecretLogined) {
          _cSecretController.text =
              SingleAccountPageState.ofUserInfo(context).passWord!;
        } else {
          _passwordController.text =
              SingleAccountPageState.ofUserInfo(context).passWord!;
        }
      }

      if (SingleAccountPageState.ofUserInfo(context).alias != null &&
          SingleAccountPageState.ofUserInfo(context).alias!.isNotEmpty) {
        _aliasController.text =
            SingleAccountPageState.ofUserInfo(context).alias!;
      }
    }
    // 监听输入变化以刷新登录按钮可用状态
    _hostController.addListener(_refresh);
    _userNameController.addListener(_refresh);
    _passwordController.addListener(_refresh);
    _cIdController.addListener(_refresh);
    _cSecretController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  GlobalKey<AnimatorWidgetState> loginKey = GlobalKey<AnimatorWidgetState>();

  bool _isCyber() {
    final mode = ref.read(themeProvider).themeMode;
    return mode == modeCyber || mode == modeDark;
  }

  @override
  Widget build(BuildContext context) {
    final bool isCyber = _isCyber();
    Widget scaffold = Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isCyber ? Colors.transparent : null,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            isCyber
                ? SystemUiOverlayStyle.light
                : (ref.watch(themeProvider).themeMode == modeDark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: SingleChildScrollView(
            primary: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height / 10),
                      // 标题
                      _buildHeader(isCyber),
                      SizedBox(height: MediaQuery.of(context).size.height / 18),
                      // 表单卡片
                      if (isCyber)
                        CyberGlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          child: _buildFormFields(isCyber),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: AppleColors.bgSecondary,
                            borderRadius: BorderRadius.circular(
                              AppleColors.radiusCard,
                            ),
                            border: Border.all(
                              color: AppleColors.cardBorder,
                              width: 0.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _buildFormFields(isCyber),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                // 记住密码
                _buildRememberPassword(isCyber),
                const SizedBox(height: 30),
                // 登录按钮
                _buildLoginButton(isCyber),
                const SizedBox(height: 30),
                // 历史账号
                _buildHistoryAccounts(),
              ],
            ),
          ),
        ),
      ),
    );
    final hasLoggedInAccount = getIt<MultiAccountUserInfoViewModel>().tokenBeans
        .any((bean) => bean.token != null && bean.token!.isNotEmpty);

    final Widget content =
        isCyber ? CyberBackground(child: scaffold) : scaffold;

    // 添加新账号 → 返回上一级；已有账号登录 → 返回首页；全新安装无账号 → 退出App
    if (widget.fromAddNewAccount || !hasLoggedInAccount) {
      return content;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.routeHomePage, (p) => false);
        }
      },
      child: content,
    );
  }

  /// 标题
  Widget _buildHeader(bool isCyber) {
    return GestureDetector(
      onTap: () {
        if (SpUtil.getInt(spVIP, defValue: typeNormal) == typeNormal) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => const InAppPurchasePage(fromDirectly: true),
            ),
          );
          return;
        } else {
          if (SpUtil.getBool(spSingleInstance, defValue: false)) {
            Navigator.pop(context);
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
        children: [
          Visibility(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: Icon(
                CupertinoIcons.chevron_back,
                color:
                    isCyber
                        ? CyberColors.cyan
                        : ref.watch(themeProvider).primaryColor,
                size: 26,
              ),
            ),
            visible: SpUtil.getBool(spSingleInstance, defValue: false),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "账号登录",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color:
                      isCyber
                          ? CyberColors.titleWhite
                          : ref.watch(themeProvider).themeColor.title2Color(),
                  fontFamily: isCyber ? CyberColors.monoFont : null,
                ),
              ),
            ),
          ),
          GestureDetector(
            onDoubleTap: () {},
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset("assets/images/ql.png", height: 45),
            ),
          ),
        ],
      ),
    );
  }

  /// 表单字段
  Widget _buildFormFields(bool isCyber) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          isCyber,
          label: '域名',
          controller: _hostController,
          hint: 'http://1.1.1.1:5700',
        ),
        const SizedBox(height: 16),
        _buildField(
          isCyber,
          label: '账户',
          controller: _userNameController,
          hint: '请输入账户',
        ),
        const SizedBox(height: 16),
        _buildField(
          isCyber,
          label: '密码',
          controller: _passwordController,
          hint: '请输入密码',
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _buildField(
          isCyber,
          label: '别名',
          controller: _aliasController,
          hint: '请输入别名(选填),仅用于展示',
          inputFormatters: [LengthLimitingTextInputFormatter(20)],
        ),
      ],
    );
  }

  /// 单个表单字段
  Widget _buildField(
    bool isCyber, {
    required String label,
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final labelStyle =
        isCyber
            ? const TextStyle(
              fontSize: 14,
              color: CyberColors.cyan,
              fontFamily: CyberColors.monoFont,
            )
            : TextStyle(
              fontSize: 14,
              color: ref.watch(themeProvider).themeColor.descColor(),
            );
    final field = TextField(
      onChanged: (_) => setState(() {}),
      controller: controller,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      style:
          isCyber
              ? const TextStyle(
                fontSize: 14,
                color: CyberColors.titleWhite,
                fontFamily: CyberColors.monoFont,
              )
              : TextStyle(
                fontSize: 16,
                color: ref.watch(themeProvider).themeColor.title2Color(),
              ),
      decoration:
          isCyber
              ? CyberInputDecoration.standard.copyWith(hintText: hint)
              : InputDecoration(
                filled: true,
                fillColor:
                    ref.watch(themeProvider).themeMode == modeWhite
                        ? Colors.black.withValues(alpha: 0.03)
                        : Colors.white.withValues(alpha: 0.05),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: ref
                        .watch(themeProvider)
                        .themeColor
                        .title2Color()
                        .withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: ref.watch(themeProvider).primaryColor,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: ref.watch(themeProvider).themeColor.hintColor(),
                ),
              ),
      autofocus: false,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  /// 记住密码
  Widget _buildRememberPassword(bool isCyber) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          Checkbox(
            value: rememberPassword,
            onChanged: (checked) {
              rememberPassword = checked ?? false;
              setState(() {});
            },
            checkColor: isCyber ? CyberColors.bg : Colors.white,
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return isCyber
                    ? CyberColors.cyan
                    : ref.watch(themeProvider).primaryColor;
              }
              return null;
            }),
          ),
          Text(
            "记住密码",
            style: TextStyle(
              color: isCyber ? CyberColors.descColor : const Color(0xff555555),
              fontSize: 14,
              fontFamily: isCyber ? CyberColors.monoFont : null,
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  /// 登录按钮
  Widget _buildLoginButton(bool isCyber) {
    final canClick = canClickLoginBtn();
    return Shake(
      preferences: const AnimationPreferences(
        autoPlay: AnimationPlayStates.None,
      ),
      key: loginKey,
      child: Center(
        child: Container(
          alignment: Alignment.center,
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  canClick
                      ? (isCyber
                          ? [
                            CyberColors.cyan,
                            CyberColors.cyan.withValues(alpha: 0.85),
                          ]
                          : [
                            AppleColors.accent,
                            AppleColors.accent.withOpacity(0.85),
                          ])
                      : (isCyber
                          ? [
                            CyberColors.cyan.withValues(alpha: 0.3),
                            CyberColors.cyan.withValues(alpha: 0.2),
                          ]
                          : [
                            AppleColors.accent.withOpacity(0.6),
                            AppleColors.accent.withOpacity(0.6),
                          ]),
            ),
            borderRadius: BorderRadius.all(
              Radius.circular(AppleColors.radiusButton),
            ),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 80,
            child: IgnorePointer(
              ignoring: !canClick,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child:
                    isLoading
                        ? const LoadingWidget(color: Colors.white)
                        : Text(
                          "登录",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight:
                                isCyber ? FontWeight.bold : FontWeight.normal,
                            fontFamily: isCyber ? CyberColors.monoFont : null,
                          ),
                        ),
                onPressed: () async {
                  // 自动补全 http:// 前缀
                  // 用户输入 192.168.31.109:5700 时自动补成 http://192.168.31.109:5700
                  final host = _hostController.text.trim();
                  if (host.isNotEmpty &&
                      !host.startsWith("http://") &&
                      !host.startsWith("https://")) {
                    _hostController.text = "http://$host";
                    _hostController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _hostController.text.length),
                    );
                  }
                  SingleAccountPageState.of(
                    context,
                  )?.registerHttp(_hostController.text);
                  SingleAccountPageState.ofHttp(context)?.pushedLoginPage =
                      false;
                  Utils.hideKeyBoard(context);
                  if (loginByUserName()) {
                    login(_userNameController.text, _passwordController.text);
                  } else {
                    login(_cIdController.text, _cSecretController.text);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 历史账号入口
  Widget _buildHistoryAccounts() {
    if (getIt<MultiAccountUserInfoViewModel>().historyAccounts.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool isCyber = _isCyber();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showHistoryAccountsSheet(isCyber),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  "assets/images/icon_history.png",
                  fit: BoxFit.cover,
                  width: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  "历史账号",
                  style: TextStyle(
                    color:
                        isCyber
                            ? CyberColors.descColor
                            : const Color(0xff555555),
                    fontSize: 14,
                    fontFamily: isCyber ? CyberColors.monoFont : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 历史账号底部弹窗（卡片圆角统一 18px）
  void _showHistoryAccountsSheet(bool isCyber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final accounts = getIt<MultiAccountUserInfoViewModel>().historyAccounts;
        final sheetBg =
            isCyber
                ? CyberColors.bg
                : (ref.read(themeProvider).themeMode == modeDark
                    ? const Color(0xFF1C1C1E)
                    : AppleColors.bgPrimary);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽条
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        isCyber
                            ? CyberColors.cyan.withValues(alpha: 0.3)
                            : Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "历史账号",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color:
                            isCyber
                                ? CyberColors.cyan
                                : ref
                                    .read(themeProvider)
                                    .themeColor
                                    .titleColor(),
                        fontFamily: isCyber ? CyberColors.monoFont : null,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: accounts.length,
                    itemBuilder:
                        (context, index) =>
                            _buildHistoryAccountCard(accounts[index], isCyber),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 历史账号卡片（圆角 18 + 统一卡片设计）
  Widget _buildHistoryAccountCard(UserInfoBean bean, bool isCyber) {
    final isDark = ref.read(themeProvider).themeMode == modeDark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color:
            isCyber
                ? const Color(0x20FFFFFF)
                : ref.read(themeProvider).themeColor.settingBordorColor(),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCyber ? CyberColors.borderGlow : AppleColors.cardBorder,
          width: isCyber ? 1 : 0.5,
        ),
        boxShadow:
            isCyber
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
              selected(bean);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 服务器名（长按修改名称）
                        GestureDetector(
                          onLongPress: () => _editAlias(bean),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  bean.host ?? "",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily:
                                        isCyber ? CyberColors.monoFont : null,
                                    color:
                                        isCyber
                                            ? CyberColors.titleWhite
                                            : ref
                                                .read(themeProvider)
                                                .themeColor
                                                .titleColor(),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                CupertinoIcons.pencil,
                                size: 12,
                                color:
                                    isCyber
                                        ? CyberColors.descColor
                                        : (isDark
                                            ? Colors.white54
                                            : Colors.black45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (bean.alias == null || bean.alias!.isEmpty)
                              ? (bean.userName ?? "")
                              : bean.alias!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                isCyber
                                    ? CyberColors.descColor
                                    : ref
                                        .read(themeProvider)
                                        .themeColor
                                        .descColor(),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      getIt<MultiAccountUserInfoViewModel>()
                          .removeHistoryAccount(bean.host);
                      Navigator.of(context).pop();
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        CupertinoIcons.clear_thick,
                        size: 18,
                        color:
                            isCyber
                                ? CyberColors.descColor
                                : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 长按修改名称（别名）
  void _editAlias(UserInfoBean bean) {
    showInputDialog(
      context,
      title: '修改名称',
      hintText: '请输入名称',
      initialValue: bean.alias ?? '',
      inputFormatters: [LengthLimitingTextInputFormatter(20)],
    ).then((newAlias) {
      if (newAlias == null) return;
      final trimmed = newAlias.trim();
      if (trimmed == (bean.alias ?? '')) return;
      final alias = trimmed.isEmpty ? null : trimmed;
      // 更新内存中的 bean 并持久化到 historyAccounts（保持最近使用顺序）
      bean.alias = alias;
      getIt<MultiAccountUserInfoViewModel>().save2HistoryAccount(bean);
      // 同步持久化到 tokenBeans，确保重启后不丢失
      getIt<MultiAccountUserInfoViewModel>().updateAliasForHost(
        bean.host,
        alias,
      );
      "名称已更新".toast();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _hostController.removeListener(_refresh);
    _userNameController.removeListener(_refresh);
    _passwordController.removeListener(_refresh);
    _cIdController.removeListener(_refresh);
    _cSecretController.removeListener(_refresh);
    _hostController.dispose();
    _aliasController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    _cIdController.dispose();
    _cSecretController.dispose();
    super.dispose();
  }

  bool isLoading = false;

  bool loginByUserName() {
    return true;
  }

  LoginHelper? helper;

  Future<void> login(String userName, String password) async {
    isLoading = true;
    setState(() {});

    helper = LoginHelper(
      _hostController.text,
      userName,
      password,
      rememberPassword,
      _aliasController.text,
    );
    var response = await helper!.login(context);
    dealLoginResponse(response);
  }

  void dealLoginResponse(int response) {
    if (response == LoginHelper.success) {
      Navigator.of(context).pushReplacementNamed(Routes.routeHomePage);
    } else if (response == LoginHelper.failed) {
      loginFailed();
    } else {
      twoFact();
    }
  }

  void loginFailed() {
    isLoading = false;
    loginKey.currentState?.forward();
    setState(() {});
  }

  bool canClickLoginBtn() {
    if (isLoading) return false;
    if (_hostController.text.isEmpty) return false;
    if (!loginByUserName()) {
      return _cIdController.text.isNotEmpty &&
          _cSecretController.text.isNotEmpty;
    } else {
      return _userNameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;
    }
  }

  void twoFact() {
    showInputDialog(
      context,
      title: '两步验证',
      hintText: '请输入code',
      keyboardType: TextInputType.number,
    ).then((value) async {
      if (value == null || value.isEmpty) {
        isLoading = false;
        setState(() {});
        return;
      }
      if (helper != null) {
        var response = await helper!.loginTwice(context, value);
        dealLoginResponse(response);
      } else {
        "状态异常，请重新点登录按钮".toast();
      }
    });
  }

  void selected(UserInfoBean result) {
    _hostController.text = result.host ?? "";
    if (result.useSecretLogined) {
      _cIdController.text = result.userName ?? "";
      _cSecretController.text = result.password ?? "";
      if (cardKey.currentState?.isFront ?? false) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          cardKey.currentState?.toggleCard();
        });
      }
    } else {
      _userNameController.text = result.userName ?? "";
      _passwordController.text = result.password ?? "";
      if (!(cardKey.currentState?.isFront ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          cardKey.currentState?.toggleCard();
        });
      }
    }
    _aliasController.text = result.alias ?? "";
    rememberPassword = true;
    setState(() {});
  }
}

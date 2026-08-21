import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/utils/codeeditor_theme.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

var themeProvider = ChangeNotifierProvider((ref) => ThemeViewModel());

Color whiteColor = const Color(0xfff1f1f1);

int modeLight = 0;
int modeWhite = 1;
int modeDark = 2;
int modeCyber = 3;

// 主色 - 青色 (#00cccc) - Apple UI Design SKILL 配色
Color _primaryColor = const Color(0xFF00CCCC);

/// 非赛博（主题版）主字体默认色
const Color kThemePrimaryTextDefault = Color(0xFF1F1F1F);
/// 非赛博（主题版）次字体默认色
const Color kThemeSecondaryTextDefault = Color(0xFFA2A2A2);
/// 赛博主字体默认色
const Color kCyberPrimaryTextDefault = Color(0xFFF0F0F0);
/// 赛博次字体默认色
const Color kCyberSecondaryTextDefault = Color(0xFF8D8D8D);

/// 自定义主字体颜色（赛博模式），未设置（-1）时回退到默认值
Color _customCyberPrimaryOf(Color fallback) {
  final custom = SpUtil.getInt(spCyberPrimaryTextColor, defValue: -1);
  return custom >= 0 ? Color(custom) : fallback;
}

/// 自定义次字体颜色（赛博模式），未设置（-1）时回退到默认值
Color _customCyberSecondaryOf(Color fallback) {
  final custom = SpUtil.getInt(spCyberSecondaryTextColor, defValue: -1);
  return custom >= 0 ? Color(custom) : fallback;
}

/// 自定义主字体颜色（非赛博/主题版），未设置（-1）时回退到默认值
Color _customThemePrimaryOf(Color fallback) {
  final custom = SpUtil.getInt(spThemePrimaryTextColor, defValue: -1);
  return custom >= 0 ? Color(custom) : fallback;
}

/// 自定义次字体颜色（非赛博/主题版），未设置（-1）时回退到默认值
Color _customThemeSecondaryOf(Color fallback) {
  final custom = SpUtil.getInt(spThemeSecondaryTextColor, defValue: -1);
  return custom >= 0 ? Color(custom) : fallback;
}

class ThemeViewModel extends ChangeNotifier {
  late ThemeData currentTheme;

  int _themeMode = modeLight;

  // ===== 主题切换颜色插值（平滑过渡，对齐 demos/theme_transition_demo）=====
  // 切换时 themeColor / primaryColor 从旧值 _from* 平滑过渡到新值 _to*
  // 用 SchedulerBinding.frame 自驱帧回调（无需 TickerProvider vsync）
  static const Duration _animDuration = Duration(milliseconds: 600);
  static const Curve _animCurve = Curves.easeInOutCubic;
  ThemeColors _fromColors = LightThemeColors();
  ThemeColors _toColors = LightThemeColors();
  Color _fromPrimary = _primaryColor;
  Color _toPrimary = _primaryColor;
  double _animValue = 1.0; // 0..1 动画进度；1 = 达到 _to*（静止态）
  bool _animating = false;
  DateTime? _animStart;

  /// 当前生效的 themeColor：动画期间返回 from→to 的插值色
  ThemeColors get themeColor {
    if (!_animating) return _toColors;
    final t = _animCurve.transform(_animValue);
    if (t >= 1.0) return _toColors;
    return _LerpThemeColors(_fromColors, _toColors, t);
  }

  /// 当前生效的主色：动画期间返回 from→to 的插值色
  Color get primaryColor =>
      !_animating
          ? _toPrimary
          : (Color.lerp(_fromPrimary, _toPrimary, _animCurve.transform(_animValue)))!;

  /// 每帧自驱动画（SchedulerBinding 帧回调，无需 vsync）
  void _scheduleFrame() {
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration _) {
    if (!_animating || _animStart == null) return;
    final elapsed = DateTime.now().difference(_animStart!);
    final p = (elapsed.inMicroseconds / _animDuration.inMicroseconds).clamp(0.0, 1.0);
    if (p >= 1.0) {
      _animating = false;
      _animValue = 1.0;
    } else {
      _animValue = p;
    }
    if (_animating) _scheduleFrame();
    notifyListeners();
  }

  /// 触发一次 0→1 的主题过渡动画（from=当前目标色，to=新目标色）
  void _startTransition(ThemeColors newColors, Color newPrimary) {
    _fromColors = _toColors;
    _fromPrimary = _toPrimary;
    _toColors = newColors;
    _toPrimary = newPrimary;
    _animValue = 0;
    _animating = true;
    _animStart = DateTime.now();
    _scheduleFrame();
  }

  void _setFinal(ThemeColors newColors, Color newPrimary) {
    _toColors = newColors;
    _toPrimary = newPrimary;
    _fromColors = newColors;
    _fromPrimary = newPrimary;
    _animValue = 1.0;
    _animating = false;
  }

  // 兼容旧引用：主文字色 / 次要文字色
  // 支持用户自定义颜色（字体设置页面设置），未设置（-1）时用默认主题色
  // 赛博/非赛博独立存储，按当前主题返回对应的自定义颜色
  bool get _isCyberNow => themeMode == modeCyber;

  Color get customPrimaryTextColor {
    final custom = SpUtil.getInt(
          _isCyberNow ? spCyberPrimaryTextColor : spThemePrimaryTextColor,
          defValue: -1,
        );
    return custom >= 0 ? Color(custom) : themeColor.titleColor();
  }
  Color get customSecondaryTextColor {
    final custom = SpUtil.getInt(
          _isCyberNow ? spCyberSecondaryTextColor : spThemeSecondaryTextColor,
          defValue: -1,
        );
    return custom >= 0 ? Color(custom) : themeColor.descColor();
  }

  /// 当前自定义主字体色（未设置为 null）
  Color? get primaryTextColor =>
      _readCustom(_isCyberNow ? spCyberPrimaryTextColor : spThemePrimaryTextColor);
  /// 当前自定义次字体色（未设置为 null）
  Color? get secondaryTextColor =>
      _readCustom(_isCyberNow ? spCyberSecondaryTextColor : spThemeSecondaryTextColor);

  // —— 赛博模式颜色（供字体设置页独立读写）——
  Color? get cyberPrimaryTextColor =>
      _readCustom(spCyberPrimaryTextColor);
  Color? get cyberSecondaryTextColor =>
      _readCustom(spCyberSecondaryTextColor);
  void setCyberPrimaryTextColor(Color? color) {
    SpUtil.putInt(spCyberPrimaryTextColor, color?.value ?? -1);
    notifyListeners();
  }
  void setCyberSecondaryTextColor(Color? color) {
    SpUtil.putInt(spCyberSecondaryTextColor, color?.value ?? -1);
    notifyListeners();
  }

  // —— 非赛博（主题版）颜色（供字体设置页独立读写）——
  Color? get themePrimaryTextColor =>
      _readCustom(spThemePrimaryTextColor);
  Color? get themeSecondaryTextColor =>
      _readCustom(spThemeSecondaryTextColor);
  void setThemePrimaryTextColor(Color? color) {
    SpUtil.putInt(spThemePrimaryTextColor, color?.value ?? -1);
    notifyListeners();
  }
  void setThemeSecondaryTextColor(Color? color) {
    SpUtil.putInt(spThemeSecondaryTextColor, color?.value ?? -1);
    notifyListeners();
  }

  Color? _readCustom(String key) {
    final custom = SpUtil.getInt(key, defValue: -1);
    return custom >= 0 ? Color(custom) : null;
  }

  /// 设置当前主题对应的主字体颜色（null 表示恢复默认），notifyListeners 让全局 rebuild
  void setCustomPrimaryTextColor(Color? color) {
    if (_isCyberNow) {
      setCyberPrimaryTextColor(color);
    } else {
      setThemePrimaryTextColor(color);
    }
  }

  /// 设置当前主题对应的次字体颜色（null 表示恢复默认），notifyListeners 让全局 rebuild
  void setCustomSecondaryTextColor(Color? color) {
    if (_isCyberNow) {
      setCyberSecondaryTextColor(color);
    } else {
      setThemeSecondaryTextColor(color);
    }
  }

  ThemeViewModel() {
    if (SpUtil.getBool(spThemeFollowSystem, defValue: false)) {
      changeThemeWithSystemStatus();
    } else {
      _themeMode = SpUtil.getInt(spThemeStyle, defValue: modeCyber);
    }

    changeThemeReal(_themeMode, false);
  }

  void changeThemeWithSystemStatus([bool must = true]) {
    if (SpUtil.getBool(spThemeFollowSystem, defValue: false) == false) return;
    var brightness = PlatformDispatcher.instance.platformBrightness;
    int theme;
    if (brightness == Brightness.dark) {
      theme = modeCyber;
    } else {
      theme =
          SpUtil.getInt(spVIP, defValue: typeNormal) != typeNormal
              ? modeWhite
              : modeLight;
    }
    if (!must && _themeMode == theme) return;
    changeThemeReal(theme);
  }

  void changeTheme(int themeMode) {
    if (_themeMode == themeMode) return;
    changeThemeReal(themeMode);
  }

  void changeThemeReal(int themeMode, [bool notify = true]) {
    _themeMode = themeMode;
    SpUtil.putInt(spThemeStyle, _themeMode);
    ThemeData newTheme;
    ThemeColors newColors;
    Color newPrimary;
    if (_themeMode == modeLight) {
      newTheme = getLightTheme();
      newColors = LightThemeColors();
      newPrimary = _primaryColor;
    } else if (_themeMode == modeDark) {
      // 黑色主题模式已合并为赛博模式，老用户存储的 modeDark 值也走赛博主题
      newTheme = getCyberTheme();
      newColors = CyberThemeColors();
      newPrimary = CyberColors.cyan;
    } else if (_themeMode == modeCyber) {
      newTheme = getCyberTheme();
      newColors = CyberThemeColors();
      newPrimary = CyberColors.cyan;
    } else {
      newTheme = getWhiteTheme();
      newColors = WhiteThemeColors();
      newPrimary = _primaryColor;
    }
    currentTheme = newTheme;
    if (Platform.isAndroid) {
      SystemUiOverlayStyle style;
      if (_themeMode == modeDark || _themeMode == modeCyber) {
        style = const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.black,
        );
      } else {
        style = const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white,
        );
      }
      SystemChrome.setSystemUIOverlayStyle(style);
    }
    if (notify) {
      _startTransition(newColors, newPrimary);
      notifyListeners();
    } else {
      _setFinal(newColors, newPrimary);
    }
  }

  get themeMode => _themeMode;

  ThemeData getWhiteTheme() {
    return ThemeData.light().copyWith(
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'MiSans'),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.light,
      primaryColor: _primaryColor,
      splashColor: Colors.transparent,
      colorScheme: ColorScheme.light(
        secondary: _primaryColor,
        primary: _primaryColor,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleColors.radiusSmall),
        ),
      ),
      scaffoldBackgroundColor: AppleColors.bgPrimary,
      dividerColor: const Color(0xFFE5E5EA),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E5EA)),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(
          fontSize: 17,
          color: AppleColors.textTertiary,
        ),
        labelStyle: TextStyle(color: _primaryColor, fontSize: 15),
        isDense: true,
        // Apple 胶囊形输入框：圆角24，水平16/垂直12
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleColors.spaceMd,
          vertical: 12,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _primaryColor, width: 2),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppleColors.bgPrimary,
        titleTextStyle: const TextStyle(
          color: AppleColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: TextStyle(color: _primaryColor),
        iconTheme: IconThemeData(color: _primaryColor),
        actionsIconTheme: IconThemeData(color: _primaryColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        unselectedItemColor: AppleColors.textSecondary,
        backgroundColor: AppleColors.bgPrimary,
        elevation: 0,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: _primaryColor,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleColors.radiusButton),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
          side: BorderSide(color: _primaryColor, width: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: _primaryColor),
      tabBarTheme: TabBarTheme(
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        labelColor: _primaryColor,
        unselectedLabelColor: AppleColors.textSecondary,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      hintColor: AppleColors.textTertiary,
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.black;
        }),
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return Colors.transparent;
        }),
      ),
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: AppleColors.bgSecondary,
      ),
    );
  }

  ThemeData getLightTheme() {
    return ThemeData.light().copyWith(
      textTheme: ThemeData.light().textTheme.apply(fontFamily: 'MiSans'),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.light,
      primaryColor: _primaryColor,
      splashColor: Colors.transparent,
      colorScheme: ColorScheme.light(
        secondary: _primaryColor,
        primary: _primaryColor,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleColors.radiusSmall),
        ),
      ),
      scaffoldBackgroundColor: AppleColors.bgPrimary,
      dividerColor: const Color(0xFFE5E5EA),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E5EA)),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(
          fontSize: 17,
          color: AppleColors.textTertiary,
        ),
        labelStyle: TextStyle(color: _primaryColor, fontSize: 15),
        isDense: true,
        // Apple 胶囊形输入框：圆角24，水平16/垂直12
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppleColors.spaceMd,
          vertical: 12,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _primaryColor, width: 2),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          borderRadius: BorderRadius.circular(AppleColors.radiusInput),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: TextStyle(color: Colors.white),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        unselectedItemColor: AppleColors.textSecondary,
        backgroundColor: AppleColors.bgPrimary,
        elevation: 0,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: _primaryColor,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppleColors.radiusButton),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
          side: BorderSide(color: _primaryColor, width: 1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppleColors.spaceLg,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleColors.radiusButton),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: _primaryColor),
      tabBarTheme: TabBarTheme(
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        labelColor: _primaryColor,
        unselectedLabelColor: AppleColors.textSecondary,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      hintColor: AppleColors.textTertiary,
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.black;
        }),
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return Colors.transparent;
        }),
      ),
      cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: AppleColors.bgSecondary,
      ),
    );
  }

  ThemeData getDartTheme() {
    return ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'MiSans'),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashColor: Colors.transparent,
      dividerColor: const Color(0xff444444),
      canvasColor: const Color(0xff1a1a1a),
      dividerTheme: const DividerThemeData(color: Color(0xff444444)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData().copyWith(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      brightness: Brightness.dark,
      primaryColor: const Color(0xffffffff),
      scaffoldBackgroundColor: const Color(0xff111111),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: const Color(0xff111111),
        titleTextStyle: const TextStyle(
          color: Color(0xffffffff),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: TextStyle(color: _primaryColor),
        iconTheme: IconThemeData(color: _primaryColor),
        actionsIconTheme: IconThemeData(color: _primaryColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: _primaryColor,
        backgroundColor: const Color(0x991B1B1B),
        elevation: 0,
      ),
      hintColor: const Color(0xffBBBBBB),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xffBBBBBB)),
        labelStyle: TextStyle(color: _primaryColor, fontSize: 14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xff999999), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xff999999), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xff999999), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      tabBarTheme: const TabBarTheme(
        labelStyle: TextStyle(fontSize: 14),
        unselectedLabelStyle: TextStyle(fontSize: 14),
        labelColor: Color(0xffffffff),
        unselectedLabelColor: Color(0xff999999),
      ),
      colorScheme: ColorScheme.dark(
        secondary: _primaryColor,
        primary: _primaryColor,
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.white;
        }),
      ),
      cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xffffffff),
        scaffoldBackgroundColor: Colors.black,
      ),
    );
  }

  /// 赛博终端主题
  ThemeData getCyberTheme() {
    return ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'MiSans'),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashColor: Colors.transparent,
      dividerColor: CyberColors.borderGlow,
      canvasColor: CyberColors.bg,
      dividerTheme: const DividerThemeData(color: CyberColors.borderGlow),
      floatingActionButtonTheme: const FloatingActionButtonThemeData().copyWith(
        backgroundColor: CyberColors.cyan,
        foregroundColor: CyberColors.bg,
      ),
      brightness: Brightness.dark,
      primaryColor: CyberColors.cyan,
      scaffoldBackgroundColor: CyberColors.bg,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        // 赛博模式顶部大标题：固定纯白（不跟随用户自定义字体色）
        // 三个模式（赛博/浅色/深色）的 title 颜色各自独立，
        // 赛博是深色底，标题必须保持高对比度白色，避免跟随字体色变浅
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
        toolbarTextStyle: TextStyle(color: CyberColors.cyan),
        iconTheme: IconThemeData(color: CyberColors.cyan),
        actionsIconTheme: IconThemeData(color: CyberColors.cyan),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: CyberColors.cyan,
        unselectedItemColor: CyberColors.hintGray,
        backgroundColor: CyberColors.bg.withValues(alpha: 0.7),
        elevation: 0,
      ),
      hintColor: CyberColors.hintGray,
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(fontSize: 14, color: CyberColors.hintGray),
        labelStyle: const TextStyle(color: CyberColors.cyan, fontSize: 14),
        isDense: true,
        // 圆柱形输入框：水平 padding 加大，圆角24（胶囊形）
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: CyberColors.cyan, width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: CyberColors.idleGray, width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: CyberColors.idleGray, width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: CyberColors.idleGray, width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      tabBarTheme: const TabBarTheme(
        labelStyle: TextStyle(fontSize: 14),
        unselectedLabelStyle: TextStyle(fontSize: 14),
        labelColor: CyberColors.cyan,
        unselectedLabelColor: CyberColors.hintGray,
      ),
      colorScheme: const ColorScheme.dark(
        secondary: CyberColors.cyan,
        primary: CyberColors.cyan,
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.selected)) {
            return CyberColors.bg;
          }
          return CyberColors.cyan;
        }),
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return CyberColors.cyan;
          }
          return Colors.transparent;
        }),
      ),
      cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CyberColors.cyan,
        scaffoldBackgroundColor: CyberColors.bg,
      ),
    );
  }
}

abstract class ThemeColors {
  Color settingBgColor();

  Color bg2Color();

  Color blackAndWhite();

  Color codeBgColor();

  Color pinedAndWhite();

  Color settingBordorColor();

  Color titleColor();

  Color title2Color();

  Color hintColor();

  Color descColor();

  Color filterColor();

  Color tabBarColor();

  Color pinColor();

  Color searchBgColor();

  Color buttonBgColor();

  Color segmentedUnCheckBg();

  Color otherFuncBg();

  Map<String, TextStyle> codeEditorTheme();

  List<Color> appBarBg();
}

class LightThemeColors extends ThemeColors {
  @override
  Color titleColor() => _customThemePrimaryOf(kThemePrimaryTextDefault);

  @override
  Color pinColor() => AppleColors.bgPrimary;

  @override
  Map<String, TextStyle> codeEditorTheme() => qinglongLightTheme;

  @override
  Color descColor() => _customThemeSecondaryOf(kThemeSecondaryTextDefault);

  @override
  Color settingBgColor() => AppleColors.bgPrimary;

  @override
  Color buttonBgColor() => _primaryColor;

  @override
  Color settingBordorColor() => AppleColors.bgPrimary;

  @override
  Color tabBarColor() => AppleColors.bgSecondary;

  @override
  List<Color> appBarBg() => [_primaryColor, _primaryColor];

  @override
  Color blackAndWhite() => Colors.white;

  @override
  Color filterColor() => AppleColors.textSecondary;

  @override
  Color title2Color() => AppleColors.textPrimary;

  @override
  Color hintColor() => _customThemeSecondaryOf(AppleColors.textTertiary);

  @override
  Color bg2Color() => AppleColors.bgSecondary;

  @override
  Color segmentedUnCheckBg() => AppleColors.bgTertiary;

  @override
  Color pinedAndWhite() => Colors.white;

  @override
  Color searchBgColor() => AppleColors.bgSecondary;

  @override
  Color otherFuncBg() => AppleColors.bgPrimary;

  @override
  Color codeBgColor() => AppleColors.bgPrimary;
}

class WhiteThemeColors extends ThemeColors {
  @override
  Color titleColor() => _customThemePrimaryOf(kThemePrimaryTextDefault);

  @override
  Color codeBgColor() => AppleColors.bgPrimary;

  @override
  Color pinColor() => AppleColors.bgPrimary;

  @override
  Color searchBgColor() => AppleColors.bgSecondary;

  @override
  Color otherFuncBg() => AppleColors.bgPrimary;

  @override
  Map<String, TextStyle> codeEditorTheme() => qinglongLightTheme;

  @override
  Color descColor() => _customThemeSecondaryOf(kThemeSecondaryTextDefault);

  @override
  Color pinedAndWhite() => Colors.white;

  @override
  Color settingBgColor() => AppleColors.bgPrimary;

  @override
  Color buttonBgColor() => _primaryColor;

  @override
  Color settingBordorColor() => AppleColors.bgPrimary;

  @override
  Color tabBarColor() => AppleColors.bgSecondary;

  @override
  List<Color> appBarBg() => [_primaryColor, _primaryColor];

  @override
  Color blackAndWhite() => Colors.white;

  @override
  Color filterColor() => AppleColors.textSecondary;

  @override
  Color title2Color() => AppleColors.textPrimary;

  @override
  Color hintColor() => _customThemeSecondaryOf(AppleColors.textTertiary);

  @override
  Color bg2Color() => AppleColors.bgSecondary;

  @override
  Color segmentedUnCheckBg() => AppleColors.bgTertiary;
}

class DartThemeColors extends ThemeColors {
  @override
  Color hintColor() {
    return _customThemeSecondaryOf(const Color(0xffBBBBBB));
  }

  @override
  Color title2Color() {
    return const Color(0xffffffff);
  }

  @override
  Color filterColor() {
    return const Color(0xffffffff);
  }

  @override
  Color pinedAndWhite() {
    return pinColor();
  }

  @override
  Color blackAndWhite() {
    return const Color(0xff111111);
  }

  @override
  Color titleColor() {
    return _customThemePrimaryOf(Colors.white);
  }

  @override
  Color pinColor() {
    return const Color(0xff202020);
  }

  @override
  Map<String, TextStyle> codeEditorTheme() {
    return qinglongDarkTheme;
  }

  @override
  Color descColor() {
    return _customThemeSecondaryOf(const Color(0xFF666666));
  }

  @override
  Color settingBgColor() {
    return const Color(0xff111111);
  }

  @override
  Color buttonBgColor() {
    return const Color(0xff333333);
  }

  @override
  Color settingBordorColor() {
    return const Color(0xff333333);
  }

  @override
  Color tabBarColor() {
    return const Color(0xff111111);
  }

  @override
  List<Color> appBarBg() {
    return [const Color(0xff111111), const Color(0xff111111)];
  }

  @override
  Color searchBgColor() {
    return const Color(0xff111111);
  }

  @override
  Color bg2Color() {
    return const Color(0xff111111);
  }

  @override
  Color otherFuncBg() {
    return Colors.transparent;
  }

  @override
  Color segmentedUnCheckBg() {
    return const Color(0xff333333);
  }

  @override
  Color codeBgColor() {
    return Color(0xff000000);
  }
}

/// 赛博终端配色
class CyberThemeColors extends ThemeColors {
  @override
  Color titleColor() => _customCyberPrimaryOf(kCyberPrimaryTextDefault);

  @override
  Color title2Color() => CyberColors.titleWhite;

  @override
  Color descColor() => _customCyberSecondaryOf(kCyberSecondaryTextDefault);

  @override
  Color hintColor() => _customCyberSecondaryOf(kCyberSecondaryTextDefault);

  @override
  Color settingBgColor() => CyberColors.bg;

  @override
  Color bg2Color() => const Color(0xFF12121A);

  @override
  Color blackAndWhite() => CyberColors.bg;

  @override
  Color codeBgColor() => const Color(0xFF000000);

  @override
  Color pinedAndWhite() => const Color(0xFF1A1A2E);

  @override
  Color settingBordorColor() => CyberColors.borderGlow;

  @override
  Color filterColor() => CyberColors.cyan;

  @override
  Color tabBarColor() => CyberColors.bg;

  @override
  Color pinColor() => const Color(0xFF1A1A2E);

  @override
  Color searchBgColor() => const Color(0xFF12121A);

  @override
  Color buttonBgColor() => CyberColors.cyan;

  @override
  Color segmentedUnCheckBg() => const Color(0xFF1A1A2E);

  @override
  Color otherFuncBg() => Colors.transparent;

  @override
  Map<String, TextStyle> codeEditorTheme() => qinglongDarkTheme;

  @override
  List<Color> appBarBg() => [CyberColors.bg, CyberColors.bg];
}

/// 主题切换过渡用的插值颜色包装器
///
/// 对齐 demos/theme_transition_demo 的全局颜色过渡机制：
/// 持有 from / to 两个 ThemeColors，动画期间按 t(0..1) 对每个颜色做 Color.lerp。
/// primaryColor、appBarBg 归为一组，文字/背景等归类为 ThemeColors 各方法。
class _LerpThemeColors implements ThemeColors {
  final ThemeColors from;
  final ThemeColors to;
  final double t;

  const _LerpThemeColors(this.from, this.to, this.t);

  Color _c(Color a, Color b) => Color.lerp(a, b, t)!;

  @override
  Color settingBgColor() => _c(from.settingBgColor(), to.settingBgColor());

  @override
  Color bg2Color() => _c(from.bg2Color(), to.bg2Color());

  @override
  Color blackAndWhite() => _c(from.blackAndWhite(), to.blackAndWhite());

  @override
  Color codeBgColor() => _c(from.codeBgColor(), to.codeBgColor());

  @override
  Color pinedAndWhite() => _c(from.pinedAndWhite(), to.pinedAndWhite());

  @override
  Color settingBordorColor() =>
      _c(from.settingBordorColor(), to.settingBordorColor());

  @override
  Color titleColor() => _c(from.titleColor(), to.titleColor());

  @override
  Color title2Color() => _c(from.title2Color(), to.title2Color());

  @override
  Color hintColor() => _c(from.hintColor(), to.hintColor());

  @override
  Color descColor() => _c(from.descColor(), to.descColor());

  @override
  Color filterColor() => _c(from.filterColor(), to.filterColor());

  @override
  Color tabBarColor() => _c(from.tabBarColor(), to.tabBarColor());

  @override
  Color pinColor() => _c(from.pinColor(), to.pinColor());

  @override
  Color searchBgColor() => _c(from.searchBgColor(), to.searchBgColor());

  @override
  Color buttonBgColor() => _c(from.buttonBgColor(), to.buttonBgColor());

  @override
  Color segmentedUnCheckBg() =>
      _c(from.segmentedUnCheckBg(), to.segmentedUnCheckBg());

  @override
  Color otherFuncBg() => Color.lerp(from.otherFuncBg(), to.otherFuncBg(), t)!;

  @override
  Map<String, TextStyle> codeEditorTheme() => to.codeEditorTheme();

  @override
  List<Color> appBarBg() {
    final a = from.appBarBg();
    final b = to.appBarBg();
    return [
      for (var i = 0; i < a.length && i < b.length; i++) Color.lerp(a[i], b[i], t)!,
    ];
  }
}

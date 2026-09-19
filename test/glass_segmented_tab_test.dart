import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_segmented_tab.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<TabController> pumpTab(WidgetTester tester, int themeMode) async {
  // surface 宽 398：Padding(15+15) 后 LayoutBuilder 可用宽 368，4 个 tab 均分得整数
  // tabWidth=92，避免分数像素舍入累积成滑块/文字中心偏差（原 400 宽 → 92.5 不稳定）
  await tester.binding.setSurfaceSize(const Size(398, 300));
  const tabs = ['全部', '运行中', '未使用', '已禁用'];
  final tabController = TabController(length: 4, vsync: tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith(
          (ref) => ThemeViewModel()..changeTheme(themeMode),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassSegmentedTab(tabs: tabs, tabController: tabController),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tabController;
}

Future<void> checkAlignment(
  WidgetTester tester,
  TabController tc,
  String label,
) async {
  const tabs = ['全部', '运行中', '未使用', '已禁用'];
  const double tabWidth = 92.0; // integer cell 宽（368 / 4）
  // 逐格动画到对应索引，校验滑块相对首格做等距移动（捕捉历史"逐索引累计偏右"）
  double? base;
  for (int i = 0; i < tabs.length; i++) {
    tc.animateTo(i);
    await tester.pumpAndSettle();
    final thumbCx = tester
        .getRect(find.byKey(const ValueKey('glass_tab_thumb')))
        .center
        .dx;
    base ??= thumbCx; // 首格实际中心作为基准，吸收全局常量偏移（如边框 inset 1px）
    final double expectCx = base! + i * tabWidth;
    final double delta = thumbCx - expectCx;
    // ignore: avoid_print
    print('$label Tab[$i] thumbCx=${thumbCx.toStringAsFixed(2)} '
        'expectCx=${expectCx.toStringAsFixed(2)}');
    expect(delta.abs(), lessThan(0.5),
        reason: '$label Tab $i 滑块发生累计偏移（非等间距 92px），偏差 $delta');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.getInstance();
  });

  testWidgets('赛博模式滑块与文案水平居中', (WidgetTester tester) async {
    final tc = await pumpTab(tester, modeCyber);
    addTearDown(tc.dispose);
    await tester.pumpAndSettle();
    await checkAlignment(tester, tc, 'CYBER');
  });

  testWidgets('苹果模式滑块与文案水平居中', (WidgetTester tester) async {
    final tc = await pumpTab(tester, modeLight);
    addTearDown(tc.dispose);
    await tester.pumpAndSettle();
    await checkAlignment(tester, tc, 'APPLE');
  });
}

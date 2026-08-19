import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_segmented_tab.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<TabController> pumpTab(WidgetTester tester, int themeMode) async {
  await tester.binding.setSurfaceSize(const Size(400, 300));
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
  for (int i = 0; i < tabs.length; i++) {
    tc.animateTo(i);
    await tester.pumpAndSettle();

    final thumb = find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration && d.gradient is LinearGradient;
    });
    final thumbRect = tester.getRect(thumb);
    final textRect = tester.getRect(find.text(tabs[i]));
    final delta = thumbRect.center.dx - textRect.center.dx;
    // ignore: avoid_print
    print('$label Tab[$i] delta=${delta.toStringAsFixed(3)}');
    expect(delta.abs(), lessThan(1.0),
        reason: '$label Tab $i 滑块与文案水平中心偏差过大: $delta');
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

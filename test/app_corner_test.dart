import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/base/ui/app_corner.dart';
import 'package:qinglong_app/base/ui/capsule_glow_card.dart';

double _pathLength(Path path) {
  double total = 0;
  for (final metric in path.computeMetrics()) {
    total += metric.length;
  }
  return total;
}

void _expectBounds(Path path, Rect rect, {String? reason}) {
  final bounds = path.getBounds();
  expect(bounds.left, closeTo(rect.left, 0.01), reason: reason);
  expect(bounds.top, closeTo(rect.top, 0.01), reason: reason);
  expect(bounds.right, closeTo(rect.right, 0.01), reason: reason);
  expect(bounds.bottom, closeTo(rect.bottom, 0.01), reason: reason);
}

void main() {
  group('appCornerStyleFor', () {
    test('小圆角走普通圆角', () {
      expect(
        appCornerStyleFor(8, const Size(300, 120)),
        AppCornerStyle.circular,
      );
      expect(
        appCornerStyleFor(10, const Size(300, 120)),
        AppCornerStyle.circular,
      );
    });

    test('大圆角走连续曲率', () {
      expect(
        appCornerStyleFor(18, const Size(300, 120)),
        AppCornerStyle.continuous,
      );
      expect(
        appCornerStyleFor(24, const Size(300, 120)),
        AppCornerStyle.continuous,
      );
    });

    test('半径达到短边一半的胶囊走普通圆角', () {
      expect(
        appCornerStyleFor(24, const Size(300, 48)),
        AppCornerStyle.circular,
      );
      expect(
        appCornerStyleFor(60, const Size(300, 120)),
        AppCornerStyle.circular,
      );
    });

    test('零或负半径走普通圆角', () {
      expect(
        appCornerStyleFor(0, const Size(300, 120)),
        AppCornerStyle.circular,
      );
      expect(
        appCornerStyleFor(-4, const Size(300, 120)),
        AppCornerStyle.circular,
      );
    });
  });

  group('appCornerBorder', () {
    test('按 style 返回引擎原生形状', () {
      expect(appCornerBorder(radius: 18), isA<RoundedSuperellipseBorder>());
      expect(
        appCornerBorder(radius: 8, style: AppCornerStyle.circular),
        isA<RoundedRectangleBorder>(),
      );
      expect(appCornerBorder(radius: 0), isA<RoundedRectangleBorder>());
    });

    test('不同宽高比下轮廓包围盒都等于布局矩形', () {
      const sizes = <Size>[
        Size(200, 200),
        Size(300, 120),
        Size(600, 24),
        Size(48, 48),
      ];
      for (final size in sizes) {
        final rect = Rect.fromLTWH(12, 8, size.width, size.height);
        final radius = math.min(size.width, size.height) / 4;
        final shape = appCornerBorder(radius: radius);
        _expectBounds(shape.getOuterPath(rect), rect, reason: '$size');
      }
    });

    test('连续曲率与普通圆角是不同轮廓', () {
      const rect = Rect.fromLTWH(0, 0, 300, 120);
      final continuous =
          appCornerBorder(radius: 24).getOuterPath(rect);
      final circular = appCornerBorder(
        radius: 24,
        style: AppCornerStyle.circular,
      ).getOuterPath(rect);

      final delta = (_pathLength(continuous) - _pathLength(circular)).abs();
      expect(delta, greaterThan(0.5));
    });

    test('半径达到短边一半（胶囊）仍能生成有效轮廓', () {
      const rect = Rect.fromLTWH(0, 0, 300, 120);
      final shape = appCornerBorder(radius: 60);
      _expectBounds(shape.getOuterPath(rect), rect, reason: 'capsule');
    });

    test('带边框时内轮廓按 strokeInset 内缩', () {
      const rect = Rect.fromLTWH(0, 0, 200, 100);
      final shape = appCornerBorder(
        radius: 18,
        side: const BorderSide(width: 2),
      );
      _expectBounds(shape.getInnerPath(rect), rect.deflate(2), reason: 'inner');
      _expectBounds(shape.getOuterPath(rect), rect, reason: 'outer');
    });

    test('支持仅顶部圆角的边框输入', () {
      final shape = appCornerBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      );
      expect(shape, isA<RoundedSuperellipseBorder>());
      _expectBounds(
        shape.getOuterPath(const Rect.fromLTWH(0, 0, 300, 200)),
        const Rect.fromLTWH(0, 0, 300, 200),
        reason: 'top-only',
      );
    });

    testWidgets('3x DPR 下 Material/InkWell/ShapeDecoration 正常绘制', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Material(
                    shape: appCornerBorder(radius: 18),
                    color: const Color(0xFF00CCCC),
                    child: InkWell(
                      onTap: () {},
                      child: const SizedBox(width: 200, height: 100),
                    ),
                  ),
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: appCornerBorder(radius: 18),
                      color: const Color(0xFF00CCCC),
                    ),
                    child: const SizedBox(width: 200, height: 100),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('CapsuleGlowCard', () {
    testWidgets('连续曲率与普通圆角都能正常绘制', (tester) async {
      for (final style in AppCornerStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CapsuleGlowCard(
                  isCyber: false,
                  cornerStyle: style,
                  child: const SizedBox(width: 300, height: 100),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$style');
      }
    });
  });
}

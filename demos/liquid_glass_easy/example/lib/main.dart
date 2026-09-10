import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'tab_bar_page.dart' show TabBarPage;

// =============================================================
// Liquid Glass Easy — 本 demo 默认入口：底部液态玻璃导航栏实验页。
//
// 评估对象：q 弹按压缩放 + 长按识别（我的 0.5s / 其余 0.1s）+ 整栏跟手滑动
// （酷安式）。官方 LensImagePage 展示页已弃用为默认入口（如需查看可
// `flutter run -t lib/main.dart` 临时改回）。
// -------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 预编译液态玻璃 shader：LiquidGlassLens 首次渲染即走完整 shader 路径，
  // 避免首帧走 frosted fallback（fallback 仅模糊 + 细边框，无折射、无外圈
  // 高光 —— "顶部 tab 外圈高光丢失"的根源之一）。
  await LiquidGlassShaders.ensureLoaded();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const TabBarPage(),
    );
  }
}


/// A page showcasing the blend over a photographic background.
class LensImagePage extends StatefulWidget {
  const LensImagePage({super.key});

  @override
  State<LensImagePage> createState() => _LensImagePageState();
}

class _LensImagePageState extends State<LensImagePage> {
  // Busy detail makes the refraction easy to read as the glass passes over it.
  // Served from the project's asset repo (same source as the other demos).
  static const String _imageUrl =
      'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets'
      '/main/blending.jpg';

  // Top-left of each draggable shape — placed close so they start fused.
  Offset _card = const Offset(40, 170);
  Offset _circle = const Offset(60, 270);
  Offset _squircle = const Offset(150, 320);

  // The merged material: clear glass (NO blur), slight tint + saturation, an
  // optical rim and a gentle optical refraction.
  static const _groupStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: 36,
      borderWidth: 1.5,
    ),
    appearance: LiquidGlassAppearance(
      color: Color(0x14FFFFFF),
      saturation: 1.05,
      blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
    ),
    refraction: LiquidGlassRefraction(
      refractionType: OpticalRefraction(
        refraction: 1.5,
        refractionWidth: 24,
        depth: 0.7,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Lens over image'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LiquidGlassView(
        backgroundWidget: const _Background(url: _imageUrl),
        child: Stack(
          children: [
            Positioned.fill(
              child: LiquidGlassBlender(
                smoothness: 58,
                style: _groupStyle,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _draggable(
                      pos: _card,
                      size: const Size(248, 120),
                      shape: const LiquidGlassShape.continuousRoundedRectangle(
                        cornerRadius: 32,
                      ),
                      onMove: (d) => setState(() => _card += d),
                      child: const _CardContent(),
                    ),
                    _draggable(
                      pos: _circle,
                      size: const Size(120, 120),
                      shape: const LiquidGlassShape.roundedRectangle(
                        cornerRadius: 60,
                      ),
                      onMove: (d) => setState(() => _circle += d),
                      child: const Icon(Icons.favorite_rounded,
                          color: Colors.white, size: 38),
                    ),
                    _draggable(
                      pos: _squircle,
                      size: const Size(140, 140),
                      shape: const LiquidGlassShape.squircle(cornerRadius: 40),
                      onMove: (d) => setState(() => _squircle += d),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 40),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: IgnorePointer(
                child: Text(
                  'Drag the glass shapes together to blend',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _draggable({
    required Offset pos,
    required Size size,
    required LiquidGlassShape shape,
    required ValueChanged<Offset> onMove,
    required Widget child,
  }) {
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (e) => onMove(e.delta),
        child: LiquidGlassLens(
          style: LiquidGlassStyle(shape: shape),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Liquid Glass',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Refraction over a live photo',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// The refractable background captured by [LiquidGlassView]: the network photo
/// (with a gradient fallback) plus a soft scrim for text legibility.
class _Background extends StatelessWidget {
  final String url;
  const _Background({required this.url});

  static const _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E1065), Color(0xFF0EA5E9), Color(0xFFF59E0B)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Stack(
              fit: StackFit.expand,
              children: [
                _fallback,
                Center(child: CircularProgressIndicator(color: Colors.white)),
              ],
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0x66000000)],
            ),
          ),
        ),
      ],
    );
  }
}

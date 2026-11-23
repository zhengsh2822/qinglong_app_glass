import 'dart:ui' show ImageFilter;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

void main() => runApp(const KbSpringDemoApp());

class KbSpringDemoApp extends StatelessWidget {
  const KbSpringDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '悬浮输入框回弹方案对比',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF06090E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const ComparePage(),
    );
  }
}

/// 回弹方案（悬浮输入框定位：列表独立滚动，输入框悬浮在键盘/底部之上）
enum Scheme {
  follow, // 悬浮·纯跟随
  trailing, // 悬浮·落地弹性
  takeover, // 悬浮·弹簧接管
}

extension SchemeInfo on Scheme {
  String get label => switch (this) {
        Scheme.follow => '悬浮·纯跟随',
        Scheme.trailing => '悬浮·落地弹性',
        Scheme.takeover => '悬浮·弹簧接管',
      };

  String get detail => switch (this) {
        Scheme.follow =>
          '输入框始终悬浮在键盘上沿，1:1 跟随 IME；列表独立滚动不被推动',
        Scheme.trailing =>
          '1:1 跟随，键盘落地瞬间按末速度 kick 小幅 dip 后归位（仅输入框本体）',
        Scheme.takeover =>
          '收起瞬间输入框由 SpringSimulation 带速度一次弹到底（popupOpen 可见过冲）',
      };
}

/// 统一弹簧规格（逐值镜像自主项目 lib/base/ui/spring_sheet.dart 的
/// SpringSheetSpec——demo 独立工程无法 import 主包，迁移时直接用真组件）
class SpringSheetSpec {
  const SpringSheetSpec._();

  /// 弹出（ζ≈0.74，过冲≈3%）
  static const SpringDescription open = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: 21,
  );

  /// 「我的」长按账号弹窗入场（ζ≈0.5，过冲≈16%，一次可见回弹）
  static const SpringDescription popupOpen = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: 14,
  );

  /// 关闭（ζ≈0.735，过冲≈3%，更快）
  static const SpringDescription close = SpringDescription(
    mass: 1,
    stiffness: 290,
    damping: 25,
  );
}

/// 落地 dip 的末速度接力上限（px/s）：真机 IME 收起峰值速度 ~1900，
/// 全量接力会 dip 出 ~75px（过头），钳到 tasteful 幅度
const double _dipVelocityClamp = 700;

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Scheme _scheme = Scheme.trailing;

  // ── 模拟 IME（250ms easeInOutCubic，与真机 IME 节奏一致）──
  late final AnimationController _ime = AnimationController.unbounded(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  double _simFrom = 0;
  double _simTarget = 0;
  double _inset = 0; // 当前生效 inset（模拟或真实）

  // ── 速度跟踪（px/s，正=键盘升高）──
  double _velocity = 0;
  DateTime _lastInsetAt = DateTime.now();

  // ── 落地 dip 弹簧（方案 trailing：按末速度 kick，仅输入框本体）──
  late final AnimationController _dipCtrl = AnimationController.unbounded(
    vsync: this,
  );
  double _dip = 0;

  // ── 弹簧接管（方案 takeover）──
  late final AnimationController _takeCtrl = AnimationController.unbounded(
    vsync: this,
  );
  double _takeoverValue = 0;
  bool _takeover = false;
  // 弹簧当前速度采样（重定目标时接力；px/s，正=上移）
  double _takeVel = 0;
  double _prevTake = 0;
  DateTime? _takeLastAt;

  // ── 真实键盘 ──
  double _realInset = 0;
  double _lastExpandInset = 0;
  bool _collapseSpringUsed = false; // 一次收起只接管一次（防落地后重复触发）
  Timer? _expandStableTimer; // 弹起停稳兜底（减速检测未触发时）
  bool _expandDipKicked = false; // 本次弹起的 dip 只踢一次
  double _expandPeakVel = 0; // 本次弹起的 IME 峰值速度

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ime.addListener(_onImeTick);
    _dipCtrl.addListener(() {
      if (mounted) setState(() => _dip = _dipCtrl.value);
    });
    _takeCtrl.addListener(() {
      final now = DateTime.now();
      if (_takeLastAt != null) {
        final dt = now.difference(_takeLastAt!).inMicroseconds / 1e6;
        if (dt > 0 && dt < 0.2) {
          _takeVel = (_takeCtrl.value - _prevTake) / dt;
        }
      }
      _prevTake = _takeCtrl.value;
      _takeLastAt = now;
      if (mounted) setState(() => _takeoverValue = _takeCtrl.value);
    });
  }

  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final bottom = view.viewInsets.bottom / view.devicePixelRatio;
    if ((bottom - _realInset).abs() < 0.5) return;
    _trackVelocity(bottom, DateTime.now());

    // 真实键盘落地：kick 落地弹簧（仅 trailing）
    if (bottom <= 0.5 &&
        _realInset > 0.5 &&
        _scheme == Scheme.trailing &&
        !_takeover) {
      _kickDip();
    }
    // 真实键盘分方向最优机制：
    // 弹起 = 1:1 跟随（弹簧追匀速目标有稳态滞后 c·v/k ≈ 160px，不可用），
    //        停稳后补 transform dip 回弹；
    // 收起 = 一次性静态目标弹簧接管（超车落底+落点回弹，目标静态无滞后）
    if (_scheme == Scheme.takeover) {
      final bool rising = bottom > _realInset;
      if (rising) {
        // 弹起：退出接管态，1:1 跟随
        if (_realInset <= 0.5 || bottom > _lastExpandInset + 1) {
          // 新一轮弹起：重置减速检测
          _expandDipKicked = false;
          _expandPeakVel = 0;
        }
        _takeover = false;
        _takeCtrl.stop();
        _collapseSpringUsed = false;
        _expandPeakVel = _expandPeakVel < _velocity.abs()
            ? _velocity.abs()
            : _expandPeakVel;
        // 减速段就地触发 dip：IME 速度衰减到峰值 35% 以下 = 正在到位，
        // 此刻起播 dip 与键盘到位同步（不再等停稳后慢半拍）
        if (!_expandDipKicked &&
            bottom > 0.5 &&
            _expandPeakVel > 800 &&
            _velocity.abs() < _expandPeakVel * 0.35) {
          _expandDipKicked = true;
          _kickDip(fixedVelocity: -320);
        }
        _lastExpandInset = bottom;
        // 停稳兜底：减速检测未触发时（如 IME 末段跳变），停稳 120ms 补
        _expandStableTimer?.cancel();
        if (bottom > 0.5 && !_expandDipKicked) {
          _expandStableTimer = Timer(const Duration(milliseconds: 120), () {
            if (mounted && _effectiveInset > 0 && !_expandDipKicked) {
              _expandDipKicked = true;
              _kickDip(fixedVelocity: -320);
            }
          });
        }
      } else if (bottom <= 0.5) {
        // 落地：重置展开减速检测（下次弹起重新计）
        _expandDipKicked = false;
        _expandPeakVel = 0;
        _expandStableTimer?.cancel();
      } else if (!_takeover && !_collapseSpringUsed && _realInset > 0.5) {
        // 收起中：一次性接管（目标 = 静止位，静态无滞后）
        _collapseSpringUsed = true;
        _startTakeover(_composerBottom, _navGap + 2, velocity: _velocity);
      }
    }
    _realInset = bottom;
    if (mounted) setState(() {});
  }

  void _trackVelocity(double next, DateTime now) {
    final dt = now.difference(_lastInsetAt).inMicroseconds / 1e6;
    if (dt > 0 && dt < 0.2) {
      _velocity = (next - _effectiveInset) / dt;
    }
    _lastInsetAt = now;
  }

  // ── 模拟 IME ────────────────────────────────────────────────
  void _toggleSimKeyboard() {
    final collapsing = _simTarget > 0; // 当前有键盘 → 这次是收起
    _simTarget = collapsing ? 0 : 320;
    _dip = 0;
    _dipCtrl.value = 0;
    // 弹簧接管分方向：收起 = 静态目标弹簧（超车+落点回弹）；弹起 =
    // 1:1 跟随（弹簧追移动目标有稳态滞后）+ 完成补 dip 回弹
    if (_scheme == Scheme.takeover && collapsing) {
      _collapseSpringUsed = true;
      _startTakeover(_composerBottom, _navGap + 2, velocity: _velocity);
      _simFrom = _inset;
      _ime.animateWith(
        _LerpSimulation(
          _simFrom,
          _simTarget,
          _ime.duration ?? const Duration(milliseconds: 250),
          Curves.easeInOutCubic,
        ),
      );
      return;
    }
    _simFrom = _inset;
    _ime
        .animateWith(
          _LerpSimulation(
            _simFrom,
            _simTarget,
            _ime.duration ?? const Duration(milliseconds: 250),
            Curves.easeInOutCubic,
          ),
        )
        .whenComplete(() {
      if (_scheme == Scheme.trailing && _simTarget == 0 && _velocity < -250) {
        // 落地：按末速度 kick 落地弹簧（仅 trailing，仅收起）
        _kickDip();
      } else if (_scheme == Scheme.takeover && _simTarget > 0) {
        // 弹起停稳：补 dip 回弹（takeover 弹起为 1:1 跟随）
        _kickDip(fixedVelocity: -320);
      }
    });
  }

  void _onImeTick() {
    // _LerpSimulation 内部已应用 IME 曲线，controller.value 即曲线后的值
    final v = _ime.value;
    _trackVelocity(v, DateTime.now());
    _inset = v;
    if (mounted) setState(() {});
  }

  void _kickDip({double? fixedVelocity}) {
    final v = fixedVelocity ??
        _velocity.clamp(-_dipVelocityClamp, _dipVelocityClamp);
    _dipCtrl.animateWith(SpringSimulation(SpringSheetSpec.open, 0, 0, v));
  }

  /// 弹簧接管：from = 当前悬浮位，to = 静止位（安全区+2）。
  /// 目标必须是最终静止位——此前弹向 0（键盘上沿），落定后还要跳一次
  /// 新间距 =「先旧间距、过一会变新间距」两段跳（用户实测 bug）。
  void _startTakeover(double from, double to, {double? velocity}) {
    _takeover = true;
    _takeVel = velocity ?? _takeVel;
    _takeCtrl
        .animateWith(
          SpringSimulation(
            // close 规格（ζ≈0.735）：过冲 3%≈10px——收起落在静止位下方、
            // 弹起冲过键盘上沿，方向都朝屏内 = 可见回弹且永不消失
            SpringSheetSpec.close,
            from,
            to,
            _takeVel.clamp(-_dipVelocityClamp * 2, _dipVelocityClamp * 2),
          ),
        )
        .whenComplete(() {
      if (!mounted) return;
      setState(() => _takeover = false);
    });
  }

  // ── 输出 ────────────────────────────────────────────────────
  double get _effectiveInset => _realInset > 0 ? _realInset : _inset;

  /// 安全区高度（小白条手势区）——与底部导航同源
  double get _navGap => MediaQuery.of(context).viewPadding.bottom;

  /// 输入框悬浮 bottom（Stack Positioned）
  /// 收起态 = 安全区 + 2（与底部导航 margin bottom:2 完全一致，小白条不遮挡）
  /// 弹起态 = 键盘 inset + 8（贴键盘上沿）
  double get _composerBottom {
    final double base;
    if (_effectiveInset > 0) {
      base = _effectiveInset + 8;
    } else {
      base = _navGap + 2;
    }
    switch (_scheme) {
      case Scheme.follow:
      case Scheme.trailing:
        return base;
      case Scheme.takeover:
        // 接管中直接用弹簧值（含对静止位的 ~10px 可见过冲，全程屏内）
        return _takeover ? _takeoverValue.clamp(2.0, double.infinity) : base;
    }
  }

  /// 输入框本体 transform 回弹（不影响列表布局）
  double get _composerTranslate {
    switch (_scheme) {
      case Scheme.trailing:
      case Scheme.takeover: // 弹起停稳后的 dip 也走 transform（takeover 弹起为 1:1 跟随）
        return _dip.clamp(-80.0, 0.0);
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = _effectiveInset;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Stack(
              children: [
                // 列表：底部只让位键盘——内容从毛玻璃输入框底下穿过（真悬浮）
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: inset + 8),
                    child: _buildChatList(),
                  ),
                ),
                // 悬浮输入框：Positioned 定位在键盘/底部之上
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: _composerBottom,
                  child: Transform.translate(
                    offset: Offset(0, _composerTranslate),
                    child: _buildComposer(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '悬浮输入框 · 回弹方案对比',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _scheme.detail,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF6B7A8C),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final s in Scheme.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _scheme == s,
                    selectedColor: const Color(0x3300E5FF),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _scheme == s
                          ? const Color(0xFF00E5FF)
                          : Colors.white70,
                    ),
                    side: BorderSide(
                      color: _scheme == s
                          ? const Color(0x6600E5FF)
                          : Colors.white24,
                    ),
                    onSelected: (_) {
                      _takeCtrl.stop();
                      _takeover = false;
                      _takeoverValue = 0;
                      _dip = 0;
                      _dipCtrl.value = 0;
                      setState(() => _scheme = s);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: _toggleSimKeyboard,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0x1A00E5FF),
                    foregroundColor: const Color(0xFF00E5FF),
                  ),
                  child: Text(
                    _simTarget > 0 || _effectiveInset > 0 ? '模拟收起' : '模拟弹起',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '也可点下方输入框拉起真实键盘',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7A8C)),
                  ),
                ),
              ],
            ),
            const Divider(height: 18, color: Colors.white10),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: 14,
      itemBuilder: (context, i) {
        final mine = i.isOdd;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: mine
                  ? const Color(0x2600E5FF)
                  : const Color(0xFF141B26),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: mine ? const Color(0x4400E5FF) : Colors.white10,
              ),
            ),
            child: Text(
              mine
                  ? '消息 $i：这是一条用户消息，用来撑出列表内容。'
                  : '回复 $i：AI 回复内容，检查键盘收起时列表是否跟手稳定。',
              style: const TextStyle(fontSize: 13.5, height: 1.5),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    // 真悬浮：毛玻璃半透明底（BackdropFilter 实时采样从底下滚过的消息），
    // 不再是不透明色块
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x59141820),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x3300E5FF)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '输入消息（可拉起真实键盘）',
                    isDense: true,
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7A8C),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onTapOutside:
                      (_) => FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.send_rounded,
                size: 22,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// from→target 插值 Simulation（内部应用 IME 曲线）
class _LerpSimulation extends Simulation {
  final double from;
  final double to;
  final Duration duration;
  final Curve curve;

  _LerpSimulation(this.from, this.to, this.duration, this.curve);

  @override
  double x(double timeInSeconds) {
    final t = (timeInSeconds * 1000 / duration.inMilliseconds).clamp(0.0, 1.0);
    return from + (to - from) * curve.transform(t);
  }

  @override
  double dx(double timeInSeconds) {
    return (to - from) * (1 / (duration.inMilliseconds / 1000));
  }

  @override
  bool isDone(double timeInSeconds) =>
      timeInSeconds * 1000 >= duration.inMilliseconds;
}

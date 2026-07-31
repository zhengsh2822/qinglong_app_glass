import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';

/// 呼吸光晕包装器
/// 为运行中的任务卡片提供青色呼吸 BoxShadow 动画
class BreathingGlow extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color glowColor;

  const BreathingGlow({
    Key? key,
    required this.child,
    this.active = false,
    this.glowColor = CyberColors.cyan,
  }) : super(key: key);

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(BreathingGlow old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && old.active) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          // padding留出光晕渲染空间，防止被ListView/Slidable裁剪
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: 0.12 * _animation.value,
                ),
                blurRadius: 6 * _animation.value + 2,
                spreadRadius: 0.5 * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 任务运行状态
enum HoloTaskStatus { idle, running, success, failed, disabled }

/// 全息任务卡片
///
/// 设计理念：将每个脚本任务具象化为一张半透明全息卡。
/// - 卡片背景：半透明深灰，边框为赛博青色细线
/// - 运行中状态：BoxShadow 青色呼吸光晕动画
/// - 脚本名称：等宽字体，强化代码感
/// - 右上角状态指示灯：灰(待机)/青色呼吸(运行)/荧光绿(成功)/红(失败)
class HoloTaskCard extends StatefulWidget {
  final String name;
  final String? command;
  final String? schedule;
  final HoloTaskStatus status;
  final bool isPinned;
  final bool editMode;
  final bool checked;
  final String? lastTime;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChecked;

  const HoloTaskCard({
    Key? key,
    required this.name,
    this.command,
    this.schedule,
    this.status = HoloTaskStatus.idle,
    this.isPinned = false,
    this.editMode = false,
    this.checked = false,
    this.lastTime,
    this.onTap,
    this.onChecked,
  }) : super(key: key);

  @override
  State<HoloTaskCard> createState() => _HoloTaskCardState();
}

class _HoloTaskCardState extends State<HoloTaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    // 呼吸动画：1.5秒一个周期，循环播放
    _breathController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    // CurvedAnimation 让光晕有"吸气-呼气"的缓动节奏
    _breathAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    if (widget.status == HoloTaskStatus.running) {
      _breathController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(HoloTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 状态变化时启动/停止呼吸动画
    if (widget.status == HoloTaskStatus.running &&
        oldWidget.status != HoloTaskStatus.running) {
      _breathController.repeat(reverse: true);
    } else if (widget.status != HoloTaskStatus.running &&
        oldWidget.status == HoloTaskStatus.running) {
      _breathController.stop();
      _breathController.reset();
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  Color _statusColor() {
    switch (widget.status) {
      case HoloTaskStatus.running:
        return CyberColors.cyan;
      case HoloTaskStatus.success:
        return CyberColors.neonGreen;
      case HoloTaskStatus.failed:
        return CyberColors.neonRed;
      case HoloTaskStatus.disabled:
        return CyberColors.idleGray;
      case HoloTaskStatus.idle:
        return CyberColors.idleGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final isRunning = widget.status == HoloTaskStatus.running;

    return AnimatedBuilder(
      animation: _breathAnimation,
      builder: (context, child) {
        // 运行中时 BoxShadow 的 spreadRadius 和 opacity 随呼吸动画变化
        final glowAlpha = isRunning ? _breathAnimation.value : 0.0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            // 半透明深灰卡片背景
            color: CyberColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isPinned
                      ? CyberColors.cyan.withValues(alpha: 0.6)
                      : CyberColors.borderGlow,
              width: isPinned ? 1.5 : 1,
            ),
            boxShadow:
                isRunning
                    ? [
                      // 青色呼吸光晕：spreadRadius 和 blurRadius 随动画值变化
                      BoxShadow(
                        color: CyberColors.cyan.withValues(
                          alpha: 0.15 * glowAlpha,
                        ),
                        blurRadius: 12 * glowAlpha + 4,
                        spreadRadius: 2 * glowAlpha,
                      ),
                    ]
                    : [],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap:
              widget.editMode
                  ? () => widget.onChecked?.call(widget.name)
                  : widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 编辑模式勾选框
                if (widget.editMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      widget.checked
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color:
                          widget.checked
                              ? CyberColors.cyan
                              : CyberColors.idleGray,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // 左侧状态指示竖条
                Container(
                  width: 3,
                  height: 40,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow:
                        isRunning
                            ? [
                              BoxShadow(
                                color: CyberColors.cyan.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ]
                            : [],
                  ),
                ),
                // 中间内容区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 脚本名称 - 等宽字体
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: CyberColors.monoFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CyberColors.titleWhite,
                          package: null,
                        ),
                      ),
                      if (widget.schedule != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.schedule!,
                          style: TextStyle(
                            fontFamily: CyberColors.monoFont,
                            fontSize: 11,
                            color: CyberColors.cyan.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      if (widget.command != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.command!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: CyberColors.descColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 右侧：状态指示灯 + 时间
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 状态指示灯 - 小圆点
                    _StatusDot(
                      color: statusColor,
                      isRunning: isRunning,
                      breathAnimation: _breathAnimation,
                    ),
                    const SizedBox(height: 6),
                    if (widget.lastTime != null)
                      Text(
                        widget.lastTime!,
                        style: TextStyle(
                          fontSize: 10,
                          color: CyberColors.descColor,
                          fontFamily: CyberColors.monoFont,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get isPinned => widget.isPinned;
}

/// 状态指示灯
/// 待机=灰 / 运行中=青色呼吸 / 成功=荧光绿 / 失败=红
class _StatusDot extends StatelessWidget {
  final Color color;
  final bool isRunning;
  final Animation<double> breathAnimation;

  const _StatusDot({
    required this.color,
    required this.isRunning,
    required this.breathAnimation,
  });

  @override
  Widget build(BuildContext context) {
    if (!isRunning) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    // 运行中：圆点亮度随呼吸动画变化
    return AnimatedBuilder(
      animation: breathAnimation,
      builder: (context, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.4 + 0.6 * breathAnimation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5 * breathAnimation.value),
                blurRadius: 6 * breathAnimation.value + 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

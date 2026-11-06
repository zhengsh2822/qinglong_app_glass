import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/ui/app_corner.dart';

/// 滑动操作按钮数据模型
class CyberSlideAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CyberSlideAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// 全局通用滑动操作组件
///
/// 赛博模式：独立圆角胶囊按钮 + 外发光 + 按钮间距
/// 按钮宽度：每个占屏幕宽度 18%（4个=72%、3个=54%、2个=36%）
class CyberSlidable extends StatelessWidget {
  final Widget child;
  final List<CyberSlideAction> startActions;
  final List<CyberSlideAction> endActions;
  final Key? slidableKey;
  final bool enabled;
  final double borderRadius;

  const CyberSlidable({
    super.key,
    required this.child,
    this.startActions = const [],
    this.endActions = const [],
    this.slidableKey,
    this.enabled = true,
    this.borderRadius = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    // 关键：用 ClipRRect 把 Slidable 整体裁剪到圆角内，
    // 避免左右滑出的 ActionPane 按钮"飘"到卡片外（与非赛博的 ClipRRect 行为一致）。
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: appCornerBorder(radius: borderRadius),
      ),
      child: Slidable(
        key: slidableKey,
        enabled: enabled,
        startActionPane: _buildPane(context, startActions),
        endActionPane: _buildPane(context, endActions),
        child: child,
      ),
    );
  }

  ActionPane? _buildPane(BuildContext context, List<CyberSlideAction> actions) {
    if (actions.isEmpty) return null;

    final extentRatio = (actions.length * 0.18).clamp(0.2, 0.9);
    const buttonRadius = 12.0;
    // 按钮间距/上下留白 ≥ 外发光半径（blurRadius 5），
    // 避免发光超出 Slidable 裁剪区域被硬切（ClipRect(_SlidableClipper)）
    const buttonSpacing = 6.0;
    const verticalPadding = 6.0;

    return ActionPane(
      motion: const ScrollMotion(),
      extentRatio: extentRatio,
      children:
          actions
              .map(
                (action) => CustomSlidableAction(
                  onPressed: (ctx) async {
                    // 等收合动画完成再执行动作：确认弹窗/页面路由若在收合中
                    // 弹出会打断动画，卡片冻在「内容被推走+按钮条悬挂」的假死状态
                    await Slidable.of(ctx)?.close();
                    action.onTap();
                  },
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  borderRadius: BorderRadius.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: buttonSpacing / 2,
                    vertical: verticalPadding,
                  ),
                  child: Builder(
                    builder:
                        (buttonContext) => Container(
                          decoration: ShapeDecoration(
                            shape: appCornerBorder(
                              radius: buttonRadius,
                              side: BorderSide(
                                color: action.color.withValues(alpha: 0.7),
                                width: 0.5,
                              ),
                            ),
                            color: action.color,
                            shadows: [
                              BoxShadow(
                                color: action.color.withValues(alpha: 0.45),
                                blurRadius: 5,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                // 必须用 Slidable 子树内的 context 解析控制器：
                                // 内层 InkWell 手势竞争必胜外层 GestureDetector
                                // （autoClose 收合被跳过），而外层传入的 context
                                // 在 Slidable 之上，Slidable.of 恒为 null——
                                // ?.close() 静默空转，卡片冻在开启态（假死根源）
                                await Slidable.of(buttonContext)?.close();
                                action.onTap();
                              },
                              customBorder: appCornerBorder(
                                radius: buttonRadius,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      action.icon,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      action.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

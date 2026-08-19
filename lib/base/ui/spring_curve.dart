import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 快起步 + 末端轻过冲的弹簧曲线。
///
/// 用于中间 tab（环境变量/配置文件等）切换：
///  - 起步近似 [Curves.easeOutCubic]（快，跟手，不会像 2t² 那样慢启动发闷）
///  - 末端带约 4% 的轻微过冲再落回，保留"回弹缓冲"但不显得重
/// 底部导航与顶部 Tab 共用，避免重复实现。
class SpringCurve extends Curve {
  const SpringCurve();

  @override
  double transformInternal(double t) {
    // 快起步（跟手）
    final double base = Curves.easeOutCubic.transform(t);
    // 末端过冲脉冲：t∈[0.55, 0.95] 峰值 +0.04，回落到 0
    final double p = ((t - 0.55) / 0.4).clamp(0.0, 1.0);
    final double over = 0.04 * math.sin(math.pi * p);
    return base + over;
  }
}

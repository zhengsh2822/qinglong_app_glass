import 'package:flutter/material.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/ui/container_transform_route.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';

/// 顶部标题 / 空白区域 → 账号页的统一共享转场（主题版：无壁纸层）。
///
/// 这些区域没有卡片材质：容器以标题矩形为起点展开，底色为当前主题
/// scaffoldBackground。圆角使用 app 统一标准 [AppleColors.radiusCard]。
Future<void> pushAccountPageFromTitle({
  required BuildContext context,
  required Rect sourceRect,
  required Widget sourceChild,
}) {
  final ThemeData theme = Theme.of(context);
  return Navigator.of(context).push(
    ContainerTransformRoute(
      sourceRect: sourceRect,
      sourceChild: sourceChild,
      sourceRadius: AppleColors.radiusCard,
      sourceBlurSigma: 0,
      sourceHighlightOpacity: 0,
      sourceBorderColor: Colors.transparent,
      pageBackground: theme.scaffoldBackgroundColor,
      pageBuilder:
          (context, animation) => ChangeAccountPage(animation: animation),
    ),
  );
}

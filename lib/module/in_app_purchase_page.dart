import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/theme.dart';

class InAppPurchasePage extends ConsumerStatefulWidget {
  final bool fromDirectly;

  const InAppPurchasePage({Key? key, this.fromDirectly = false})
    : super(key: key);

  @override
  ConsumerState<InAppPurchasePage> createState() => _InAppPurchasePageState();
}

class _InAppPurchasePageState extends ConsumerState<InAppPurchasePage> {
  /// 全局字重（build 顶部统一 watch，供 helper 方法使用）
  FontWeight _globalFw = FontWeight.w400;

  @override
  Widget build(BuildContext context) {
    _globalFw = FontWeight(ref.watch(textWeightProvider));
    return Scaffold(
      appBar: QlAppBar(title: "APP功能介绍", canBack: true),
      body: SingleChildScrollView(
        primary: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection("核心特色", [
                "三种主题模式（赛博 / Apple / 白色），切换含全局颜色过渡动画",
                "底部液态玻璃导航栏 + 顶部大胶囊 Tab，双击回顶部",
                "胶囊高光卡片设计系统，统一 18px 圆角与毛玻璃视觉",
                "多账号同时登录，HTTP 缓存隔离防止跨账号数据泄漏",
                "仪表盘对齐 Web 端：7 日趋势图 / Top5 统计 / 实时运行态 / 系统资源",
                "完整支持任务、环境变量、配置、脚本、依赖、日志、订阅等基础操作",
              ], isAdvance: true),
              const SizedBox(height: 15),
              _buildSection("体验优化", [
                "全局字号 + 字重调节（400~700 四档）",
                "日志/详情页长按复制启用 iOS 风格文本选择放大镜",
                "脚本搜索：列表常驻过滤 + 编辑页弹出式搜索",
                "悬浮时钟、悬浮式沉浸搜索框",
              ], isAdvance: true),
              const SizedBox(height: 15),
              _buildSection("高级功能", [
                "Face ID / 指纹解锁 APP",
                "环境变量、配置、订阅等实时备份，最高可查历史 100 天",
                "支持远程上传文件、剪切板自动识别",
                "京东助手独立模块（独立登录 + Cookie 校验）",
                "环境变量拖拽排序、任务/依赖批量操作",
              ], isAdvance: true),
              const SizedBox(height: 15),
              _buildSection("性能与兼容", [
                "安卓小白条 + 状态栏沉浸适配（兼容澎湃 OS）",
                "毛玻璃效果可开关，纯色模式更省电",
                "Flutter 3.44.4 + Impeller 渲染，性能大幅提升",
              ], isAdvance: false),
              const SizedBox(height: 30),
              Center(
                child: Text(
                  "本应用不会收集任何关于您的信息，使用前请仔细阅读用户协议",
                  style: TextStyle(
                    color: ref.watch(themeProvider).themeColor.descColor(),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<String> items, {
    bool isAdvance = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: ref.watch(themeProvider).themeColor.titleColor(),
            fontSize: 18,
            fontWeight: _globalFw,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: BasicFuncWidget(title: item, advance: isAdvance),
          ),
        ),
      ],
    );
  }
}

class BasicFuncWidget extends ConsumerWidget {
  final String title;
  final bool advance;

  const BasicFuncWidget({Key? key, required this.title, this.advance = false})
    : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Image.asset(
            advance ? "assets/images/icon_b.png" : "assets/images/icon_a.png",
            fit: BoxFit.cover,
            width: 13,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: ref.watch(themeProvider).themeColor.descColor(),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

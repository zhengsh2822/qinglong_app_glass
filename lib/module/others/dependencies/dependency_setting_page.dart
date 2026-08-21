import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/app_colors.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/glass_text_field.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/ui/other_page_card.dart';
import 'package:qinglong_app/utils/extension.dart';

/// 依赖设置页面（青龙面板 v2.21+ 系统设置 → 依赖设置）
///
/// 配置依赖代理 + Node/Python/Linux 镜像源，解决依赖安装慢/失败的问题。
/// 4 个输入框：
/// - 依赖代理（http_proxy/https_proxy）
/// - Node.js 镜像源（pnpm config set registry）
/// - Python 镜像源（pip3 config set global.index-url）
/// - Linux 镜像源（仅 Linux 平台）
///
/// 传空字符串保存表示清除设置。
/// Node/Linux 镜像源更新会触发重装已安装依赖，耗时较长，用 Loading 遮罩提示。
class DependencySettingPage extends ConsumerStatefulWidget {
  const DependencySettingPage({super.key});

  @override
  ConsumerState<DependencySettingPage> createState() =>
      _DependencySettingPageState();
}

class _DependencySettingPageState extends ConsumerState<DependencySettingPage> {
  final _proxyController = TextEditingController();
  final _nodeController = TextEditingController();
  final _pythonController = TextEditingController();
  final _linuxController = TextEditingController();

  /// 服务器端当前值，用于对比是否变化，避免发送无效请求
  String _origProxy = '';
  String _origNode = '';
  String _origPython = '';
  String _origLinux = '';

  bool _loading = true;
  bool _saving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _nodeController.dispose();
    _pythonController.dispose();
    _linuxController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final api = SingleAccountPageState.ofApi(context);
    final response = await api.systemConfig();

    if (!mounted) return;

    if (response.success && response.bean != null) {
      try {
        final decoded = jsonDecode(response.bean!);
        // 青龙 API 返回结构：{code:200, data:{id, type, info:{dependenceProxy, nodeMirror, ...}}}
        // response.bean 是 data 字段的 JSON 字符串，即 {id, type, info:{...}}
        final data = decoded is Map ? decoded['data'] ?? decoded : decoded;
        if (data is Map) {
          // 依赖设置字段在 info 对象下
          final info = data['info'];
          final cfg = info is Map ? info : data;
          _proxyController.text = cfg['dependenceProxy']?.toString() ?? '';
          _nodeController.text = cfg['nodeMirror']?.toString() ?? '';
          _pythonController.text = cfg['pythonMirror']?.toString() ?? '';
          _linuxController.text = cfg['linuxMirror']?.toString() ?? '';
          // 保存原始值，用于保存时对比是否变化
          _origProxy = _proxyController.text;
          _origNode = _nodeController.text;
          _origPython = _pythonController.text;
          _origLinux = _linuxController.text;
        }
        setState(() => _loading = false);
      } catch (e) {
        setState(() {
          _loading = false;
          _errorMsg = '解析配置失败: $e';
        });
      }
    } else {
      setState(() {
        _loading = false;
        _errorMsg = response.message?.isNotEmpty == true
            ? response.message
            : '当前版本不支持依赖设置，请将青龙更新到 v2.21+';
      });
    }
  }

  Future<void> _saveAll() async {
    if (_saving) return;
    setState(() => _saving = true);

    final api = SingleAccountPageState.ofApi(context);

    // 只发送变化的字段，避免发送无效请求（如代理地址为空时服务器 rm 不存在的文件会 500）
    final newProxy = _proxyController.text.trim();
    final newPython = _pythonController.text.trim();
    final newNode = _nodeController.text.trim();
    final newLinux = _linuxController.text.trim();

    final labels = <String>[];
    final fns = <Future<HttpResponse<String>> Function()>[];

    if (newProxy != _origProxy) {
      labels.add('依赖代理');
      fns.add(() => api.updateDependenceProxy(newProxy));
    }
    if (newPython != _origPython) {
      labels.add('Python镜像源');
      fns.add(() => api.updatePythonMirror(newPython));
    }
    if (newNode != _origNode) {
      labels.add('Node镜像源');
      fns.add(() => api.updateNodeMirror(newNode));
    }
    if (newLinux != _origLinux) {
      labels.add('Linux镜像源');
      fns.add(() => api.updateLinuxMirror(newLinux));
    }

    // 无任何变化
    if (labels.isEmpty) {
      setState(() => _saving = false);
      '配置未变化'.toast();
      return;
    }

    final results = <HttpResponse<String>>[];
    final detailLines = <String>[];

    // needRelogin（token 失效 / 网络异常）时，Http 层已重建 Dio + 静默刷新 + 重试一次
    // 重试仍失败会触发 exitLogin() 弹窗，此时后续字段继续请求也会失败，应提前终止
    bool abortDueToRelogin = false;

    for (int i = 0; i < fns.length; i++) {
      final label = labels[i];
      detailLines.add('▶ $label');
      try {
        final r = await fns[i]();
        results.add(r);
        if (r.success) {
          detailLines.add('  ✓ 成功');
        } else {
          final raw = r.message?.isNotEmpty == true ? r.message : 'code=${r.code}';
          detailLines.add('  ✗ 失败: $raw');
          // needRelogin 表示 token 失效或网络异常，后续请求也会失败，终止循环
          if (r.needRelogin) {
            abortDueToRelogin = true;
            detailLines.add('  ⚠ 登录已过期或网络异常，已终止后续保存');
            break;
          }
        }
      } catch (e) {
        detailLines.add('  ✗ 异常: $e');
        results.add(HttpResponse<String>(success: false, code: -9999, message: e.toString()));
      }
      detailLines.add('');
    }

    if (!mounted) return;

    final allSuccess = results.isNotEmpty && results.every((r) => r.success);
    setState(() => _saving = false);

    // 部分成功时，更新已成功字段的 _origXxx，避免下次重复发送
    // 通过 labels 和 results 的对应关系判断哪些字段成功
    if (results.isNotEmpty) {
      for (int i = 0; i < results.length && i < labels.length; i++) {
        if (!results[i].success) continue;
        switch (labels[i]) {
          case '依赖代理':
            _origProxy = newProxy;
            break;
          case 'Python镜像源':
            _origPython = newPython;
            break;
          case 'Node镜像源':
            _origNode = newNode;
            break;
          case 'Linux镜像源':
            _origLinux = newLinux;
            break;
        }
      }
    }

    if (allSuccess) {
      final hasMirror = newNode.isNotEmpty || newLinux.isNotEmpty;
      if (hasMirror) {
        '依赖设置已保存，镜像源更新后将在后台重装依赖'.toast();
      } else {
        '依赖设置已保存'.toast();
      }
    } else if (abortDueToRelogin) {
      // needRelogin 失败：Http 层已触发 exitLogin() 弹窗（"连接失败，是否重新登录？"）
      // 不再重复弹窗，仅 toast 提示
      final detail = detailLines.join('\n');
      debugPrint('[DependencySetting] 保存中断（登录/网络异常）:\n$detail');
      '登录已过期或网络异常，请重试'.toast();
    } else {
      final detail = detailLines.join('\n');
      debugPrint('[DependencySetting] 保存失败:\n$detail');
      await Clipboard.setData(ClipboardData(text: detail));
      if (!mounted) return;
      final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isCyber ? CyberColors.bg : AppleColors.bgSecondary,
          title: Text('保存失败', style: TextStyle(color: ref.read(themeProvider).themeColor.titleColor())),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                detail,
                style: TextStyle(color: ref.read(themeProvider).themeColor.descColor(), fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('关闭', style: TextStyle(color: ref.read(themeProvider).primaryColor)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeProvider);

    // 根据主题模式动态选择颜色
    final Color titleColor = ref.read(themeProvider).themeColor.titleColor();
    final Color subtitleColor = ref.read(themeProvider).themeColor.descColor();
    final Color accentColor = ref.watch(themeProvider).primaryColor;

    Widget body;
    if (_loading) {
      body = Center(
        child: LoadingWidget(
          color: accentColor,
          size: 30,
        ),
      );
    } else if (_errorMsg != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                color: accentColor.withOpacity(0.15),
                onPressed: _loadConfig,
                child: Text(
                  '重试',
                  style: TextStyle(color: accentColor, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppleColors.spaceMd,
          right: AppleColors.spaceMd,
          top: AppleColors.spaceMd,
          bottom: MediaQuery.of(context).viewPadding.bottom + 30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: '依赖代理',
              subtitle: 'http_proxy / https_proxy，用于代理安装依赖',
              hint: '例如 http://127.0.0.1:7890',
              controller: _proxyController,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              inputColor: titleColor,
            ),
            const SizedBox(height: AppleColors.spaceMd),
            _buildSection(
              title: 'Node.js 镜像源',
              subtitle: 'pnpm config set registry，更新后会重装已安装的 nodejs 依赖',
              hint: '例如 https://registry.npmmirror.com',
              controller: _nodeController,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              inputColor: titleColor,
            ),
            const SizedBox(height: AppleColors.spaceMd),
            _buildSection(
              title: 'Python 镜像源',
              subtitle: 'pip3 config set global.index-url',
              hint: '例如 https://mirrors.aliyun.com/pypi/simple/',
              controller: _pythonController,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              inputColor: titleColor,
            ),
            const SizedBox(height: AppleColors.spaceMd),
            _buildSection(
              title: 'Linux 镜像源',
              subtitle: '仅 Linux 平台生效',
              hint: '例如 https://mirrors.aliyun.com',
              controller: _linuxController,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              inputColor: titleColor,
            ),
            const SizedBox(height: 30),
            _buildSaveButton(accentColor),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: QlAppBar(
            title: '依赖设置',
            canBack: true,
          ),
          body: body,
        ),
        if (_saving)
          Positioned.fill(
            child: AbsorbPointer(
              child: Center(
                child: LoadingWidget(
                  color: accentColor,
                  size: 30,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required String hint,
    required TextEditingController controller,
    required Color titleColor,
    required Color subtitleColor,
    required Color inputColor,
  }) {
    return OtherPageCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: controller,
            hintText: hint,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              color: inputColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(Color accentColor) {
    return SizedBox(
      width: double.infinity,
      child: OtherPageCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        onTap: _saving ? null : _saveAll,
        child: Center(
          child: Text(
            '保存',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

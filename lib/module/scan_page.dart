import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/base/ui/radar_scan_view.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_bean.dart';
import 'package:qinglong_app/module/task/TaskBean2.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../main.dart';
import '../base/http/http.dart';
import '../base/ui/button.dart';
import '../base/ui/settings_widgets.dart';
import '../base/ui/tree/models/script_data.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ScanPage> createState() => ScanPageState();
}

class ScanPageState extends ConsumerState<ScanPage> {
  bool scaning = false;
  // 雷达进度：_totalCount 需扫描的总文件数，_currentIndex 已扫描数
  int _totalCount = 0;
  int _currentIndex = 0;

  // 只扫描定时任务引用的脚本（默认开启），跳过未被任何定时任务引用的脚本
  bool _onlyTaskScripts = true;

  var textProvider = StateProvider<String>((ref) => "");

  @override
  Widget build(BuildContext context) {
    final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
    final Widget scaffold = Scaffold(
      backgroundColor: isCyber ? Colors.transparent : null,
      appBar: QlAppBar(
        title: "扫描缺失的依赖",
        backCall: () {
          if (!scaning) {
            Navigator.of(context).pop();
          } else {
            if (isCyber) {
              showCyberConfirmDialog(
                context,
                title: '温馨提示',
                content: '当前正在扫描文件,确定退出吗?',
                danger: true,
              ).then((confirmed) {
                if (confirmed == true) {
                  Navigator.of(context).pop();
                }
              });
              return;
            }
            showCupertinoDialog(
              context: context,
              useRootNavigator: false,
              builder:
                  (childContext) => CupertinoAlertDialog(
                    title: const Text("温馨提示"),
                    content: const Text("当前正在扫描文件,确定退出吗?"),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text(
                          "取消",
                          style: TextStyle(color: Color(0xff999999)),
                        ),
                        onPressed: () {
                          Navigator.of(childContext).pop();
                        },
                      ),
                      CupertinoDialogAction(
                        child: Text(
                          "确定",
                          style: TextStyle(
                            color: ref.watch(themeProvider).primaryColor,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(childContext).pop();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
            );
          }
        },
      ),
      body: scanWidget(),
    );
    return isCyber ? CyberBackground(child: scaffold) : scaffold;
  }

  void _startScan() async {
    try {
      List<String> jsInstalled = [];
      List<String> pyInstalled = [];
      Api api = Api(SingleAccountPageState.of(context)?.index ?? 0);

      // 获取脚本目录树
      HttpResponse<List<ScriptData>> scriptResponse =
          await SingleAccountPageState.ofApi(context).scripts();
      if (!scriptResponse.success || scriptResponse.bean == null) {
        scaning = false;
        setState(() {});
        "获取脚本列表失败".toast();
        return;
      }
      List<ScriptData> scripts = scriptResponse.bean!;

      // 若开启"只扫定时任务脚本"，则按 task 命令的脚本路径过滤掉未被任务引用的脚本
      if (_onlyTaskScripts) {
        Set<String> taskScriptPaths = await _fetchTaskScriptPaths(api);
        if (taskScriptPaths.isNotEmpty) {
          int before = _countScriptFiles(scripts);
          _filterUntrackedScripts(scripts, taskScriptPaths);
          scripts.removeWhere(
            (element) => element.title == "node_modules" ||
                element.title == "__pycache__" ||
                element.title == ".git" ||
                element.title.endsWith(".pyc"),
          );
          int after = _countScriptFiles(scripts);
          // 兜底：task command 路径与 ScriptData.key 形态不一致（如 ql repo 拉取的仓库）
          // 会导致过滤后仍有大量脚本被扫描，此时打印提示并保留全量扫，避免漏扫
          if (after == before) {
            logger.w(
              "扫描过滤未匹配到任何脚本：定时任务 command 路径与 ScriptData.key 不一致，回退为全量扫描",
            );
          }
        } else {
          logger.w("未找到任何定时任务脚本，回退为全量扫描");
        }
      }

      // 先统计脚本源码总文件数，作为雷达进度总数
      _totalCount = _countScriptFiles(scripts);
      _currentIndex = 0;
      if (mounted) setState(() {});

      // 递归扫描所有脚本源码，提取并自动安装缺失依赖
      await _scanScripts(scripts, "", api, jsInstalled, pyInstalled);

      // 扫描完成：进度条收尾到 100%
      _currentIndex = _totalCount;
      if (mounted) setState(() {});
      scaning = false;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (jsInstalled.isNotEmpty || pyInstalled.isNotEmpty) {
          final bool isCyber = ref.read(themeProvider).themeMode == modeCyber;
          String content =
              'NodeJS:\n ${jsInstalled.join("\n").toString()} \n Python3:\n ${pyInstalled.join("\n").toString()}';
          if (isCyber) {
            showCyberConfirmDialog(
              context,
              title: '本次已安装如下依赖',
              content: content,
              confirmLabel: '知道了',
            );
            return;
          }
          showCupertinoDialog(
            context: context,
            useRootNavigator: false,
            builder:
                (childContext) => CupertinoAlertDialog(
                  title: const Text("本次已安装如下依赖"),
                  content: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(childContext).size.height * 0.4,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        content,
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  actions: [
                    CupertinoDialogAction(
                      child: Text(
                        "知道了",
                        style: TextStyle(
                          color: ref.watch(themeProvider).primaryColor,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(childContext).pop();
                      },
                    ),
                  ],
                ),
          );
        } else {
          "暂未发现缺失的依赖".toast();
        }
      });
      setState(() {});
    } catch (e) {
      scaning = false;
      _totalCount = 0;
      _currentIndex = 0;
      setState(() {});
      "扫描失败: $e".toast();
    }
  }

  /// 统计脚本树中需要扫描的脚本源码文件总数（.js/.ts/.py）
  int _countScriptFiles(List<ScriptData> scripts) {
    int count = 0;
    for (var script in scripts) {
      if (script.type == "directory") {
        count += _countScriptFiles(script.children);
      } else if (_isScriptFile(script.title)) {
        count++;
      }
    }
    return count;
  }

  /// 是否为可扫描的脚本源码文件
  static bool _isScriptFile(String name) {
    return name.endsWith(".js") ||
        name.endsWith(".ts") ||
        name.endsWith(".py");
  }

  /// 递归历遍脚本树，读取脚本源码并提取/安装缺失依赖
  Future<void> _scanScripts(
    List<ScriptData> scripts,
    String path,
    Api api,
    List<String> jsInstalled,
    List<String> pyInstalled,
  ) async {
    for (var script in scripts) {
      if (scaning == false) break;
      if (script.type == "directory") {
        // 目录的 path 用 title 拼接（与 ScriptData.key 形式一致）
        String childPath = path.isEmpty ? script.title : "$path/${script.title}";
        await _scanScripts(
          script.children,
          childPath,
          api,
          jsInstalled,
          pyInstalled,
        );
      } else if (_isScriptFile(script.title)) {
        _currentIndex++;
        _updateDescText("正在扫描: ${script.title} ($_currentIndex/$_totalCount)");
        if (mounted) setState(() {});

        // 短间隔避免对 keep-alive 连接造成持续压力，减少死连接概率
        await Future.delayed(const Duration(milliseconds: 100));

        // 读取脚本源码内容：scriptDetail 接受父目录 path + 文件名 title
        HttpResponse<String> response =
            await SingleAccountPageState.ofApi(
              context,
            ).scriptDetail(script.title, path);
        if (response.success &&
            response.bean != null &&
            response.bean!.isNotEmpty) {
          String content = response.bean!;
          bool isPy = script.title.endsWith(".py");
          // 提取脚本源码中 require/import 的依赖，并比对自动安装缺失项
          List<String> deps = extractScriptDeps(content, isPy);
          for (String dep in deps) {
            if (dep.isEmpty) continue;
            var installed = await autoInstallFounded(api, dep, isPy);
            if (installed == true) {
              if (isPy) {
                if (!pyInstalled.contains(dep)) pyInstalled.add(dep);
              } else {
                if (!jsInstalled.contains(dep)) jsInstalled.add(dep);
              }
            }
          }
        }
      }
    }
  }

  /// 从定时任务列表提取被引用的脚本路径集合（归一化为不含扩展名的路径）
  ///
  /// 青龙定时任务 command 形如：
  ///   "task 目录/脚本.js"
  ///   "task 目录/脚本.py"
  /// ql repo / ql raw 等非脚本执行类命令直接跳过。
  /// 路径去扩展名、归一化正斜杠，与 ScriptData.key 去除扩展名后做严格匹配。
  ///
  /// 接口选择：v2.13.9+ 使用 crons2_13_09()（带 page/size=10000，能拉完全部任务）；
  /// 旧版用 crons()（默认分页，task 数 > size 时会漏，导致扫描脚本数与定时任务数对不上）
  Future<Set<String>> _fetchTaskScriptPaths(Api api) async {
    Set<String> paths = {};
    try {
      final index = SingleAccountPageState.of(context)?.index ?? 0;
      final systemBean = getIt<SystemBean>(instanceName: index.toString());
      List<TaskBean> tasks = [];

      if (systemBean.isUpperVersion2_13_9()) {
        HttpResponse<TaskBean2> resp = await api.crons2_13_09();
        if (resp.success && resp.bean != null) {
          tasks = resp.bean!.data ?? [];
        }
      } else {
        HttpResponse<List<TaskBean>> resp = await api.crons();
        if (resp.success && resp.bean != null) {
          tasks = resp.bean!;
        }
      }

      for (TaskBean task in tasks) {
        String? command = task.command;
        if (command == null) continue;
        String trimmed = command.trim();
        // 跳过非脚本执行类命令（ql repo / ql raw 等）
        if (!trimmed.startsWith("task ")) continue;
        String rel = trimmed.substring(5).trim();
        if (rel.isEmpty) continue;
        // 命令可能带附加参数（少见），只取首个空白分隔片段
        String first = rel.split(RegExp(r'\s+')).first;
        if (!_isScriptFile(first)) continue;
        // 归一化路径：去 ./、反斜杠转斜杠、去扩展名
        String norm = first
            .replaceAll("./", "")
            .replaceAll(r"\", "/")
            .replaceFirst(RegExp(r'\.(js|ts|py)$', caseSensitive: false), '');
        if (norm.isNotEmpty) paths.add(norm);
      }
    } catch (e) {
      logger.e(e);
    }
    return paths;
  }

  /// 递归移除未被任何定时任务引用的脚本（含空目录）
  ///
  /// [taskScriptPaths] 为归一化后的脚本相对路径集合（不含扩展名）。
  /// 优先用 ScriptData.key 作为完整路径（新接口 v2.13+ 可能填充），
  /// 若 key 为空则通过父目录 path 拼接 title 构造完整路径（兼容旧接口）。
  void _filterUntrackedScripts(
    List<ScriptData> scripts,
    Set<String> taskScriptPaths, [
    String parentPath = "",
  ]) {
    scripts.removeWhere((script) {
      if (script.type == "directory") {
        String childPath = parentPath.isEmpty
            ? script.title
            : "$parentPath/${script.title}";
        _filterUntrackedScripts(script.children, taskScriptPaths, childPath);
        // 目录里已无有效脚本则整目录移除
        return script.children.isEmpty;
      }
      // 拿到脚本的完整相对路径：
      // 1) 优先用 script.key（新接口填充的完整路径，如 "jd/rankVote.js"）
      // 2) 退而用 parentPath + title 拼接（兼容旧接口，key 为空时）
      String fullPath = script.key.isNotEmpty
          ? script.key
          : (parentPath.isEmpty
                ? script.title
                : "$parentPath/${script.title}");
      String norm = fullPath.replaceFirst(
        RegExp(r'\.(js|ts|py)$', caseSensitive: false),
        '',
      );
      return !taskScriptPaths.contains(norm);
    });
  }

  /// 从脚本源码中提取 require/import 的依赖包名（nodejs/js 与 python 两套规则）
  static List<String> extractScriptDeps(String content, bool isPy) {
    List<String> result = [];
    Set<String> seen = {};
    if (isPy) {
      // Python: import xxx / import xxx as yyy / from xxx import ...
      RegExp reg = RegExp(
        r'^\s*(?:import|from)\s+([a-zA-Z_][a-zA-Z0-9_]*)',
        multiLine: true,
      );
      for (var match in reg.allMatches(content)) {
        String dep = match.group(1)!;
        if (!_isValidDepName(dep)) continue;
        if (seen.add(dep)) result.add(dep);
      }
    } else {
      // NodeJS/TS: require('x') / import ... from 'x' / import 'x'
      RegExp reg = RegExp(
        r'''require\s*\(\s*["']([^"'/][^"']*?)["']\s*\)|from\s+["']([^"'/][^"']*?)["']''',
      );
      for (var match in reg.allMatches(content)) {
        String? dep = match.group(1) ?? match.group(2);
        if (dep != null && dep.isNotEmpty && _isValidDepName(dep)) {
          if (seen.add(dep)) {
            result.add(dep);
          }
        }
      }
    }
    return result;
  }

  /// 校验是否为合法的依赖包名，过滤脚本源码中被转义/加密的乱码串
  ///
  /// 正常 npm/pip 包名仅由字母、数字、下划线、短横线、点号组成，
  /// 排除含反斜杠转义（\x../\u.. 等十六进制/unicode 转义）或其它乱码特征的结果。
  /// 示例非法项：\x67\x6f\x74、\x66\x73、\u002e\u002f 等。
  static bool _isValidDepName(String name) {
    if (name.isEmpty) return false;
    // 含反斜杠转义（\x / \u / \b 等）即为被转义字符串，非真实包名
    if (name.contains(r'\')) return false;
    // 首字符必须为字母或下划线（npm 包名无法用数字开头）
    if (!RegExp(r'^[a-zA-Z_]').hasMatch(name)) return false;
    // 包名主体只允许字母/数字/下划线/短横线/点号
    if (!RegExp(r'^[a-zA-Z0-9_\-\.]+$').hasMatch(name)) return false;
    // 连续转义类字符（乱码特征）排除
    if (RegExp(r'[0-9a-fA-F]{2,}(?=[a-zA-Z])').hasMatch(name) &&
        !RegExp(r'^[a-zA-Z]').hasMatch(name)) {
      return false;
    }
    return true;
  }

  Widget scanWidget() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom -
              kToolbarHeight,
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              _buildRadarView(),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: Consumer(
                  builder: (context, ref, _) {
                    String text = ref.watch(textProvider);
                    return Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontSize: 12,
                        color: ref.watch(themeProvider).themeColor.descColor(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SettingsSwitchRow(
                  title: "只扫描定时任务的脚本",
                  value: _onlyTaskScripts,
                  onChanged: (v) {
                    if (scaning) return;
                    setState(() => _onlyTaskScripts = v);
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: ButtonWidget(
                  title: !scaning ? "开始扫描" : "停止扫描",
                  onTap: () {
                    if (scaning == true) {
                      scaning = false;
                      setState(() {});
                      ref.read(textProvider.notifier).state = "";
                    } else {
                      scaning = true;
                      _totalCount = 0;
                      _currentIndex = 0;
                      setState(() {});
                      _startScan();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 雷达扫描视图：外圈进度环 + 内圈旋转扫描，实时跟随扫描进度
  Widget _buildRadarView() {
    final theme = ref.watch(themeProvider);
    final primaryColor = theme.primaryColor;
    final descColor = theme.themeColor.descColor();
    final progress = _totalCount == 0 ? 0.0 : _currentIndex / _totalCount;
    final radarSize = MediaQuery.of(context).size.width * 0.62;

    // 严格区分：未扫描 / 准备中（已点开始但还在等网络）/ 扫描中 / 扫描完成
    String percentText;
    String bottomText;
    if (scaning) {
      if (_totalCount == 0) {
        percentText = '';
        bottomText = '准备中...';
      } else {
        percentText = '${(progress * 100).toStringAsFixed(0)}%';
        bottomText = '$_currentIndex / $_totalCount';
      }
    } else if (_totalCount > 0) {
      percentText = '100%';
      bottomText = '扫描完成';
    } else {
      percentText = '0%';
      bottomText = '准备就绪';
    }

    return RadarScanView(
      size: radarSize,
      progress: progress,
      primaryColor: primaryColor,
      descColor: descColor,
      percentText: percentText,
      bottomText: bottomText,
    );
  }

  void _updateDescText(String s) {
    ref.read(textProvider.notifier).state = s;
  }

  static Future<bool> autoInstallFounded(
    Api api,
    String found,
    bool isPython,
  ) async {
    if (found.contains(".") || found.contains("/")) return false;
    if (isPython) {
      List<DependencyBean> pyList = [];
      var pyDep = await api.dependencies("python3");
      if (pyDep.success) {
        pyList.addAll(pyDep.bean ?? []);
      }
      DependencyBean bean = pyList.firstWhere(
        (element) => element.name == found,
        orElse: () => DependencyBean(),
      );
      if (bean.name == null || bean.name!.isEmpty) {
        await api.addDependency([
          {"name": found, "type": 1},
        ]);
        return true;
      }
    } else {
      var jsDep = await api.dependencies("nodejs");
      List<DependencyBean> jsList = [];

      if (jsDep.success) {
        jsList.addAll(jsDep.bean ?? []);
      }
      DependencyBean bean = jsList.firstWhere(
        (element) => element.name == found,
        orElse: () => DependencyBean(),
      );

      if (bean.name == null || bean.name!.isEmpty) {
        await api.addDependency([
          {"name": found, "type": 0},
        ]);
        return true;
      }
    }
    return false;
  }

  /// 同时搜索 NodeJS 和 Python 缺失依赖错误，返回所有找到的依赖名
  static List<String> foundAllReg(String text) {
    if (text.isEmpty) return [];

    List<String> results = [];
    Set<String> seen = {}; // 去重

    // NodeJS: Cannot find module 'xxx' / "xxx"
    for (final pattern in [
      RegExp(r"Cannot find module '([^']+)'"),
      RegExp(r'Cannot find module "([^"]+)"'),
    ]) {
      for (final match in pattern.allMatches(text)) {
        String? dep = match.group(1);
        if (dep != null && dep.isNotEmpty && !dep.contains(".") && !dep.contains("/")) {
          if (seen.add(dep)) results.add(dep);
        }
      }
    }

    // Python: No module named 'xxx' / "xxx"
    for (final pattern in [
      RegExp(r"No module named '([^']+)'"),
      RegExp(r'No module named "([^"]+)"'),
    ]) {
      for (final match in pattern.allMatches(text)) {
        String? dep = match.group(1);
        if (dep != null && dep.isNotEmpty && !dep.contains(".") && !dep.contains("/")) {
          if (seen.add(dep)) results.add(dep);
        }
      }
    }

    return results;
  }
}

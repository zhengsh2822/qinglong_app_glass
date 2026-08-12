import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_background.dart';
import 'package:qinglong_app/base/ui/cyber/cyber_dialog.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_bean.dart';
import 'package:qinglong_app/module/others/task_log/task_log_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';

import '../base/http/http.dart';
import '../base/ui/button.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ScanPage> createState() => ScanPageState();
}

class ScanPageState extends ConsumerState<ScanPage> {
  bool scaning = false;

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

      // 获取已安装依赖列表
      List<DependencyBean> jsList = [];
      List<DependencyBean> pyList = [];
      var jsDep = await api.dependencies("nodejs");
      if (jsDep.success) {
        jsList.addAll(jsDep.bean ?? []);
      }
      var pyDep = await api.dependencies("python3");
      if (pyDep.success) {
        pyList.addAll(pyDep.bean ?? []);
      }

      // 改用历史日志扫描：获取日志文件列表，读取每个日志文件内容
      // 原来用 inTimeLog 只能获取正在运行任务的实时日志，任务没运行时返回空
      HttpResponse<List<TaskLogBean>> logResponse =
          await SingleAccountPageState.ofApi(context).taskLog();

      if (!logResponse.success || logResponse.bean == null) {
        scaning = false;
        setState(() {});
        "获取日志列表失败".toast();
        return;
      }

      List<TaskLogBean> logList = logResponse.bean!;
      int totalFiles = 0;
      int scannedFiles = 0;

      // 先统计总文件数
      for (TaskLogBean dir in logList) {
        if (dir.files != null) {
          // 每个目录只扫描最新2个日志文件，避免扫描过多
          totalFiles += dir.files!.length > 2 ? 2 : dir.files!.length;
        }
        if (dir.children != null) {
          totalFiles += dir.children!.length > 2 ? 2 : dir.children!.length;
        }
      }

      for (TaskLogBean dir in logList) {
        if (scaning == false) break;

        // 收集该目录下的日志文件名
        List<String> fileNames = [];
        if (dir.files != null && dir.files!.isNotEmpty) {
          // files 按时间倒序，只取最新2个
          for (int i = dir.files!.length - 1;
              i >= 0 && fileNames.length < 2;
              i--) {
            fileNames.add(dir.files![i]);
          }
        }
        if (dir.children != null && dir.children!.isNotEmpty) {
          for (int i = dir.children!.length - 1;
              i >= 0 && fileNames.length < 2;
              i--) {
            if (dir.children![i].title != null) {
              fileNames.add(dir.children![i].title!);
            }
          }
        }

        String dirName = dir.name ?? "";

        for (String fileName in fileNames) {
          if (scaning == false) break;
          scannedFiles++;
          _updateDescText("正在扫描: $fileName ($scannedFiles/$totalFiles)");

          HttpResponse<String> response = await SingleAccountPageState.ofApi(
            context,
          ).taskLogDetail(fileName, dirName);

          if (response.success &&
              response.bean != null &&
              response.bean!.isNotEmpty) {
            String text = response.bean ?? "";
            // 同时搜索 nodejs 和 python 缺失依赖错误
            List<String> foundDeps = foundAllReg(text);
            for (String found in foundDeps) {
              if (found.isEmpty) continue;
              bool isPy = _isPythonDependency(text, found);
              var result = await autoInstallFounded(api, found, isPy);
              if (result == true) {
                if (isPy) {
                  if (!pyInstalled.contains(found)) pyInstalled.add(found);
                } else {
                  if (!jsInstalled.contains(found)) jsInstalled.add(found);
                }
              }
            }
          }
        }
      }

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
                  content: Text(content),
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
      setState(() {});
      "扫描失败: $e".toast();
    }
  }

  /// 判断日志文本中找到的缺失依赖是 Python 还是 NodeJS
  static bool _isPythonDependency(String text, String depName) {
    // 通过上下文判断：如果 depName 附近有 "No module named"，则是 Python
    int idx = text.indexOf(depName);
    if (idx >= 0) {
      int start = idx > 100 ? idx - 100 : 0;
      String context = text.substring(start, idx + depName.length + 50);
      if (context.contains("No module named")) return true;
      if (context.contains("Cannot find module")) return false;
    }
    // 默认按名称特征判断：Python 模块通常不含大写字母
    return false;
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
              Icon(
                CupertinoIcons.doc_text_search,
                size: MediaQuery.of(context).size.width * 0.5,
                color: ref.watch(themeProvider).primaryColor,
              ),
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

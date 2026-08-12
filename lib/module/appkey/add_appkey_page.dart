import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/module/appkey/appkey_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../base/commit_button.dart';
import '../../base/ql_app_bar.dart';
import '../../base/single_account_page.dart';
import '../../base/ui/selectable_chip.dart';
import '../subscribe/add_subscribe_page.dart';



class AddAppKeyPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> bean;

  const AddAppKeyPage({
    Key? key,
    required this.bean,
  }) : super(key: key);

  @override
  ConsumerState<AddAppKeyPage> createState() => _AddAppKeyPageState();
}

class _AddAppKeyPageState extends ConsumerState<AddAppKeyPage> {
  final TextEditingController _nameController = TextEditingController();

  /// 全部可选权限（与青龙面板 scopes 对应）
  static const List<String> _allPermissions = [
    '定时任务',
    '环境变量',
    '配置文件',
    '脚本管理',
    '任务日志',
    '依赖管理',
    '系统信息',
  ];

  List<String> selectedPermissions = ["定时任务"];

  @override
  void initState() {
    if (widget.bean.isNotEmpty) {
      _nameController.text = widget.bean["name"] ?? "";

      selectedPermissions.clear();
      selectedPermissions
          .addAll(AppKeyViewModel.getScopeNames(widget.bean["scopes"]));
    }

    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: QlAppBar(
        canBack: true,
        actions: [
          CommitButton(
            onTap: () {
              commit();
            },
          ),
        ],
        title: "新增应用",
      ),
      body: SingleChildScrollView(
        primary: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  const TitleWidget(
                    "名称",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  TextField(
                    controller: _nameController,
                    maxLines: 3,
                    minLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      hintText: "请输入名称",
                    ),
                    autofocus: false,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  const TitleWidget(
                    "权限",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Wrap(
                    runSpacing: 8,
                    spacing: 8,
                    children: _allPermissions.map((e) {
                      final selected = selectedPermissions.contains(e);
                      return SelectableChip(
                        label: e,
                        selected: selected,
                        onToggle: (value) {
                          setState(() {
                            if (value) {
                              selectedPermissions.add(e);
                            } else {
                              selectedPermissions.remove(e);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void commit() async {
    if (_nameController.text.isEmpty) {
      "请输入名称".toast();
      return;
    }

    if (selectedPermissions.isEmpty) {
      "请选择权限".toast();
      return;
    }

    EasyLoading.show(status: "提交中");

    HttpResponse<NullResponse> response;

    Map<String, dynamic> data = {
      "name": _nameController.getTextOrDefault(),
      "scopes": AppKeyViewModel.getScopeKeys(selectedPermissions),
    };
    if (widget.bean.containsKey("_id") || widget.bean.containsKey("id")) {
      if (widget.bean.containsKey("_id")) {
        data["_id"] = widget.bean["_id"];
      } else {
        data["id"] = widget.bean["id"];
      }

      response = await SingleAccountPageState.ofApi(context).updateAppKey(data);
    } else {
      response = await SingleAccountPageState.ofApi(context).addAppKey(data);
    }
    EasyLoading.dismiss();

    if (response.success) {
      Navigator.of(context).pop(true);
    } else {
      response.message?.toast();
    }
  }
}

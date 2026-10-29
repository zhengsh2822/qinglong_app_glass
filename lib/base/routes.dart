import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qinglong_app/module/config/config_detail_page.dart';
import 'package:qinglong_app/module/config/config_edit_page.dart';
import 'package:qinglong_app/module/dashboard/dashboard_page.dart';
import 'package:qinglong_app/module/dashboard/dashboard_task_result_page.dart';
import 'package:qinglong_app/module/env/add_env_page.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/module/env/env_detail_page.dart';
import 'package:qinglong_app/module/home/home_page.dart';
import 'package:qinglong_app/module/icloud/icloud_file_page.dart';
import 'package:qinglong_app/module/icloud/icloud_page.dart';
import 'package:qinglong_app/module/login/login_page.dart';
import 'package:qinglong_app/module/others/about_page.dart';
import 'package:qinglong_app/module/others/change_account_page.dart';
import 'package:qinglong_app/module/others/dependencies/add_dependency_page.dart';
import 'package:qinglong_app/module/others/dependencies/dependency_page.dart';
import 'package:qinglong_app/module/others/login_log/login_log_page.dart';
import 'package:qinglong_app/module/others/notify_log/notify_log_page.dart';
import 'package:qinglong_app/module/others/scripts/script_add_page.dart';
import 'package:qinglong_app/module/others/scripts/script_detail_page.dart';
import 'package:qinglong_app/module/others/scripts/script_edit_page.dart';
import 'package:qinglong_app/module/others/scripts/script_page.dart';
import 'package:qinglong_app/module/others/task_log/task_log_page.dart';
import 'package:qinglong_app/module/others/jdck/jdck_page.dart';
import 'package:qinglong_app/module/others/update_password_page.dart';
import 'package:qinglong_app/module/setting_page.dart';
import 'package:qinglong_app/module/subscribe/subscribe_detail_page.dart';
import 'package:qinglong_app/module/subscribe/subscribe_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/module/task/task_detail/task_detail_page.dart';
import 'package:qinglong_app/base/ui/container_page_route.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

class Routes {
  static const String routeHomePage = "/home/homepage";
  static const String routeLogin = "/login";
  static const String routeSubscribeList = "/task/subscribeList";
  static const String routeTaskDetail = "/task/detail";
  static const String routeSubscribeDetail = "/task/subscribeDetail";
  static const String routeEnvDetail = "/env/detail";
  static const String routeAddDependency = "/task/dependency";
  static const String routeAddEnv = "/env/add";
  static const String routeConfigEdit = "/config/edit";
  static const String routeConfigDetail = "/config/detail";
  static const String routeLoginLog = "/log/login";
  static const String routeNotifyLog = "/log/notify";
  static const String routeTaskLog = "/log/task";
  static const String routeScript = "/script";
  static const String routeScriptDetail = "/script/detail";
  static const String routeScriptUpdate = "/script/update";
  static const String routeScriptAdd = "/script/add";
  static const String routeDependency = "/Dependency";
  static const String routeSetting = "/setting";
  static const String routeUpdatePassword = "/updatePassword";
  static const String routeAbout = "/about";
  static const String routeTheme = "/theme";
  static const String routeICloud = "/icloud";
  static const String routeDashboard = "/dashboard";
  static const String routeDashboardTaskResult = "/dashboard/taskResult";
  static const String routeJdck = "/jdck";

  static const String routeIcloudFile = "/icloudfile";

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case routeHomePage:
        return ContainerPageRoute(builder: (context) => const HomePage());
      case routeLogin:
        return ContainerPageRoute(
          builder:
              (context) => LoginPage(
                fromAddNewAccount: (settings.arguments as bool?) ?? false,
              ),
        );
      case routeICloud:
        return ContainerPageRoute(builder: (context) => const IcloudPage());
      case routeSubscribeList:
        return ContainerPageRoute(builder: (context) => const SubscribePage());
      case routeDashboard:
        return ContainerPageRoute(builder: (context) => const DashboardPage());
      case routeDashboardTaskResult:
        return ContainerPageRoute(
          builder:
              (context) => DashboardTaskResultPage(
                isSuccess: (settings.arguments as bool?) ?? true,
              ),
        );
      case routeSetting:
        return ContainerPageRoute(builder: (context) => const SettingPage());
      case routeIcloudFile:
        return ContainerPageRoute(builder: (context) => const IcloudFilePage());

      case routeAddDependency:
        return ContainerPageRoute(
          builder: (context) => const AddDependencyPage(),
        );
      case routeAddEnv:
        if (settings.arguments != null) {
          return ContainerPageRoute(
            builder:
                (context) => AddEnvPage(envBean: settings.arguments as EnvBean),
          );
        } else {
          return ContainerPageRoute(builder: (context) => const AddEnvPage());
        }
      case routeConfigEdit:
        return ContainerPageRoute(
          builder:
              (context) => ConfigEditPage(
                (settings.arguments as Map)["title"],
                (settings.arguments as Map)["content"],
              ),
        );
      case routeConfigDetail:
        return ContainerPageRoute(
          builder:
              (context) => ConfigDetailPage(
                bean: (settings.arguments as Map)["bean"],
                content: (settings.arguments as Map)["content"],
              ),
        );
      case routeLoginLog:
        return ContainerPageRoute(builder: (context) => const LoginLogPage());
      case routeNotifyLog:
        return ContainerPageRoute(builder: (context) => const NotifyLogPage());
      case routeTaskLog:
        if (settings.arguments != null) {
          return ContainerPageRoute(
            builder:
                (context) => TaskLogPage(
                  searchText: (settings.arguments as Map)["search"],
                ),
          );
        } else {
          return ContainerPageRoute(builder: (context) => TaskLogPage());
        }
      case routeScript:
        return ContainerPageRoute(builder: (context) => const ScriptPage());
      case routeDependency:
        return ContainerPageRoute(builder: (context) => const DependencyPage());
      case routeScriptDetail:
        return ContainerPageRoute(
          builder:
              (context) => ScriptDetailPage(
                title: (settings.arguments as Map)["title"],
                path: (settings.arguments as Map)["path"],
              ),
        );
      case routeTaskDetail:
        return ContainerPageRoute(
          builder: (context) => TaskDetailPage(settings.arguments as TaskBean),
        );
      case routeSubscribeDetail:
        return ContainerPageRoute(
          builder:
              (context) => SubscribeDetailPage(
                settings.arguments as Map<String, dynamic>,
              ),
        );
      case routeEnvDetail:
        return ContainerPageRoute(
          builder: (context) => EnvDetailPage(settings.arguments as EnvBean),
        );
      case routeUpdatePassword:
        return ContainerPageRoute(
          builder: (context) => const UpdatePasswordPage(),
        );
      case routeAbout:
        return ContainerPageRoute(builder: (context) => const AboutPage());
      case routeScriptUpdate:
        return ContainerPageRoute(
          builder:
              (context) => ScriptEditPage(
                (settings.arguments as Map)["title"],
                (settings.arguments as Map)["path"],
                (settings.arguments as Map)["content"],
              ),
        );
      case routeScriptAdd:
        return ContainerPageRoute(
          builder:
              (context) => ScriptAddPage(
                (settings.arguments as Map)["title"],
                (settings.arguments as Map)["path"],
              ),
        );
      case routeJdck:
        return ContainerPageRoute(builder: (context) => const JdckPage());
    }

    return null;
  }
}

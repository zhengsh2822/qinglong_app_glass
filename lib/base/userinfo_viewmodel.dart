import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/http/url.dart';
import 'package:qinglong_app/base/multi_account_userinfo_viewmodel.dart';
import 'package:qinglong_app/module/home/system_bean.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';

import '../main.dart';

class UserInfoViewModel {
  String? _token;
  String? _alias;
  String? _host = "";
  String? _userName;
  String? _passWord;
  bool _useSecertLogined = false;

  UserInfoViewModel({
    String? token,
    String? alias,
    String? host,
    String? password,
    String? name,
    bool? useSecret,
  }) {
    _token = token;
    _alias = alias;
    _host = host;
    _passWord = password;
    _userName = name;
    _useSecertLogined = useSecret ?? false;
  }

  void clearCurrentInfo(int index) {
    getIt<MultiAccountUserInfoViewModel>().removeTokenBean(index);
    _host = null;
    _token = null;
    _userName = null;
    _passWord = null;
    _alias = null;
    _useSecertLogined = false;
    // 清理该账号在 getIt 中的所有单例,避免内存堆积
    _unregisterAccountSingletons(index);
  }

  void exitLoginFocus(int index) {
    _token = null;
    updateToken(index, _host, _token, _useSecertLogined, _alias);
  }

  /// 清理指定账号在 getIt 中注册的所有单例
  /// 用于删除账号场景,避免多账号反复操作导致内存堆积
  static void _unregisterAccountSingletons(int index) {
    final name = index.toString();
    // Http 先调 clear 释放缓存和连接池,再 unregister
    if (getIt.isRegistered<Http>(instanceName: name)) {
      getIt<Http>(instanceName: name).clear();
      getIt.unregister<Http>(instanceName: name);
    }
    if (getIt.isRegistered<UserInfoViewModel>(instanceName: name)) {
      getIt.unregister<UserInfoViewModel>(instanceName: name);
    }
    if (getIt.isRegistered<SystemBean>(instanceName: name)) {
      getIt.unregister<SystemBean>(instanceName: name);
    }
    if (getIt.isRegistered<Url>(instanceName: name)) {
      getIt.unregister<Url>(instanceName: name);
    }
    if (getIt.isRegistered<ICloudUtils>(instanceName: name)) {
      getIt.unregister<ICloudUtils>(instanceName: name);
    }
    // GlobalKey 不 unregister(框架会随 widget 卸载自动处理)
  }

  void updateToken(
    int index,
    String? host,
    String? token,
    bool useSecret,
    String? alias,
  ) {
    if (host != null) {
      _host = host;
    }
    _token = token;
    _alias = alias;
    _useSecertLogined = useSecret;
    getIt<MultiAccountUserInfoViewModel>().updateToken(
      index,
      _host,
      _token,
      _useSecertLogined,
      alias,
    );
  }

  void updateUserName(
    String? host,
    String? userName,
    String? password,
    bool secretLogin,
    String? alias,
  ) {
    _host = host;
    _useSecertLogined = secretLogin;
    _userName = userName;
    _passWord = password;
    _alias = alias;

    getIt<MultiAccountUserInfoViewModel>().save2HistoryAccount(
      UserInfoBean(
        userName: _userName,
        host: _host,
        useSecretLogined: _useSecertLogined,
        password: _passWord,
        alias: _alias,
      ),
    );
  }

  String? get token => _token;

  String? get host => _host;

  String? get userName => _userName;

  String? get passWord => _passWord;

  bool get useSecretLogined => _useSecertLogined;

  String? get alias => _alias ?? _host;

  bool isLogined() {
    return token != null && token!.isNotEmpty;
  }

  void updateHost(String host) {
    _host = host;
  }
}

class UserInfoBean {
  String? userName;
  String? password;
  bool useSecretLogined = false;
  String? host;
  String? alias;

  UserInfoBean({
    this.userName,
    this.password,
    this.useSecretLogined = false,
    this.host,
    this.alias,
  });

  UserInfoBean.fromJson(Map<String, dynamic> json) {
    userName = json['userName'];
    password = json['password'];
    useSecretLogined = json['useSecretLogined'] ?? false;
    host = json['host'];
    alias = json['alias'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userName'] = userName;
    data['password'] = password;
    data['useSecretLogined'] = useSecretLogined;
    data['host'] = host;
    data['alias'] = alias;
    return data;
  }
}

class TokenBean {
  String? token;
  bool useSecretLogined = false;
  String? host;
  String? alias;

  TokenBean({this.token, this.useSecretLogined = false, this.host, this.alias});

  TokenBean.fromJson(Map<String, dynamic> json) {
    token = json['token'];
    useSecretLogined = json['useSecretLogined'] ?? false;
    host = json['host'];
    alias = json['alias'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['token'] = token;
    data['useSecretLogined'] = useSecretLogined;
    data['host'] = host;
    data['alias'] = alias;
    return data;
  }
}

# qinglong_app_glass

基于 Flutter 框架编写的青龙面板第三方客户端

基于 [qinglong](https://github.com/whyour/qinglong) 开源项目，二改自 [ayoulx/qinglong-app](https://github.com/ayoulx/qinglong-app)

> 本项目在原项目基础上进行了主题系统重构、多账号安全增强、仪表盘功能扩展、脚本搜索能力补全、京东助手独立模块化等改进，并移除了部分不兼容的依赖与功能。

## App 功能介绍

### 仪表盘（对齐 Web 端）

并行调用 7 个 dashboard 接口，老版本服务端会自动隐藏不支持的卡片：

- **青龙版本信息**：服务端版本号展示
- **任务概览**：总任务/已启用/已禁用/今日执行/今日成功/今日失败/成功率/平均耗时
- **近 7 日趋势**：自绘折线图（纯 `CustomPaint`，无 fl_chart 依赖），含网格线、Y 轴刻度、X 轴日期、总趋势线（渐变区域填充）、成功/失败虚线、数据圆点
- **今日耗时 Top 5**：排名/任务/平均耗时/最长单次
- **今日执行次数 Top 5**：排名/任务/次数/平均耗时/成功率
- **标签统计**：标签/任务数/今日执行/成功率/平均耗时
- **实时运行态**：运行中/排队中数量、正在运行任务（含 PID）、24 小时未运行任务
- **系统资源**：平台/CPU 核心/系统负载/运行时长/内存与堆内存进度条

### 定时任务

- 任务列表卡片化展示，支持左/右滑动操作（启用/禁用、收藏、运行、编辑、删除等）
- 切换底部导航 Tab 时自动收起所有展开的滑动卡片（全局 `SlidableCloseNotifier` 通知器 + `ValueKey` 重建机制）
- 任务详情、即时日志、历史日志查看
- 日志支持长按选择复制，并启用 iOS 风格文本选择放大镜

### 环境变量

- 列表/分组管理，滑动操作与任务页一致
- Tab 切换自动收起滑动卡片
- 详情页支持长按复制与 iOS 风格放大镜

### 订阅管理

- 订阅列表滑动操作（运行、编辑、删除等）
- Tab 切换自动收起滑动卡片
- 详情页支持长按复制

### 脚本管理

- 树形目录展示，顶部常驻胶囊形搜索栏（圆角 24），300ms 防抖递归过滤文件名/目录名
- 脚本查看/编辑页：点击右上角搜索图标弹出搜索卡片，支持 `/re/flags` 正则语法，200ms 防抖
- 搜索卡片含上一个（chevron_up）/下一个（chevron_down）/关闭（xmark）按钮
- 通过 `WebView.runJavaScript` 注入 `appSearch/appSearchNext/appSearchPrev` 函数，使用 CodeMirror `getSearchCursor` + `markText` 高亮匹配
- CSS 类 `.cm-app-search-match` / `.cm-app-search-current` 区分普通匹配与当前匹配
- 代码高亮基于 `flutter_highlight`，支持 90+ 主题
- 代码区 `SelectableText.rich` 同样启用 iOS 风格放大镜

### 京东助手（独立模块）

- 独立青龙面板登录，自动从应用设置获取 clientId/clientSecret
- Cookie 上传前校验 pt_key/pt_pin
- 账号与青龙配置备份/恢复
- 添加/编辑/删除账号弹窗统一使用 `_showBlurDialog` 模糊展开动画与卡片样式（三主题一致）

### 其他功能

- 配置文件管理、依赖管理（缺失依赖扫描）、登录日志、任务日志
- 应用内购买、推送设置、字体大小、修改密码、账号排序、iCloud 备份
- 检查更新、关于页面

## 主要改进

### 新增功能与设计

- **三种主题模式**：赛博朋克（青色霓虹 #00F0FF + 玻璃态背景 + BackdropFilter 模糊）、Apple（#00cccc 纯色 + BackdropFilter 模糊弹窗）、白色（18px 圆角统一规范）。黑色主题已合并入赛博模式
- **主题切换动画**：基于 `AnimatedTheme`（300ms easeInOut）实现当前页面平滑过渡
- **多账号 HTTP 缓存隔离**：HTTP 缓存按账号隔离，防止跨账号数据泄漏
- **仪表盘功能扩展**：新增 4 个 API 端点（`/api/dashboard/trend`、`/top-time`、`/top-count`、`/labels`）及对应 UI 模块，自绘折线图（`CustomPaint`，无 fl_chart 依赖），老版本服务端自动隐藏不支持的卡片
- **脚本搜索能力补全**：脚本列表页常驻搜索过滤；脚本查看/编辑页弹出式搜索卡片，支持正则语法、上下导航、200ms 防抖、CodeMirror 高亮匹配
- **Slidable 跨 Tab 自动收起**：全局 `SlidableCloseNotifier`（`ValueNotifier<int>`）在底部导航切换时通知任务/环境变量/订阅三个页面，通过更新 `ValueKey` 强制重建 Slidable 卡片以重置展开状态
- **iOS 风格文本选择放大镜**：11 个文件的 `SelectableText` / `SelectableText.rich` 应用了 `cupertinoTextSelectionControls`，覆盖日志、任务详情、环境变量详情、订阅详情、代码高亮等可复制区域
- **京东助手独立模块**：独立青龙面板登录、自动从应用设置获取 clientId/clientSecret、Cookie 上传前校验 pt_key/pt_pin、账号与青龙配置备份/恢复
- **京东助手弹窗统一**：添加/编辑/删除账号弹窗统一使用 `_showBlurDialog` 模糊展开动画与卡片样式，三主题一致
- **按钮配色统一**：非破坏性长按钮使用主色渐变 `[primaryColor, primaryColor.withOpacity(0.85)]`，Apple 主题为 #00cccc 渐变；破坏性按钮保留红色渐变
- **赛博模式搜索框深色化**：搜索框在赛博模式下使用 `0xFF12121A` 深色背景 + 青色微光边框，解决白底问题
- **统一滑动操作**：任务/环境变量/订阅三个页面统一使用 `Slidable + SlidableAction`，赛博与非赛博模式结构完全一致，仅配色不同
- **统一设计规范**：所有搜索框/输入框胶囊形状（borderRadius 24）、卡片统一 18px 圆角、依赖管理 Tab 胶囊样式（24px 圆角 + 青色 thumb）
- **HTTP 容错**：`ResponseType.plain` + 手动 `jsonDecode`，过滤底层库 JSON 解析错误
- **构建脚本**：`build_apk.ps1` 禁用 R8 优化（`--no-shrink`），自动复制 APK 到桌面，自动检测 ADB 设备并安装
- **调试支持**：`debug_helper.ps1` + ADB 配置，支持 `flutter run` 热重载与 IDE 断点调试

### 移除的不兼容功能与依赖

- **App 内消息推送功能**（原项目 2.6.3 已移除，本项目延续此变更）
- **`convex_bottom_bar`**：改用自定义底部导航
- **`cached_network_image`**：移除网络图片缓存库
- **`file_picker`**：移除文件选择器
- **`quick_actions`**：移除桌面快捷方式
- **`flutter_dynamic_icon`**：移除动态图标切换
- **`flutter_scroll_to_top`**：移除列表顶部跳转
- **`json_table` / `extended_text`**：移除表格与扩展文本
- **`launch_review` / `package_info_plus` / `move_to_background`**：移除评分跳转、包信息、后台运行
- **`dio_log` / `json_conversion`**：移除网络日志与 JSON 转换注解
- **`CyberSlidable` 组件**：弃用，统一为标准 `Slidable`
- **Lottie 扫描动画**：弃用无效的 `assets/scan.json`，改用 `CupertinoIcons.doc_text_search`
- **主题切换强制跳转首页逻辑**：移除 `MaterialApp` 的 `key: ValueKey(themeMode)` 与 `onThemeChanged` 回调

### 依赖升级

- Dart SDK：`>=2.18.0` → `^3.7.2`
- `dio`：`4.0.6` → `5.7.0`
- `flutter_slidable`：`2.0.0` → `3.1.2`
- `flutter_riverpod`：`2.1.1` → `2.6.1`
- `local_auth`：`2.1.2` → `2.3.0`
- `share_plus`：`6.3.0` → `10.1.4`
- `logger`：`1.1.0` → `2.7.0`
- `cupertino_icons`：`1.0.5` → `1.0.8`
- `flutter_displaymode`：`0.4.1` → `0.7.0`

## 构建打包

```powershell
# Release 打包（禁用 R8 优化，自动复制到桌面并安装到已连接设备）
.\build_apk.ps1

# Debug 打包
.\build_apk.ps1 -DebugMode

# 仅构建，不复制不安装
.\build_apk.ps1 -NoCopy -NoInstall
```

> Release 模式启用 ABI split（仅生成 arm64-v8a），Flutter 工具会误报"failed to produce an .apk file"，实际 APK 已生成在 `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`，使用 `build_apk.ps1` 可自动处理并复制为 `app-release.apk`。

## 相关项目

- [qinglong_app_glass_Wallpaper](https://github.com/zhengsh2822/qinglong_app_glass_Wallpaper) — 支持更换壁纸的版本

## 致谢

- [whyour/qinglong](https://github.com/whyour/qinglong) — 青龙面板服务端
- [ayoulx/qinglong-app](https://github.com/ayoulx/qinglong-app) — 原客户端项目
- [yclown/ql_jd_cookie](https://github.com/yclown/ql_jd_cookie)@XanderYe - 原版京东助手作者
- @yclown - 原版修改者

## License

AGPL-3.0

# iOS 版与 Android 版功能对比

> 生成日期：2026-08-15
> 依据：通读 Android 原生层（MainActivity.kt / NativeWebViewActivity.kt / WebViewActivity.kt）、全部 `Platform.isAndroid/isIOS` 分支、各 MethodChannel 调用点后整理的对比。
> iOS 端基础版：GitHub Actions 云构建未签名 IPA（Flutter 3.29.3），AppDelegate.swift 为默认实现。

## 结论速览

- **核心业务功能 100% 一致**（登录、任务、环境变量、脚本、依赖、订阅、日志、仪表盘、扫描、主题/字体设置等）。
- **完全缺失 4 项**：悬浮时钟、京东助手 Cookie 自动获取、京东助手短信验证码填充、文件选择器。
- **降级/差异 4 项**：前后台轮询暂停、内存预警清理、删除备份方式、备份存储位置。
- **代码层 Android-only 但无实际差异 2 项**：高刷新率、系统栏样式控制。
- 多数缺失源于 **iOS 系统级安全限制**（悬浮窗、读短信、系统悬浮层为 iOS 根本不允许），不属于可修复的缺陷。

---

## 一、核心业务功能（两平台完全一致）✅

| 功能 | 说明 |
|---|---|
| 青龙全部业务 | 登录 / 多账号 / HTTP 缓存隔离 / 任务 / 环境变量 / 脚本 / 依赖 / 订阅 / 日志 / 仪表盘 / 扫描依赖 / 账号排序 |
| 代码编辑器 | CodeMirror + webview_flutter，iOS 用 WKWebView，功能一致 |
| 主题切换 / 字体大小 / 字体颜色 | 纯 Dart，三主题一致 |
| Face ID / 指纹解锁 | local_auth 跨平台，iOS 走 Face ID（已加 NSFaceIDUsageDescription） |
| 分享 | share_plus 跨平台 |
| 推送 / 通知设置 | 配置服务端 webhook（企业微信 / PushPlus 等），App 不直接收推送 |
| 文本选择放大镜 / 代码高亮 / 剪贴板识别 | 纯 Dart，一致 |
| 备份（经 iCloud / 文档目录） | iOS 保存后额外自动同步 iCloud |

## 二、完全缺失（Android 有，iOS 无）❌

| # | 功能 | 受影响入口 | iOS 原因 |
|---|---|---|---|
| 1 | **悬浮时钟**（系统级悬浮窗） | "我的 → 悬浮时间" | iOS 禁止第三方 App 创建系统悬浮窗（**系统级限制，无法实现**） |
| 2 | **京东助手-自动获取登录 Cookie** | 京东助手"自动获取" | iOS 无 WebView Cookie 提取通道（MethodChannel `com.qlapp.qinglong_app/cookies` 无 iOS 实现），静默失败，需手动粘贴 Cookie |
| 3 | **京东助手-短信验证码自动填充** | 京东助手短信登录 | iOS 禁止第三方 App 读短信（**系统级限制，无法实现**），只能手动输入 |
| 4 | **文件选择器** | 备份恢复（选 .tgz）、脚本上传（选本地文件）、配置导入 | MethodChannel `com.qlapp.qinglong_app/file_picker` 无 iOS 实现，入口点击无效 |

> 代码位置：
> - 悬浮时钟：`lib/utils/floating_clock_service.dart` + `MainActivity.kt` `floating_clock` 通道
> - Cookie：`lib/module/others/jdck/jdck_page.dart:387` `_getCookies`
> - 短信：`lib/module/others/jdck/jdck_page.dart:36` `_smsChannel`
> - 文件选择：`lib/utils/file_picker_utils.dart`（被 `upload_script_widget.dart:256`、`backup_page.dart:333` 调用）

## 三、降级/差异（有替代或行为不同）⚠️

| # | 功能 | Android | iOS |
|---|---|---|---|
| 5 | 前后台轮询暂停（金标联盟公平调度） | ProcessLifecycleOwner 主动暂停 Timer | 无此机制（`AppLifecycleProvider` 仅 Android 订阅）；但 iOS 系统会直接挂起后台应用，实际影响很小 |
| 6 | 内存预警/查杀自动清缓存（金标联盟内存机制） | 监听系统内存广播（TRIM/KILL） | 无对应机制；iOS 内存由系统管理，影响小 |
| 7 | 删除备份 | 应用内"删除备份"按钮 | 只能去"文件"App 手动删 |
| 8 | 备份存储位置 | 应用私有目录（`/data/user/0/...`，非 root 看不到） | 应用文档目录 + iCloud 同步（反而多 iCloud 能力） |

## 四、仅代码层面 Android-only（无实际功能差异）⚪

| 功能 | 说明 |
|---|---|
| 高刷新率显示（FlutterDisplayMode） | Android 手动开高刷；iOS 系统自动（ProMotion），无需操作 |
| 状态栏 / 导航栏颜色控制（SystemUiOverlayStyle） | Android 专属 API；iOS 系统自动适配小白条 / 状态栏沉浸 |

## 五、无差异的特殊项

- **VIP / 内购**：当前"APP功能介绍"页只是功能说明，无实际支付 SDK（无微信 / 支付宝 / Google Play 内购代码）；"支持我"页是微信 / 支付宝打赏二维码（静态图）→ 两平台一致。
- **App 内消息推送**：两平台均已移除。
- **原生 WebView 编辑器**：`NativeEditorUtils`（`com.qlapp.qinglong_app/webview`）已是死代码，无调用点；编辑器本体跨平台可用 → 无影响。

---

## 附：iOS 端可补齐方向（如需）

1. **文件选择器**：iOS 用 `UIDocumentPickerViewController`（file_picker pub 包或自写平台通道）可补齐备份恢复 / 脚本上传 / 配置导入。
2. **京东 Cookie 提取**：iOS 用 `WKWebsiteDataStore` 可获取 WKWebView Cookie，补齐"自动获取"。
3. 短信验证码、系统悬浮窗受 iOS 系统限制，**无法实现**。

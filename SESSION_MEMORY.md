# 青龙面板移动客户端 - 会话记忆

> 项目路径: `c:\Users\Administrator\Desktop\mimo\qinglong_app_glass`
> 技术栈: Flutter + Dart + Riverpod + flutter_slidable + webview_flutter + CodeMirror
> 最后更新: 2026-07-15 11:24

---

## 一、项目硬约束

- **APK 版本**: 3.0.0（构建脚本 `build_apk.ps1` 强制 `versionName=3.0.0`）
- **设备 ID**: `Z9IJBYQW8HHU55JV`
- **APK 输出**: `C:\Users\Administrator\Desktop\qinglong_app_v3.0.0_release.apk`
- **打包命令**: `powershell -ExecutionPolicy Bypass -File build_apk.ps1`（cwd 必须为项目根）
- **架构**: 主用 ARM64，**只 build APK，不要 build ipa**
- **修改前必须 Read**，修改后**必须打包安装**给用户看
- **版本号不修改** - 不要改动 version number，保持 3.0.0+300 便于覆盖安装

---

## 二、本轮 (2026-07-15) 滑动按钮 + 卡片圆角改造

### 1. 抽离通用滑动按钮组件

**`lib/base/ui/cyber/cyber_slide_action.dart`**

- 新增 `AppSlideButton`（基类）
  - 关键参数：`color` / `icon` / `label` / `cyberMode` / `width` / `outerGap` / `innerGap` / `glowOpacity`
  - `cyberMode=true` → 同色外发光 + 边框 (0.5px width, 0.7 opacity)
  - `cyberMode=false` → 无外发光, 无边框
  - `width=double.infinity` → 用 `Expanded` 等分 ActionPane 内部空间
  - `width=60`(默认) → 固定 60px
  - 自动 `Slidable.of(context)?.close()`
- 保留 `CyberSlideButton`（继承自 AppSlideButton，`cyberMode=true`）—— 兼容旧代码

### 2. 三个页面统一使用 `AppSlideButton`

| 文件 | startActionPane | endActionPane |
|------|-----------------|---------------|
| `lib/module/task/task_page.dart` | 2 按钮 (extentRatio=0.4) | 4 按钮 (extentRatio=0.7) |
| `lib/module/env/env_page.dart` | 无 | 3 按钮 (extentRatio=0.55) |
| `lib/module/subscribe/subscribe_page.dart` | 2 按钮 (extentRatio=0.4) | 3 按钮 (extentRatio=0.55) |

- **统一 `ScrollMotion`**（不是 StretchMotion）—— 按钮跟着卡片一起滑
- `width: double.infinity`（等分 Pane 内宽）
- **赛博模式颜色**:
  - task: `0xFF00F0FF`(青) / `0xFFFFC107`(黄) / `0xFF333333`(深灰) / `0xFFFF3D00`(红)
  - env/subscribe: `0xFF00F0FF` / `0xFF333333` 或 `0xFFA356D6` / `0xFFFF3D00`
- **非赛博模式颜色**:
  - task: `AppColors.success` / `AppColors.warning` / `AppColors.purple` / `AppColors.danger`
  - env/subscribe: `0xff5D5E70` / `0xffA356D6` / `0xffEA4D3E`
- **startActionPane 颜色**(不分模式):
  - task: `0xffD25535` / `0xff606467`
  - subscribe: `0xffD25535` / `0xff606467`

### 3. 卡片圆角统一

**`lib/base/app_colors.dart:64`** — `radiusCard` 12 → **18**

- 影响所有 `BorderRadius.circular(AppleColors.radiusCard)` 的非赛博页面
- 赛博模式本来就用 `BorderRadius.circular(18)`，现在两者统一

### 4. 关键修复点

- `cyberMode: true` (赛博) / `false` (非赛博) - 控制外发光
- `ScrollMotion` - 按钮跟随卡片移动
- `width: double.infinity` - 等分 Pane 内部空间
- 任务/订阅页面要注意 `isCyber` 变量**在 build() 作用域内**——子函数如 `_buildCyber` / `_buildNormal` 需要 `final bool isCyber = true/false;` 显式声明

---

## 三、脚本页面搜索改造 (2026-07-15 更新)

### 背景
- 原版: CodeMirror 自带搜索栏 (Search: (Use /re/ syntax for regexp search)) 在 WebView 内部
- 新版: 点击 appBar 右上角 🔍 → 在 **编辑器上方** 弹出应用层搜索栏（不是 Overlay，不用 Positioned）
- **搜索框 UI 用 SearchCell 组件**（与其他页面搜索框统一），不自定义内框
- **搜索功能真正实现**: 输入关键词 → 跳转第一个匹配 → 上/下导航

### 改动文件

#### 1. CodeMirror 端 (`assets/codemirror.html`)

**HTML `<style>` 中新增 CSS 高亮样式** (约 L475):
```css
.cm-app-search-match {
  background-color: #ff9c4a !important;
  background-color: rgba(255, 156, 74, .55) !important;
  border-radius: 2px;
}
.cm-app-search-current {
  background-color: #ff6b00 !important;
  background-color: rgba(255, 107, 0, .7) !important;
  border-radius: 2px;
}
```

**JS 函数** (约 L13798-13853):
- `clearSearchText()` - 清除所有 markText 标记 + `_appSearchCurrentMark`
- `appSearch(query)` - 搜索所有匹配 → markText 高亮 → `_jumpToMatch(0)` 跳转第一个
- `_jumpToMatch(idx)` - 内部函数：跳转指定匹配 + 当前项加 `cm-app-search-current` 更强高亮
- `appSearchNext()` - 跳转下一个匹配（循环）
- `appSearchPrev()` - 跳转上一个匹配（循环）**[新增]**
- 支持 `/re/flags` 正则语法

#### 2. Flutter CodeMirror 控制器 (`lib/module/code_editor/codemirror/io.dart`)

**`CodeMirrorViewState`** 新增公共方法:
- `appSearch(String query)` - 调 `appSearch(decodeURIComponent("$encoded"))`
- `appSearchNext()` - 调 `appSearchNext()`
- `appSearchPrev()` - 调 `appSearchPrev()` **[新增]**
- `clearAppSearch()` - 调 `clearSearchText()`
- `showSearchBar()` - 旧方法，调 CodeMirror 自带搜索（编辑页不再用）

#### 3. 脚本查看页 (`lib/module/others/scripts/script_detail_page.dart`)

**搜索栏**:
- 点击 appBar 搜索图标 → `_toggleSearchBar()` 弹出/收起
- 搜索栏在 body 的 Column 中（appBar 下方、编辑器上方），**不是 Overlay**
- UI: `SearchCell`（占满宽度）+ `chevron_up`(上一个) + `chevron_down`(下一个) + `xmark`(关闭)
- 用 `SearchCell` 组件（与其他页面统一），不自定义内框

**搜索逻辑**:
- `_searchTextCtrl.addListener(_onSearchTextChanged)` 监听文本变化
- 200ms debounce → `codeKey.currentState?.appSearch(text)` 调用 WebView 搜索
- 空文本 → `clearAppSearch()` 清除高亮
- `_onSearchNext()` / `_onSearchPrev()` → 上/下导航

#### 4. 脚本编辑页 (`lib/module/others/scripts/script_edit_page.dart`) **[新增]**

- 同样的搜索栏 + 搜索逻辑（与查看页一致）
- appBar 搜索按钮改为 `_toggleSearchBar()`（不再调 `showSearchBar()`）
- body 改为 Column：`if (_isSearchOpen) _buildSearchBar()` + `Expanded(Editor(...))`

---

## 四、Slidable 卡片切换 Tab 自动回位 (2026-07-15 新增)

### 背景
- 滑动卡片露出功能按钮后，切换底部导航栏 tab，卡片应自动回位为完整状态

### 实现

#### 1. 全局通知器 (`lib/base/ui/slidable_close_notifier.dart`) **[新增文件]**

```dart
class SlidableCloseNotifier {
  static final ValueNotifier<int> _notifier = ValueNotifier<int>(0);
  static ValueListenable<int> get listenable => _notifier;
  static void notify() { _notifier.value++; }
  static int get value => _notifier.value;
}
```

#### 2. 触发 (`lib/module/home/home_page.dart`)

- tab 切换 `onTap` 中调用 `SlidableCloseNotifier.notify()`
- import: `slidable_close_notifier.dart`

#### 3. 监听页面（3 个）

| 文件 | SlidableAutoCloseBehavior 位置 |
|------|-------------------------------|
| `lib/module/task/task_page.dart` | L284 (notScripts), L513 (TabBarView) |
| `lib/module/env/env_page.dart` | L331 (TabBarView) |
| `lib/module/subscribe/subscribe_page.dart` | L162 (ListView) |

每个页面:
- `initState` 中 `SlidableCloseNotifier.listenable.addListener(_onSlidableClose)`
- `_onSlidableClose()` → `setState(() { _slidableResetKey = SlidableCloseNotifier.value; })`
- `SlidableAutoCloseBehavior` 加 `key: ValueKey('xxx_${_slidableResetKey}')` → key 变化重建 widget → 卡片重置
- `dispose` 中 `removeListener`

---

## 五、重要决策/约定

1. **左滑/右滑按钮** - 统一用 `AppSlideButton` + `ScrollMotion` + `width: double.infinity`
2. **卡片圆角** - 全部用 `AppleColors.radiusCard=18`
3. **脚本搜索** - 用 SearchCell 组件 + 应用层搜索栏（不是 Overlay），查看页和编辑页都改
4. **搜索功能** - 真正调用 CodeMirror appSearch JS，高亮匹配 + 上/下导航
5. **Slidable 回位** - tab 切换时通过 ValueNotifier + ValueKey 重建 SlidableAutoCloseBehavior
6. **未改动的页面**:
   - `lib/module/task/task_page.dart` 常驻搜索 (top searchCell) **保留不动**
   - `lib/module/others/scripts/script_page.dart` 常驻搜索 (script_list) **保留不动**
   - `lib/module/config/config_page.dart` / `config_detail_page.dart` **保留不动**
7. **APK 构建** - 必须用 `build_apk.ps1`，**不要手动** `flutter build apk`
8. **设备** - `Z9IJBYQW8HHU55JV` 唯一测试设备

---

## 六、用户反馈关键词

- "无敌了" → 满意
- "怎么左边按钮怎么不是一个层级的" → 左右 Pane 一致性问题
- "还是固定一个位置" → StretchMotion → ScrollMotion
- "内容卡片左滑不要固定长度" → extentRatio 控制，按钮完全展开即可
- "左滑 / 右滑按钮 跟着卡片一起移动" → ScrollMotion
- "按钮和内容卡片间距有问题" → 用等分 width: double.infinity
- "非赛博模式卡片圆角是不是比赛博的小" → radiusCard 12→18
- "图一原版搜索效果改为图二" → 应用层搜索栏（不是 Overlay）
- "只修改编辑脚本代码页面的" → 改 script_detail_page.dart + script_edit_page.dart
- "保存上下文到根目录" → 写 SESSION_MEMORY.md
- "搜索功能还是没实现" → CSS 高亮样式缺失，补到 HTML `<style>` 中
- "UI不要加内框" → 改用 SearchCell 组件
- "二图编辑脚本页面你没改" → script_edit_page.dart 也要加搜索
- "直接跳转第一匹配结果，然后可选择上或下查找" → appSearch 跳第一个 + appSearchPrev/appSearchNext
- "切换底部导航栏都会自动回位成完整卡片状态" → SlidableCloseNotifier + ValueKey 重建

---

## 七、文件改动总览 (2026-07-15)

| 文件 | 状态 | 说明 |
|------|------|------|
| `lib/base/ui/cyber/cyber_slide_action.dart` | ✅ 改 | 新增 AppSlideButton |
| `lib/base/app_colors.dart` | ✅ 改 | radiusCard 12→18 |
| `lib/module/task/task_page.dart` | ✅ 改 | 统一 AppSlideButton + Slidable 回位监听 |
| `lib/module/env/env_page.dart` | ✅ 改 | 统一 AppSlideButton + Slidable 回位监听 |
| `lib/module/subscribe/subscribe_page.dart` | ✅ 改 | 统一 AppSlideButton + Slidable 回位监听 |
| `lib/module/others/scripts/script_detail_page.dart` | ✅ 改 | 搜索栏（SearchCell + 上/下导航） |
| `lib/module/others/scripts/script_edit_page.dart` | ✅ 改 | 搜索栏（SearchCell + 上/下导航）**[新增]** |
| `lib/module/code_editor/codemirror/impl.dart` | ✅ 改 | EditorController + runJavaScript |
| `lib/module/code_editor/codemirror/io.dart` | ✅ 改 | appSearch/appSearchNext/appSearchPrev/clearAppSearch |
| `assets/codemirror.html` | ✅ 改 | CSS 高亮样式 + appSearch/appSearchNext/appSearchPrev JS 函数 |
| `lib/base/ui/slidable_close_notifier.dart` | ✅ 新增 | 全局 Slidable 关闭通知器 |
| `lib/module/home/home_page.dart` | ✅ 改 | tab 切换触发 SlidableCloseNotifier |
| `lib/base/ui/cyber/task_slide_actions.dart` | ⚠️ 未删 | 不再被引用，可后续清理 |

---

## 八、构建结果

- **APK**: `C:\Users\Administrator\Desktop\qinglong_app_v3.0.0_release.apk`
- **大小**: 22.52 MB
- **最后构建时间**: 2026-07-15 11:24:27
- **app version**: 3.0.0+300

---

## 九、环境变量页面搜索排序 Bug 修复 (2026-07-17)

### 背景
- 环境变量页面关键词搜索时，启用/已禁用 tab 过滤出来的内容显示不正常
- 原 bug：`EnvListView`（启用/禁用 tab）对非匹配项返回 `SizedBox.shrink()`，但仍占据 `ListView.separated` 的 itemCount 位置，导致：
  1. 隐藏项之间仍生成 12px 分隔符，造成可见项之间出现多余大间距
  2. 序号显示为原始列表位置而非过滤后的连续序号（如原第 3、7、9 位匹配时显示 "4"、"8"、"10" 而非 "1"、"2"、"3"）

### 改动文件

#### `lib/module/env/env_page.dart`

**1. `EnvListView`（启用/禁用 tab，L1050-1091）**
- 改为先过滤出匹配项构建 `filtered` 列表，再以此构建 `ListView.separated`
- `itemCount` 从 `widget.list.length` 改为 `filtered.length`
- 序号 `i` 自然从 0 连续递增
- 移除了 `SizedBox.shrink()` 分支

**2. `EnvRecordListView`（全部 tab，L1121-1151）**
- 新增 `displayIndex` 计数器，仅当项匹配搜索时递增
- 用 `displayIndex` 替代原始循环索引 `i` 传给 `EnvItemCell`

### 构建结果
- **APK**: `C:\Users\Administrator\Desktop\qinglong_app_v3.0.0_release.apk`
- **大小**: 25.21 MB
- **最后构建时间**: 2026-07-17 01:37:05
- **app version**: 3.0.0+300
- **安装设备**: ee054345

---

## 十、京东助手页面进入卡顿优化 (2026-07-17)

### 背景
- 点击进入京东助手页面时转场动画掉帧卡顿
- 原因：`initState` 中 `addPostFrameCallback` + `Future.microtask` 在转场动画期间创建 WebView 并加载京东登录页面，WebView 初始化和 URL 加载消耗 GPU/CPU 导致动画掉帧

### 修复方案
- WebView 初始化从 `initState` 延迟到**路由转场动画完成后**执行
- `_loadConfig()`（轻量本地配置）仍在 `addPostFrameCallback` 中执行，不影响首帧渲染

### 改动文件：`lib/module/others/jdck/jdck_page.dart`

1. 新增字段 `_routeListenerAdded`、`_routeAnimation`（L78-79）
2. `initState`（L91-100）：移除 `Future.microtask` 中的 WebView 初始化，仅保留 `_loadConfig()`
3. 新增 `didChangeDependencies`（L102-115）：获取 `ModalRoute.of(context)?.animation`，若动画未完成则添加状态监听
4. 新增 `_onRouteAnimationComplete`（L117-122）：动画 `completed` 时移除监听并调用 `_initWebViewDeferred`
5. 新增 `_initWebViewDeferred`（L124-128）：安全初始化 WebView + `setState`
6. `dispose`（L1000）：移除路由动画监听

### 构建结果
- **APK**: 25.21 MB
- **构建时间**: 2026-07-17 01:53:09
- **安装设备**: ee054345

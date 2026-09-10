const String spLoginHistory = "loginHistory";
const String spTokenBeanList = "spTokenBeanList";
const String spAccountCount = "spAccountCount";
const String spVIP = "spvip";
const String spVIPLOGO = "spviplogo";
const String spVIPLOGOChangeReminder = "spVIPLOGOChangeReminder";
const String spOpenAuth = "spOpenAuth";
const String spPoetToken = "spPoetToken";

const typeNormal = 0;
const typeVIP = 10;
const typeSVIP = 12531;

const String spEnvBackTime = "envBackTime";
const String spSubscribeBackTime = "subscribeBackTime";
const String spConfigBackTime = "configBackTime";
const String spICloud = "spICloud";
const String spShowLine = "spShowLine";
const String spUseWebCodeEditor = "spUseWebCodeEditor";
const String spAutoShowLog = "spAutoShowLog";
const String spVersioCodeHistory = "spVersioCodeHistory";
const String spLocalBackUpFileExperiedTime = "spLocalBackUpFileExperiedTime";
const String spThemeStyle = "spThemeStyle";
const String spThemeFollowSystem = "spThemeFollowSystem";
const String spTextScaleFactor = "spTextScaleFactor";
// 全局字体粗细（int：400/500/600/700，全局单一值，不分赛博/主题版）
const String spTextFontWeight = "spTextFontWeight";
// 赛博模式自定义字体颜色（与主题版独立，两主题颜色互斥）
const String spCyberPrimaryTextColor = "spCyberPrimaryTextColor";
const String spCyberSecondaryTextColor = "spCyberSecondaryTextColor";
// 非赛博模式（主题版）自定义字体颜色
const String spThemePrimaryTextColor = "spThemePrimaryTextColor";
const String spThemeSecondaryTextColor = "spThemeSecondaryTextColor";
const String spLogAutoJump2Bottom = "spLogAutoJump2Bottom";
const String spAndroidKeyboardError = "spAndroidKeyboardError";
const String spSingleInstance = "spSingleInstance";
// 冷启动主动提醒时"已提醒过"的 GitHub release 附件上传时间(epoch 毫秒)，
// 用于避免同一版本重复打扰；出现更新的 release 后才再次提醒
const String spGithubLastRemindTime = "spGithubLastRemindTime";
// 冷启动主动提醒时"已提醒过"的 GitHub 安装包文件名序号（release_N）
const String spGithubLastRemindNo = "spGithubLastRemindNo";

/// 毛玻璃效果开关（bool，默认 true=开启）
///
/// true  = 透明背景 + BackdropFilter 高斯模糊（毛玻璃）
/// false = 纯色背景（不透明），不使用 BackdropFilter（GPU 零开销）
/// 用户可在「系统设置 → 通用功能 → 毛玻璃效果」中开关。
const String spBlurEffect = "spBlurEffect";

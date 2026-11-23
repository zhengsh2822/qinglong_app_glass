import 'dart:convert';

import 'package:qinglong_app/utils/sp_utils.dart';

/// 会话持久化：UI 条目 + 模型对话历史一起保存，退出重进可恢复。
///
/// 这里故意用 SharedPreferences 明文 JSON：
/// - 会话内容不含 Token / API Key（工具结果已脱敏），无需加密；
/// - 之前用 Isolate + CryptoUtils 加密，一旦加密失败就 remove key，
///   导致会话永远存不上（表现为「退出就清空」），可靠性优先。
/// 按「后端 + 账号」分 key，切换后端/账号不会串会话。
class AgentSessionStore {
  AgentSessionStore._();

  /// 会话保留天数，设置页可选 1/3/7 天，过期自动清理。
  static const String keepDaysKey = 'agent_session_keep_days';
  static const int defaultKeepDays = 7;

  static int get keepDays {
    final v = SpUtil.getInt(keepDaysKey, defValue: defaultKeepDays);
    return (v == 1 || v == 3 || v == 7) ? v : defaultKeepDays;
  }

  static Future<void> setKeepDays(int days) async {
    if (days == 1 || days == 3 || days == 7) {
      await SpUtil.putInt(keepDaysKey, days);
    }
  }

  static Duration get maxAge => Duration(days: keepDays);

  static String keyFor(String backendId, int accountIndex) =>
      'agent_session_v3_${backendId}_$accountIndex';

  static Future<Map<String, dynamic>> load(String key) async {
    final stored = SpUtil.getString(key);
    if (stored.isEmpty) return _empty();
    try {
      final decoded = jsonDecode(stored);
      if (decoded is Map) {
        final savedAt = decoded['savedAt'];
        if (savedAt is int &&
            DateTime.now().millisecondsSinceEpoch - savedAt >
                maxAge.inMilliseconds) {
          await SpUtil.remove(key);
          return _empty();
        }
        return <String, dynamic>{
          'entries': _listOfMaps(decoded['entries']),
          'history': _listOfMaps(decoded['history']),
        };
      }
    } catch (_) {
      // 旧格式或损坏时安全降级为空会话。
    }
    return _empty();
  }

  static Future<void> save(
    String key, {
    required List<Map<String, dynamic>> entries,
    required List<Map<String, dynamic>> history,
  }) async {
    final raw = jsonEncode(<String, dynamic>{
      'entries': entries,
      'history': history,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await SpUtil.putString(key, raw);
  }

  static Future<void> clear(String key) async {
    await SpUtil.remove(key);
  }

  static Map<String, dynamic> _empty() => <String, dynamic>{
        'entries': <Map<String, dynamic>>[],
        'history': <Map<String, dynamic>>[],
      };

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

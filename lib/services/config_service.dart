import 'package:shared_preferences/shared_preferences.dart';

/// 本地配置管理（服务器地址、Token）
class ConfigService {
  static const String _keyHost = 'ghost_host';
  static const String _keyToken = 'ghost_token';

  static String? _cachedHost;
  static String? _cachedToken;

  /// 获取服务器地址（不含端口）
  static Future<String> getHost() async {
    if (_cachedHost != null) return _cachedHost!;
    final prefs = await SharedPreferences.getInstance();
    _cachedHost = prefs.getString(_keyHost) ?? '';
    return _cachedHost!;
  }

  /// 获取 Token
  static Future<String> getToken() async {
    if (_cachedToken != null) return _cachedToken!;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_keyToken) ?? '';
    return _cachedToken!;
  }

  /// 保存配置
  static Future<void> save({required String host, required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, host);
    await prefs.setString(_keyToken, token);
    _cachedHost = host;
    _cachedToken = token;
  }

  /// 获取完整 WebSocket URL
  static Future<Uri> getWsUrl() async {
    final host = await getHost();
    final token = await getToken();
    return Uri.parse('ws://$host:8000/chat?token=$token');
  }

  /// 获取完整 HTTP Base URL
  static Future<String> getBaseUrl() async {
    final host = await getHost();
    return 'http://$host:8000';
  }

  /// 检查是否已配置
  static Future<bool> isConfigured() async {
    final host = await getHost();
    final token = await getToken();
    return host.isNotEmpty && token.isNotEmpty;
  }
}

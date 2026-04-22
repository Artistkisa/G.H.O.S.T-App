import 'package:shared_preferences/shared_preferences.dart';

/// 本地配置管理（服务器地址、Token）
class ConfigService {
  static const String _keyHost = 'ghost_host';
  static const String _keyToken = 'ghost_token';

  static String? _cachedHost;
  static String? _cachedToken;

  /// 获取原始服务器地址
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

  /// 清理用户输入的 host：去掉协议前缀、末尾斜杠
  static String _cleanHost(String raw) {
    var h = raw.trim();
    if (h.startsWith('http://')) h = h.substring(7);
    if (h.startsWith('https://')) h = h.substring(8);
    if (h.startsWith('ws://')) h = h.substring(5);
    if (h.startsWith('wss://')) h = h.substring(6);
    if (h.endsWith('/')) h = h.substring(0, h.length - 1);
    return h;
  }

  /// 解析 host:port，默认端口 8000
  static (String host, int port) _parseHostPort(String raw) {
    final cleaned = _cleanHost(raw);
    if (cleaned.contains(':')) {
      final parts = cleaned.split(':');
      return (parts[0], int.tryParse(parts[1]) ?? 8000);
    }
    return (cleaned, 8000);
  }

  /// 获取完整 WebSocket URL
  static Future<Uri> getWsUrl() async {
    final hostRaw = await getHost();
    final token = await getToken();
    final (host, port) = _parseHostPort(hostRaw);
    return Uri.parse('ws://$host:$port/chat?token=$token');
  }

  /// 获取完整 HTTP Base URL
  static Future<String> getBaseUrl() async {
    final hostRaw = await getHost();
    final (host, port) = _parseHostPort(hostRaw);
    return 'http://$host:$port';
  }

  /// 检查是否已配置
  static Future<bool> isConfigured() async {
    final host = await getHost();
    final token = await getToken();
    return host.isNotEmpty && token.isNotEmpty;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';
import 'config_service.dart';

/// Ghost WebSocket 连接管理 + 消息协议解析
class GhostWebSocket {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Message>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Message> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// 连接 WebSocket
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final wsUrl = await ConfigService.getWsUrl();
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;
      _connectionController.add(true);

      _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          _isConnected = false;
          _connectionController.add(false);
        },
        onDone: () {
          _isConnected = false;
          _connectionController.add(false);
        },
      );
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  /// 断开连接
  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    _connectionController.add(false);
  }

  /// 发送用户消息
  void sendMessage(String text, {List<String>? images}) {
    if (!_isConnected) return;

    final payload = jsonEncode({
      'text': text,
      if (images != null && images.isNotEmpty) 'images': images,
    });
    _channel!.sink.add(payload);
  }

  /// 解析后端消息
  void _onMessage(dynamic raw) {
    final data = raw.toString();

    // 1. reasoning 思考过程
    if (data.startsWith('__GHOST_REASONING__')) {
      final text = data.substring('__GHOST_REASONING__'.length);
      _messageController.add(Message(
        id: _uuid(),
        role: MessageRole.reasoning,
        text: text,
      ));
      return;
    }

    // 2. 工具调用消息
    if (data.startsWith('__GHOST_TOOL__')) {
      final jsonStr = data.substring('__GHOST_TOOL__'.length);
      try {
        final tool = jsonDecode(jsonStr) as Map<String, dynamic>;
        final phase = tool['phase'] == 'start' ? ToolPhase.start : ToolPhase.end;
        _messageController.add(Message(
          id: _uuid(),
          role: MessageRole.tool,
          toolName: tool['name'] as String?,
          toolArguments: tool['arguments'] as String?,
          toolResult: tool['result'] as String?,
          toolDurationMs: tool['duration_ms'] as int?,
          toolPhase: phase,
          text: tool['name'] as String?,
        ));
      } catch (_) {}
      return;
    }

    // 3. 深度搜索进度
    if (data.startsWith('__GHOST_DEEP_SEARCH__')) {
      final jsonStr = data.substring('__GHOST_DEEP_SEARCH__'.length);
      try {
        final ds = jsonDecode(jsonStr) as Map<String, dynamic>;
        _messageController.add(Message(
          id: _uuid(),
          role: MessageRole.system,
          isDeepSearch: true,
          deepSearchProgress: (ds['progress'] as num?)?.toDouble(),
          text: ds['message'] as String?,
        ));
      } catch (_) {}
      return;
    }

    // 4. 普通文本消息
    _messageController.add(Message(
      id: _uuid(),
      role: MessageRole.ghost,
      text: data,
    ));
  }

  String _uuid() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_random(10000)}';
  }

  int _random(int max) => DateTime.now().microsecond % max;
}

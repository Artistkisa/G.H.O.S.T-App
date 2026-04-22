import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/message.dart';
import '../services/ghost_api.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/tool_card.dart';
import '../widgets/reasoning_panel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isConnected = true; // SSE 是短连接，每次请求独立
  bool _isReasoning = false;
  String _currentReasoning = '';
  bool _isSending = false;
  StreamSubscription? _sseSub;

  @override
  void dispose() {
    _sseSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    setState(() {
      switch (type) {
        case 'reasoning':
          _isReasoning = true;
          _currentReasoning = event['text'] as String? ?? '';
          break;
        case 'tool_start':
          _messages.add(Message(
            id: _uuid(),
            role: MessageRole.tool,
            toolName: event['name'] as String?,
            toolArguments: event['arguments'] as String?,
            toolPhase: ToolPhase.start,
            text: event['name'] as String?,
          ));
          break;
        case 'tool_end':
          _messages.add(Message(
            id: _uuid(),
            role: MessageRole.tool,
            toolName: event['name'] as String?,
            toolResult: event['result'] as String?,
            toolDurationMs: event['duration_ms'] as int?,
            toolPhase: ToolPhase.end,
            text: event['name'] as String?,
          ));
          break;
        case 'text':
          _messages.add(Message(
            id: _uuid(),
            role: MessageRole.ghost,
            text: event['text'] as String? ?? '',
          ));
          _isReasoning = false;
          _currentReasoning = '';
          break;
        case 'done':
          _isSending = false;
          break;
      }
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(Message(
        id: _uuid(),
        role: MessageRole.user,
        text: text,
      ));
      _isSending = true;
      _isReasoning = false;
      _currentReasoning = '';
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final stream = GhostApi.streamChat(text);
      _sseSub = stream.listen(
        _onEvent,
        onError: (e) {
          setState(() {
            _isSending = false;
            _messages.add(Message(
              id: _uuid(),
              role: MessageRole.ghost,
              text: '[连接错误] $e',
            ));
          });
          _scrollToBottom();
        },
        onDone: () {
          setState(() => _isSending = false);
        },
      );
    } catch (e) {
      setState(() {
        _isSending = false;
        _messages.add(Message(
          id: _uuid(),
          role: MessageRole.ghost,
          text: '[错误] $e',
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final result = await GhostApi.uploadImage(picked.path);
      if (result['url'] != null) {
        final url = result['url'] as String;
        _sendWithImages('[上传图片] $url', images: [url]);
      }
    } catch (e) {
      _showSnackBar('上传失败: $e');
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    try {
      final uploadResult = await GhostApi.uploadFile(result.files.single.path!);
      if (uploadResult['path'] != null) {
        final path = uploadResult['path'] as String;
        final name = result.files.single.name;
        _sendWithImages('[上传文件: $name] 路径: $path');
      }
    } catch (e) {
      _showSnackBar('上传失败: $e');
    }
  }

  Future<void> _sendWithImages(String text, {List<String>? images}) async {
    if (_isSending) return;

    setState(() {
      _messages.add(Message(
        id: _uuid(),
        role: MessageRole.user,
        text: text,
      ));
      _isSending = true;
      _isReasoning = false;
      _currentReasoning = '';
    });
    _scrollToBottom();

    try {
      final stream = GhostApi.streamChat(text, images: images);
      _sseSub = stream.listen(
        _onEvent,
        onError: (e) {
          setState(() {
            _isSending = false;
            _messages.add(Message(
              id: _uuid(),
              role: MessageRole.ghost,
              text: '[连接错误] $e',
            ));
          });
          _scrollToBottom();
        },
        onDone: () => setState(() => _isSending = false),
      );
    } catch (e) {
      setState(() {
        _isSending = false;
        _messages.add(Message(
          id: _uuid(),
          role: MessageRole.ghost,
          text: '[错误] $e',
        ));
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  String _uuid() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_random(10000)}';
  }

  int _random(int max) => DateTime.now().microsecond % max;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('G.H.O.S.T'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isSending ? Colors.orange : Colors.green,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length + (_isReasoning ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isReasoning && index == _messages.length) {
                  return ReasoningPanel(reasoning: _currentReasoning);
                }
                final msg = _messages[index];
                if (msg.role == MessageRole.tool) {
                  return ToolCard(message: msg);
                }
                return ChatBubble(message: msg);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: _isSending ? null : _pickImage,
            ),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _isSending ? null : _pickFile,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                  border: InputBorder.none,
                ),
                enabled: !_isSending,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

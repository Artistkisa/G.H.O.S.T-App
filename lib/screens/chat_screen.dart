import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/message.dart';
import '../services/ghost_ws.dart';
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
  final GhostWebSocket _ws = GhostWebSocket();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isConnected = false;
  bool _isReasoning = false;
  String _currentReasoning = '';

  @override
  void initState() {
    super.initState();
    _initConnection();
    _ws.connectionStream.listen((connected) {
      setState(() => _isConnected = connected);
    });
    _ws.messageStream.listen(_onMessage);
  }

  Future<void> _initConnection() async {
    final ok = await _ws.connect();
    if (!ok && mounted) {
      _showSnackBar('连接服务器失败，请检查设置');
    }
  }

  @override
  void dispose() {
    _ws.disconnect();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessage(Message msg) {
    setState(() {
      if (msg.role == MessageRole.reasoning) {
        _isReasoning = true;
        _currentReasoning = msg.text ?? '';
      } else {
        _messages.add(msg);
        if (msg.role == MessageRole.ghost) {
          _isReasoning = false;
          _currentReasoning = '';
        }
      }
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (!_ws.isConnected) {
      _showSnackBar('未连接到服务器，请检查网络或重新配置');
      return;
    }

    setState(() {
      _messages.add(Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.user,
        text: text,
      ));
    });

    _ws.sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final result = await GhostApi.uploadImage(picked.path);
      if (result['url'] != null) {
        final url = result['url'] as String;
        _ws.sendMessage('[上传图片] $url', images: [url]);
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
        _ws.sendMessage('[上传文件: $name] 路径: $path');
      }
    } catch (e) {
      _showSnackBar('上传失败: $e');
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
              color: _isConnected ? Colors.green : Colors.red,
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
              onPressed: _pickImage,
            ),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickFile,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: '输入消息...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

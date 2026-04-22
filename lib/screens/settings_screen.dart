import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/ghost_ws.dart';
import 'chat_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hostController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLoading = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final host = await ConfigService.getHost();
    final token = await ConfigService.getToken();
    setState(() {
      _hostController.text = host;
      _tokenController.text = token;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final token = _tokenController.text.trim();

    if (host.isEmpty || token.isEmpty) {
      _showSnackBar('服务器地址和 Token 不能为空');
      return;
    }

    await ConfigService.save(host: host, token: token);

    setState(() => _isConnecting = true);

    // 测试连接
    final ws = GhostWebSocket();
    final connected = await ws.connect();
    ws.disconnect();

    setState(() => _isConnecting = false);

    if (!connected) {
      _showSnackBar('连接失败，请检查服务器地址、端口和 Token 是否正确');
      return;
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('服务器配置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '连接到你的 Ghost',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '输入服务器地址和访问 Token，信息仅保存在本地。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: '例如: 192.168.1.100 或 ghost.example.com',
                      prefixIcon: Icon(Icons.dns),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Token',
                      hintText: '例如: your-token',
                      prefixIcon: Icon(Icons.key),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isConnecting ? null : _save,
                      child: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('保存并连接'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Ghost 消息模型
enum MessageRole {
  user,      // 用户发送
  ghost,     // Ghost 回复文本
  reasoning, // thinking 过程
  tool,      // 工具调用
  system,    // 系统提示
}

enum ToolPhase { start, end }

class Message {
  final String id;
  final MessageRole role;
  final String? text;
  final DateTime timestamp;

  // 工具相关
  final String? toolName;
  final String? toolArguments;
  final String? toolResult;
  final int? toolDurationMs;
  final ToolPhase? toolPhase;

  // 深度搜索
  final bool? isDeepSearch;
  final double? deepSearchProgress;

  Message({
    required this.id,
    required this.role,
    this.text,
    DateTime? timestamp,
    this.toolName,
    this.toolArguments,
    this.toolResult,
    this.toolDurationMs,
    this.toolPhase,
    this.isDeepSearch,
    this.deepSearchProgress,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isToolStart => role == MessageRole.tool && toolPhase == ToolPhase.start;
  bool get isToolEnd => role == MessageRole.tool && toolPhase == ToolPhase.end;
}

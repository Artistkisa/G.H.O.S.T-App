import 'package:flutter/material.dart';
import '../models/message.dart';

class ToolCard extends StatelessWidget {
  final Message message;

  const ToolCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isStart = message.isToolStart;
    final isEnd = message.isToolEnd;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 48),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isStart
            ? Colors.blue.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isStart ? Colors.blue.withOpacity(0.3) : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isStart ? Icons.play_circle_outline : Icons.check_circle_outline,
                size: 16,
                color: isStart ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: 6),
              Text(
                message.toolName ?? '工具',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isStart ? Colors.blue : Colors.green,
                ),
              ),
              if (isEnd && message.toolDurationMs != null)
                Text(
                  '  ${message.toolDurationMs}ms',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          if (message.toolArguments != null && message.toolArguments!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '参数: ${message.toolArguments}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (isEnd && message.toolResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message.toolResult!,
                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

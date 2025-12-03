// ABOUTME: Reusable result display widget for demo app
// ABOUTME: Shows success/error states and formatted output

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class ResultDisplay extends StatelessWidget {
  final String? title;
  final String content;
  final bool isError;
  final bool copyable;

  const ResultDisplay({
    super.key,
    this.title,
    required this.content,
    this.isError = false,
    this.copyable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? AppTheme.errorRed.withValues(alpha: 0.5) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (isError)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.error_outline,
                          color: AppTheme.errorRed, size: 18),
                    ),
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isError
                              ? AppTheme.errorRed
                              : AppTheme.textPrimary,
                        ),
                  ),
                  const Spacer(),
                  if (copyable)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      color: AppTheme.textSecondary,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: isError ? AppTheme.errorRed : AppTheme.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class KeyValueDisplay extends StatelessWidget {
  final Map<String, String> data;

  const KeyValueDisplay({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: data.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    entry.value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

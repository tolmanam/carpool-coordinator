import 'package:flutter/material.dart';
import '../config/app_info.dart';

void showAboutAppDialog(BuildContext context) {
  final theme = Theme.of(context);

  showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('About ${AppInfo.appName}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(context, 'App Name', AppInfo.appName),
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Version', AppInfo.appVersion),
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Release / Tag', AppInfo.gitTag),
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                'Git Commit',
                AppInfo.gitCommit != 'Dev Build'
                    ? '${AppInfo.shortGitCommit} (${AppInfo.gitCommit})'
                    : AppInfo.gitCommit,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Build Date', AppInfo.buildDate),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Widget _buildInfoRow(BuildContext context, String label, String value) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
      SelectableText(
        value,
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface,
        ),
      ),
    ],
  );
}

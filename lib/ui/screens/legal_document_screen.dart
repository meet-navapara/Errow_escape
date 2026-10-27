import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_info.dart';
import '../../core/legal/legal_content.dart';
import '../../core/theme/app_colors.dart';

/// Renders a [LegalDocument] in the app so it is readable offline. The same
/// text is published on the web (see hosting/README.md).
class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final url = '${AppInfo.hostingBase}/${document.slug}';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(document.title)),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              document.summary,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            for (final s in document.sections) ...[
              const SizedBox(height: 20),
              Text(
                s.heading,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              for (final p in s.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    p,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Web link copied')),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(url, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

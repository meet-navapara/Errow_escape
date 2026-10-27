import 'package:flutter/material.dart';

import '../../core/legal/legal_content.dart';
import 'legal_document_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const LegalDocumentScreen(document: LegalContent.privacy);
}

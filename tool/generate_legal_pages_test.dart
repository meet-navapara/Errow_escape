// Renders the legal documents in lib/core/legal/legal_content.dart to static
// HTML for Firebase Hosting. Run from the project root:
//
//   flutter test tool/generate_legal_pages_test.dart
//
// Then deploy as described in hosting/README.md.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/core/app_info.dart';
import 'package:arrow_escape/core/legal/legal_content.dart';

const _esc = HtmlEscape();

String _linkify(String text) => _esc
    .convert(text)
    .replaceAllMapped(
      RegExp(r'https://[^\s<]+[^\s<.,)]'),
      (m) => '<a href="${m[0]}">${m[0]}</a>',
    );

String page(String title, String description, String body) =>
    '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc.convert(title)} · ${AppInfo.name}</title>
<meta name="description" content="${_esc.convert(description)}">
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<header><a class="brand" href="/">${AppInfo.name}</a></header>
<main>
$body
</main>
<footer>
<nav><a href="/privacy">Privacy Policy</a> · <a href="/terms">Terms of Service</a> · <a href="/delete-account">Delete account</a></nav>
</footer>
</body>
</html>
''';

String render(LegalDocument doc) {
  final b = StringBuffer()
    ..writeln('<h1>${_esc.convert(doc.title)}</h1>')
    ..writeln('<p class="summary">${_linkify(doc.summary)}</p>');
  for (final s in doc.sections) {
    b.writeln('<h2>${_esc.convert(s.heading)}</h2>');
    for (final p in s.paragraphs) {
      b.writeln('<p>${_linkify(p)}</p>');
    }
  }
  return page(doc.title, doc.summary, b.toString());
}

void main() {
  test('generate legal pages', () {
    final out = Directory('hosting/public')..createSync(recursive: true);
    for (final doc in LegalContent.all) {
      File('${out.path}/${doc.slug}.html').writeAsStringSync(render(doc));
    }
    File('${out.path}/index.html').writeAsStringSync(
      page(
        AppInfo.name,
        'Arrow Escape puzzle game: legal information and support.',
        '''<h1>${AppInfo.name}</h1>
<p class="summary">Clear the path. Escape every arrow.</p>
<ul>
<li><a href="/privacy">Privacy Policy</a></li>
<li><a href="/terms">Terms of Service</a></li>
<li><a href="/delete-account">Delete your account</a></li>
</ul>
<p>Support: ${_esc.convert(AppInfo.supportEmail)}</p>''',
      ),
    );
    File('${out.path}/404.html').writeAsStringSync(
      page(
        'Not found',
        'Page not found',
        '<h1>Page not found</h1><p><a href="/">Home</a></p>',
      ),
    );
    for (final doc in LegalContent.all) {
      expect(File('${out.path}/${doc.slug}.html').existsSync(), isTrue);
    }
  });
}

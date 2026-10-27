/// Single source for the Privacy Policy, Terms of Service and account
/// deletion page. Shown in the app and rendered to hosting/public/*.html by
/// tool/generate_legal_pages_test.dart, so both always match.
///
/// Update [LegalContent.effectiveDate] whenever the text changes, then
/// regenerate the pages. These documents describe the app as built; they are not legal advice and should be
/// reviewed by a qualified professional for your jurisdiction.
library;

import '../app_info.dart';

class LegalSection {
  final String heading;
  final List<String> paragraphs;
  const LegalSection(this.heading, this.paragraphs);
}

class LegalDocument {
  final String title;
  final String slug;
  final String summary;
  final List<LegalSection> sections;
  const LegalDocument({
    required this.title,
    required this.slug,
    required this.summary,
    required this.sections,
  });
}

class LegalContent {
  static const developer = 'Meet Navapara';
  static const contactEmail = AppInfo.supportEmail;
  static const effectiveDate = '27 October 2026';
  static const jurisdiction = 'India';

  static const privacy = LegalDocument(
    title: 'Privacy Policy',
    slug: 'privacy',
    summary:
        'Arrow Escape works without an account. If you sign in with Google, '
        'your game progress is backed up to your private cloud record. Ads '
        'appear only if you choose to watch one for a reward.',
    sections: [
      LegalSection('Who we are', [
        'Arrow Escape ("the Game") is published by $developer ("we", "us"). '
            'Contact: $contactEmail.',
        'Effective date: $effectiveDate.',
      ]),
      LegalSection('Information stored on your device', [
        'The Game saves your progress on your device: unlocked and completed '
            'levels, daily and weekly challenge results, achievements, '
            'tutorial progress, power-up balances and your sound and '
            'vibration settings.',
        'In guest mode the Game creates a random guest identifier that stays '
            'on your device. Guest data is not sent to us.',
      ]),
      LegalSection('If you sign in with Google', [
        'Sign-in is optional and uses Google Sign-In and Firebase '
            'Authentication (provided by Google LLC). We receive your Google '
            'account name, email address, profile photo link and a unique '
            'user ID. Firebase may also process technical data such as IP '
            'address and sign-in times to provide and secure sign-in.',
        'Your game progress (the items listed above, plus record timestamps) '
            'is stored in Google Cloud Firestore in a record that only your '
            'signed-in account can read or change. We use it only to back up '
            'your progress and restore it on your devices.',
      ]),
      LegalSection('Advertising', [
        'The Game uses Google AdMob to offer optional rewarded ads: you may '
            'choose to watch an ad to earn an extra power-up. No ad is '
            'required to play or finish a level.',
        'AdMob and its partners may collect device identifiers (such as the '
            'Android Advertising ID or Apple IDFA where permitted), IP '
            'address, approximate location derived from it, and interaction '
            'and diagnostic data to deliver, measure and limit fraud on ads. '
            'See https://policies.google.com/technologies/partner-sites.',
        'Where required (for example in the EEA, UK and Switzerland) the Game '
            'asks for your consent through Google\'s consent message before '
            'ads are requested. You can review your choice at any time in '
            'Me > Privacy Preferences.',
      ]),
      LegalSection('What we do not do', [
        'The Game does not include analytics or crash-reporting SDKs, does '
            'not sell personal information, does not offer in-app purchases '
            'and does not request access to your contacts, photos, camera, '
            'microphone or precise location.',
      ]),
      LegalSection('Service providers', [
        'Google LLC (Firebase Authentication, Cloud Firestore, Firebase '
            'Hosting, Google Sign-In, AdMob and the User Messaging Platform). '
            'Google processes data under its own terms and privacy policy: '
            'https://policies.google.com/privacy.',
      ]),
      LegalSection('Retention and deletion', [
        'Device data stays until you delete it (Settings > Reset Progress), '
            'clear the app\'s storage or uninstall the Game.',
        'Cloud data is kept while your account exists. You can delete your '
            'account in the Game at Settings > Delete Account & Cloud Data, '
            'which permanently deletes your cloud progress record and your '
            'Arrow Escape sign-in account and wipes the Game\'s data on that '
            'device. You can also request deletion without the app: see '
            '${AppInfo.deleteAccountUrl}. Google may keep limited logs for '
            'security and legal purposes as described in its policies.',
      ]),
      LegalSection('Security', [
        'Cloud data is transferred over encrypted connections and protected '
            'by access rules that allow only your account to access your '
            'record. No method of storage or transmission is completely '
            'secure, and we cannot guarantee absolute security.',
      ]),
      LegalSection('Children', [
        'The Game is not directed at children under 13 (or the minimum age '
            'in your country) and we do not knowingly collect their personal '
            'information. If you believe a child has given us personal '
            'information, contact $contactEmail and we will delete it.',
      ]),
      LegalSection('Your rights', [
        'Depending on where you live, you may have the right to access, '
            'correct, delete or export your personal information, or to '
            'object to or restrict its processing. Contact $contactEmail. '
            'You may also complain to your local data protection authority.',
      ]),
      LegalSection('Changes', [
        'We will update this policy if our practices change and revise the '
            'effective date above. Significant changes will be announced in '
            'the Game.',
      ]),
    ],
  );

  static const terms = LegalDocument(
    title: 'Terms of Service',
    slug: 'terms',
    summary:
        'Play fair, enjoy the puzzles, and remember power-ups are in-game '
        'items with no money value.',
    sections: [
      LegalSection('Agreement', [
        'These terms are an agreement between you and $developer for your use '
            'of Arrow Escape. By playing you accept them. Effective date: '
            '$effectiveDate.',
      ]),
      LegalSection('Using the Game', [
        'We grant you a personal, non-transferable, non-exclusive licence to '
            'play the Game for non-commercial use on devices you own or '
            'control.',
        'You agree not to cheat, reverse engineer, interfere with the '
            'Game\'s services or security, tamper with saved data to obtain '
            'rewards, or use the Game unlawfully.',
      ]),
      LegalSection('Accounts', [
        'An account is optional. If you sign in with Google you are '
            'responsible for keeping access to that Google account secure. '
            'You can delete your Arrow Escape account at any time in '
            'Settings.',
      ]),
      LegalSection('Power-ups and rewards', [
        'Hints, erasers, magic wands, path scanners, scores, achievements and '
            'trophies are virtual items with no monetary value. They cannot '
            'be sold, transferred or exchanged for money, and may be '
            'adjusted, for example to fix errors or abuse.',
      ]),
      LegalSection('Advertising', [
        'Rewarded ads are always optional. A reward is granted only when the '
            'ad provider confirms the ad was completed. Ads are provided by '
            'third parties, and we are not responsible for their content.',
      ]),
      LegalSection('Availability', [
        'The Game is provided "as is". Online features (sign-in, cloud '
            'backup, ads) may sometimes be unavailable. We may change or '
            'discontinue features. Offline play keeps working without them.',
      ]),
      LegalSection('Intellectual property', [
        'The Game, its puzzles, artwork, logo and code belong to $developer '
            'or its licensors. Open-source components are listed in About '
            'Game > Open-source licenses.',
      ]),
      LegalSection('Liability', [
        'To the extent permitted by law, we are not liable for indirect or '
            'consequential losses, or for loss of in-game progress or items. '
            'Nothing in these terms limits rights you have under consumer '
            'protection laws that cannot be waived.',
      ]),
      LegalSection('Governing law and changes', [
        'These terms are governed by the laws of $jurisdiction, except where '
            'your local law requires otherwise. We may update these terms '
            'and will revise the effective date; continuing to play means '
            'you accept the updated terms.',
      ]),
      LegalSection('Contact', ['Questions: $contactEmail.']),
    ],
  );

  static const deleteAccount = LegalDocument(
    title: 'Delete your Arrow Escape account',
    slug: 'delete-account',
    summary:
        'How to delete your Arrow Escape account and the data associated '
        'with it, published by $developer.',
    sections: [
      LegalSection('In the app (fastest)', [
        'Open Arrow Escape, go to Me > Settings > Delete Account & Cloud '
            'Data and confirm with your Google account. This immediately and '
            'permanently deletes your cloud progress record and your Arrow '
            'Escape sign-in account, and wipes the Game\'s data on that '
            'device.',
      ]),
      LegalSection('Without the app', [
        'Email $contactEmail from the address of your Google account with '
            'the subject "Delete my Arrow Escape account". We will delete '
            'your account and its cloud data within 30 days and confirm by '
            'email.',
      ]),
      LegalSection('What is deleted', [
        'Your sign-in account (name, email, user ID) and your cloud progress '
            'record: levels, daily and weekly results, achievements, '
            'tutorial progress, power-up balances, settings and timestamps.',
        'Guest progress stored only on a device is removed by uninstalling '
            'the Game or clearing its storage.',
        'Google may retain limited security and legal logs as described in '
            'its own policies.',
      ]),
    ],
  );

  static const all = [privacy, terms, deleteAccount];
}

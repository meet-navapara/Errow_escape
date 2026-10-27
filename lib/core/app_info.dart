/// App metadata shown in About/Settings. Kept in sync with pubspec.yaml by
/// test/app_info_test.dart.
class AppInfo {
  static const String name = 'Arrow Escape';
  static const String version = '1.0.0';
  static const int buildNumber = 1;

  /// Public legal pages (Firebase Hosting, see hosting/README.md). These are
  /// the default Hosting URLs for the Firebase project in
  /// android/app/google-services.json; they only work after deployment.
  static const String hostingBase = 'https://arrow-escape-85dcd.web.app';
  static const String privacyUrl = '$hostingBase/privacy';
  static const String termsUrl = '$hostingBase/terms';
  static const String deleteAccountUrl = '$hostingBase/delete-account';

  /// Public support and data-request contact.
  static const String supportEmail = 'meet56256@gmail.com';
}

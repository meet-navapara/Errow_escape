# Arrow Escape legal pages (Firebase Hosting)

Static pages for the Privacy Policy, Terms of Service and account-deletion
instructions. They are **generated** from `lib/core/legal/legal_content.dart`,
the same text the app shows, so the app and the web never disagree.

```
hosting/public/
  index.html            landing page with links
  privacy.html          -> https://<project>.web.app/privacy
  terms.html            -> https://<project>.web.app/terms
  delete-account.html   -> https://<project>.web.app/delete-account
  404.html, styles.css
```

`firebase.json` serves `hosting/public` with clean URLs (no `.html`).

## 1. Developer details

Set in `lib/core/legal/legal_content.dart` and `lib/core/app_info.dart`:
developer Meet Navapara, support meet56256@gmail.com, effective date
27 October 2026, governing law India. After any text change, bump the
effective date and regenerate the HTML and check nothing is left:

```bash
flutter test tool/generate_legal_pages_test.dart
grep -n "\[" hosting/public/*.html   # must print nothing
flutter test test/progression_test.dart   # checks pages match the app text
```

Have the documents reviewed by someone qualified for your jurisdiction; they
describe the app as built but are not legal advice.

## 2. Deploy

Requires Node.js. Nothing has been deployed yet.

```bash
npm install -g firebase-tools        # or prefix each command with: npx firebase-tools
firebase login
firebase projects:list               # confirm the project you intend to use
firebase use --add                   # select it; android/app/google-services.json
                                     # currently points at arrow-escape-85dcd
firebase deploy --only hosting
```

Firebase prints the live URLs, normally `https://<project-id>.web.app`.
Open each page in a browser and confirm it loads before using it anywhere.

If your project id is not `arrow-escape-85dcd`, or you attach a custom
domain, update `AppInfo.hostingBase` in `lib/core/app_info.dart`.

## 3. Use the URLs

- Google Play Console: App content > Privacy policy = `/privacy`;
  Data safety > account deletion URL = `/delete-account`.
- App Store Connect: App Privacy > Privacy Policy URL = `/privacy`.
- The app already links to the same pages (Me > Privacy Policy / Terms).

## Firestore rules

The same `firebase.json` deploys the security rules:

```bash
firebase deploy --only firestore:rules
```

Test them first against the local emulator (Java required):

```bash
cd firebase/rules-test
npm install
npm test
```

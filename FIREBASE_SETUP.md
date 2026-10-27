# Firebase, Google Sign-In and AdMob setup

What is already done in code, and the console steps only you can do.

## Current state (verified 2026-10-27)

| Item | Status |
| --- | --- |
| `Firebase.initializeApp()` in `lib/main.dart` | Done. Previously missing, so sign-in and sync never ran. |
| Google Services Gradle plugin | Applied (`android/settings.gradle.kts`, `android/app/build.gradle.kts`) |
| `android/app/google-services.json` | Present (project `arrow-escape-85dcd`, package `com.arrowescape.arrow_escape`) |
| Android debug build | Built; on a real device logcat shows `FirebaseApp initialization successful` |
| Google sign-in on Android | Code complete; **not yet tested end-to-end** (needs SHA fingerprints, below) |
| iOS Firebase / Google sign-in | **Not configured**: `GoogleService-Info.plist` and URL scheme missing |
| Firestore rules | Written and tested in the emulator (6 tests); **not deployed** |

If Firebase can't initialize (e.g. iOS before setup), the app runs fully
offline in guest mode and the sign-in button explains why it is unavailable.

## How accounts work

- **Guest**: no Firebase account is created (no anonymous auth). Progress is
  saved only on the device under a random local guest id.
- **Google**: Google Sign-In -> Firebase Authentication. On sign-in, the
  device's guest progress is merged into the account (never discarded) and
  saved to `users/{uid}` in Firestore.
- **Sync**: `CloudSyncService` merges local and cloud copies inside a
  Firestore transaction (rules in `ProgressSnapshot.merge`: max/union, never
  backwards), debounced ~4 s after changes, with retry/backoff while offline.
- **Delete account**: re-authenticates with Google, deletes `users/{uid}`,
  deletes the Firebase user, then wipes local data.

## 1. Android: register signing fingerprints (required for Google sign-in)

Google sign-in fails with `ApiException: 10` (shown in the app as "not
configured for this build") until the SHA-1 and SHA-256 of **every** key
that signs the app are registered:

```bash
cd android
./gradlew signingReport          # debug key + your upload key
```

Firebase Console > Project settings > Your apps > Android app > Add
fingerprint: add debug SHA-1/SHA-256 and your upload-key SHA-1/SHA-256.
After uploading to Play, also add the **App signing key** fingerprints from
Play Console > Setup > App integrity. Then download the updated
`google-services.json` into `android/app/`.

## 2. iOS

1. Firebase Console > Add app > iOS, bundle id `com.arrowescape.arrowEscape`.
2. Download `GoogleService-Info.plist` and add it to `ios/Runner` **in Xcode**
   (Runner target, "Copy items if needed").
3. In `ios/Runner/Info.plist` add the URL scheme from the plist's
   `REVERSED_CLIENT_ID`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array><dict>
     <key>CFBundleURLSchemes</key>
     <array><string>com.googleusercontent.apps.YOUR-REVERSED-CLIENT-ID</string></array>
   </dict></array>
   ```
4. `cd ios && pod install`, then test sign-in on a physical iPhone.

(Optionally run `flutterfire configure` to generate `lib/firebase_options.dart`;
the app currently relies on the native config files instead.)

## 3. Authentication and Firestore

1. Authentication > Sign-in method > enable **Google** and set the support
   email. Anonymous sign-in is **not** used.
2. Firestore Database > create in **production mode**.
3. Deploy and test the rules (see `hosting/README.md`):
   ```bash
   cd firebase/rules-test && npm install && npm test   # emulator tests
   cd ../.. && firebase deploy --only firestore:rules
   ```
4. Google Cloud Console > OAuth consent screen: app name "Arrow Escape",
   support email, privacy policy URL, scopes `email` and `profile`;
   publish it (move out of "Testing") before release.

## 4. AdMob (optional rewarded ads)

Currently uses Google's **test** ids (debug builds only). Release builds show
no ads until real ids are supplied:

1. Create an AdMob account and an app for Android and iOS; create one
   **Rewarded** ad unit per platform.
2. Android app id: build with `-PadmobAppId=ca-app-pub-XXX~YYY`
   (or edit the default in `android/app/build.gradle.kts`).
   iOS app id: replace `GADApplicationIdentifier` in `ios/Runner/Info.plist`.
3. Rewarded unit ids at build time:
   ```bash
   flutter build appbundle --release \
     --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXX/AAA \
     --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-XXX/BBB
   ```
4. AdMob > Privacy & messaging: create a **GDPR (European regulations)**
   consent message and, if you serve US states, a US state regulations
   message. Until this exists the UMP consent request fails (seen on the
   test device as `[UMP] consent update failed`) and ads stay unavailable,
   which is safe but means no rewarded ads.
5. Add `app-ads.txt` to your developer website as AdMob instructs.
6. Optional: AdMob server-side verification for rewards (stronger than
   client-side callbacks; see firestore.rules comment).

## 5. Manual test pass (on real devices)

- [ ] Guest: play offline (airplane mode), progress survives app restart.
- [ ] Google sign-in: success, cancel, no network, wrong SHA (expect clear messages).
- [ ] After sign-in: `users/{uid}` exists with `schemaVersion: 2`.
- [ ] Second device: sign in, progress merges; nothing regresses.
- [ ] Offline changes sync after reconnecting (Me tab shows status).
- [ ] Sign out keeps device progress; sign in again restores cloud copy.
- [ ] Delete account: Firestore doc and Auth user gone; app back to guest.
- [ ] Rewarded ad (test ids): reward only after completing the ad; closing early gives nothing.
- [ ] EEA test (UMP debug geography): consent form shows; Me > Privacy Preferences reopens it.

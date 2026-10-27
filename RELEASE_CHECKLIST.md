# Arrow Escape release checklist (Google Play and App Store)

Status as of 2026-10-27. Passing analysis and tests does **not** guarantee
store approval; each store reviews the submitted build itself.

## 1. Completed and verified

- [x] `flutter analyze`: no issues. `flutter test`: 155 tests pass
      (gameplay rules, solver/levels, hit testing/zoom, power-ups, rewarded-ad
      callback handling, tutorials, daily/weekly, achievements, sync merge and
      conflict policy, guest->Google migration, account deletion, layouts,
      the 1000-level catalogue, difficulty progression and progress migration).
- [x] Firestore rules: 8 emulator tests pass (`firebase/rules-test`): owner
      only, unauthenticated/other users denied, schema validated, progress and
      spent power-ups cannot go backwards, other collections closed.
- [x] Android debug APK builds; installed on a physical device; Firebase
      initializes (`FirebaseApp initialization successful`); no crash/ANR.
- [x] Target SDK 36 (Flutter default) - Google Play requires API 36 for new
      apps and updates from 31 Aug 2026. Min SDK 24.
- [x] App label "Arrow Escape"; original launcher icons (legacy + adaptive),
      iOS icon set (RGB, no alpha), Play 512 icon, App Store 1024 icon, Play
      feature graphic - `assets/branding/`.
- [x] In-app account deletion (Settings) and a deletion web page
      (`hosting/public/delete-account.html`, not yet deployed).
- [x] Privacy Policy and Terms in the app, generated to HTML from one source.
- [x] Rewarded ads are optional, never required to finish a level, reward only
      on the SDK reward callback, guarded against duplicate callbacks/taps.
- [x] No in-app purchases; no "Remove Ads" button (it would have no real flow).

## 2. Implemented but not yet tested

- [ ] Google sign-in end-to-end on Android (blocked on SHA fingerprints).
- [ ] Cloud sync against the real Firestore project (tested only with fakes
      and the emulator).
- [ ] Rewarded ads with the real AdMob SDK on a device (test ids configured;
      UMP consent request currently fails until a consent message exists).
- [ ] UMP consent form / Privacy Preferences in an EEA test geography.
- [ ] Release-mode build (`flutter build appbundle --release`) with real
      signing; release builds show no ads until real ad unit ids are passed.
- [ ] Gameplay walkthrough, level guides and power-up sheets on real devices
      (verified in widget tests; device screen was locked during the smoke test).
- [ ] iOS: nothing has been built or run (no macOS/Xcode available here).

## 3. Manual configuration tasks

Android / Play Console
- [ ] Create an upload keystore and `android/key.properties`
      (`build.gradle.kts` uses it automatically; never commit it):
      `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] Register debug, upload and Play app-signing SHA-1/SHA-256 in Firebase;
      re-download `google-services.json` (FIREBASE_SETUP.md).
- [ ] AdMob: real app ids and rewarded unit ids (FIREBASE_SETUP.md §4),
      GDPR / US-states consent messages, `app-ads.txt`.
- [ ] Deploy Hosting and Firestore rules (hosting/README.md); verify URLs load.
- [ ] **Redeploy Firestore rules for the 1000-level update before releasing it**
      (`firebase deploy --only firestore:rules`). Earlier rules capped
      `highestUnlockedLevel` at 101 and `completedLevels` at 100 entries, so
      cloud saves past level 100 would be rejected (local progress is kept).
      The new limits are covered by the emulator tests in `firebase/rules-test`.
- [ ] Play Console: Privacy policy URL, Data safety (below), account deletion
      URL, content rating questionnaire, target audience, ads declaration
      ("contains ads": yes), app access (no login needed to review).
- [ ] Capture real phone screenshots (at least 2; ideally 4-8) from a device.

Data safety form (based on the current build; confirm against SDK docs)
- Personal info - name, email: collected if user signs in; app functionality
  / account management; not shared; deletable.
- App activity / in-app progress: collected if signed in; app functionality.
- Device or other IDs (Advertising ID): collected by AdMob; advertising /
  fraud prevention. The merged manifest includes `com.google.android.gms.permission.AD_ID`.
- Diagnostics / approximate location via IP: processed by AdMob.
- Encrypted in transit: yes. Users can request deletion: yes (in app + URL).

iOS / App Store Connect
- [ ] Add `GoogleService-Info.plist`, Google URL scheme (FIREBASE_SETUP.md §2).
- [ ] Replace `GADApplicationIdentifier`; add Google's full SKAdNetwork list.
- [ ] Add an app `PrivacyInfo.xcprivacy` in Xcode (UserDefaults API reason
      `CA92.1`); SDK privacy manifests come with the pods.
- [ ] App Privacy "nutrition label" matching the Data safety answers above.
- [ ] Decide on App Tracking Transparency: the app does not request it, so
      ads are non-personalised on iOS unless you add an ATT prompt.
- [ ] Signing, capabilities, archive and TestFlight on a physical iPhone.

## 4. Developer decisions / legal review still needed

- [ ] **iOS Sign in with Apple (App Store blocker).** Guideline 4.8 requires an
      equivalent privacy-focused login (e.g. Sign in with Apple) when Google
      sign-in is offered. Either add Sign in with Apple (Firebase supports it;
      needs Apple Developer setup and a Mac to test) or hide Google sign-in on
      iOS and ship guest-only there.
- [x] Legal details filled in: developer Meet Navapara, support
      meet56256@gmail.com, effective 27 October 2026, governing law India.
      Pages regenerated.
- [ ] Have the Privacy Policy and Terms reviewed by a lawyer, including
      India's Digital Personal Data Protection Act 2023 and its Rules (e.g.
      whether a named grievance contact or other notice details are needed).
- [ ] Use the same developer name and email on the Play Console and App Store
      listings (Play checks the deletion page names the developer).
- [ ] Audience: the policy says the game is not directed at children under 13.
      If you target children (Play Families / Apple Kids), ads must be
      configured for child-directed treatment and the policy changed.
- [ ] Confirm the Firebase project (`arrow-escape-85dcd`) is the production one.
- [ ] Reward integrity: client-side callbacks plus rules make abuse harder but
      cannot prove an ad was watched; consider AdMob server-side verification.
- [ ] Interstitial ads are intentionally not shown (`AdService` hook only).
- [ ] Weekly challenge is personal/local; no global leaderboard (would need a
      trusted backend to validate scores).

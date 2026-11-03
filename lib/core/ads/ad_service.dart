import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// What happened when the player chose to watch a rewarded ad.
enum RewardedAdOutcome {
  /// The SDK confirmed the reward (onUserEarnedReward fired).
  rewarded,

  /// The ad showed but was closed before the reward was earned.
  dismissed,

  /// No ad could be loaded or shown (network, no fill, show error).
  failed,

  /// Ads are not available: not configured, unsupported platform, or the
  /// player has not given the consent needed to request ads.
  unavailable,
}

/// Abstraction over the rewarded-ad SDK so gameplay code and tests never
/// depend on AdMob directly.
abstract class RewardedAdProvider {
  /// Shows one rewarded ad. Completes exactly once.
  Future<RewardedAdOutcome> showRewarded();
}

/// Never shows ads. Used in tests and wherever ads are not configured.
class NoRewardedAds implements RewardedAdProvider {
  const NoRewardedAds();

  @override
  Future<RewardedAdOutcome> showRewarded() async =>
      RewardedAdOutcome.unavailable;
}

/// Google AdMob rewarded ads, gated by Google UMP consent.
///
/// The production unit is a **Rewarded interstitial** unit in AdMob, so it is
/// loaded with [RewardedInterstitialAd]; loading it as a plain rewarded ad
/// fails with a format mismatch. It is still only shown when the player
/// chooses to watch an ad, and the reward still requires the SDK callback.
///
/// Ad unit ids: debug builds use Google's public test ids. Release builds use
/// the production Android unit below, or ids passed with --dart-define
/// (ADMOB_REWARDED_ANDROID / ADMOB_REWARDED_IOS); without an id ads stay
/// unavailable instead of showing test ads in production.
class AdMobRewardedAds implements RewardedAdProvider {
  static const _testAndroid = 'ca-app-pub-3940256099942544/5354046379';
  static const _testIos = 'ca-app-pub-3940256099942544/6978759866';
  static const _releaseAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-1959480289882936/2000572174',
  );
  static const _releaseIos = String.fromEnvironment('ADMOB_REWARDED_IOS');

  static String? get adUnitId {
    if (kIsWeb) return null;
    final android = Platform.isAndroid;
    if (!android && !Platform.isIOS) return null;
    if (kReleaseMode) {
      final id = android ? _releaseAndroid : _releaseIos;
      return id.isEmpty ? null : id;
    }
    return android ? _testAndroid : _testIos;
  }

  /// Requests consent and initializes the SDK (see [AdMobSdk.ensureReady]).
  Future<void> initialize() async {
    if (adUnitId == null) return;
    await AdMobSdk.ensureReady();
  }

  @override
  Future<RewardedAdOutcome> showRewarded() async {
    final unitId = adUnitId;
    if (unitId == null) return RewardedAdOutcome.unavailable;
    if (!await AdMobSdk.ensureReady()) return RewardedAdOutcome.unavailable;

    final result = Completer<RewardedAdOutcome>();
    void finish(RewardedAdOutcome o) {
      if (!result.isCompleted) result.complete(o);
    }

    var earned = false;
    await RewardedInterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              finish(
                earned
                    ? RewardedAdOutcome.rewarded
                    : RewardedAdOutcome.dismissed,
              );
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              finish(RewardedAdOutcome.failed);
            },
          );
          ad.show(onUserEarnedReward: (_, _) => earned = true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdMob] rewarded failed to load: $error');
          finish(RewardedAdOutcome.failed);
        },
      ),
    );
    return result.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () => RewardedAdOutcome.failed,
    );
  }
}

/// Shared one-time AdMob start-up used by rewarded and interstitial ads.
class AdMobSdk {
  static Future<bool>? _ready;

  /// Requests consent info, shows the consent form when required (e.g.
  /// EEA/UK) and initializes the SDK if ads may be requested. A failed
  /// attempt is retried on the next call.
  static Future<bool> ensureReady() {
    return _ready ??= () async {
      try {
        await ConsentService.gatherConsent();
        if (!await ConsentInformation.instance.canRequestAds()) {
          debugPrint('[AdMob] consent does not allow ad requests yet');
          _ready = null;
          return false;
        }
        await MobileAds.instance.initialize();
        return true;
      } catch (e) {
        debugPrint('[AdMob] init failed: $e');
        _ready = null;
        return false;
      }
    }();
  }
}

/// Full-screen ad shown at a natural break between levels.
abstract class InterstitialAdProvider {
  /// Shows one interstitial if one is ready; completes when it is closed or
  /// immediately when none is available. Never throws.
  Future<void> show();
}

class NoInterstitialAds implements InterstitialAdProvider {
  const NoInterstitialAds();

  @override
  Future<void> show() async {}
}

/// Google AdMob interstitials. One ad is preloaded so it can appear
/// without a wait when the player moves on to the next level.
///
/// Debug builds use Google's public test id. Release builds use the
/// production unit below or --dart-define=ADMOB_INTERSTITIAL_ANDROID=...;
/// with no id, interstitials are simply skipped.
class AdMobInterstitialAds implements InterstitialAdProvider {
  static const _testAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _releaseAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-1959480289882936/5626351797',
  );
  static const _releaseIos = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');

  InterstitialAd? _loaded;
  bool _loading = false;

  static String? get adUnitId {
    if (kIsWeb) return null;
    final android = Platform.isAndroid;
    if (!android && !Platform.isIOS) return null;
    if (kReleaseMode) {
      final id = android ? _releaseAndroid : _releaseIos;
      return id.isEmpty ? null : id;
    }
    return android ? _testAndroid : _testIos;
  }

  /// Loads the next ad in the background if none is ready.
  Future<void> preload() async {
    final unitId = adUnitId;
    if (unitId == null || _loaded != null || _loading) return;
    if (!await AdMobSdk.ensureReady()) return;
    _loading = true;
    await InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _loaded = ad;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          debugPrint('[AdMob] interstitial failed to load: $error');
        },
      ),
    );
  }

  @override
  Future<void> show() async {
    final ad = _loaded;
    if (ad == null) {
      unawaited(preload());
      return;
    }
    _loaded = null;
    final closed = Completer<void>();
    void done() {
      if (!closed.isCompleted) closed.complete();
      unawaited(preload());
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        done();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdMob] interstitial failed to show: $error');
        ad.dispose();
        done();
      },
    );
    await ad.show();
    return closed.future.timeout(const Duration(minutes: 2), onTimeout: () {});
  }
}

/// Google User Messaging Platform (UMP) consent handling.
class ConsentService {
  static Future<void> gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) debugPrint('[UMP] form error: ${error.message}');
          if (!done.isCompleted) done.complete();
        });
      },
      (error) {
        debugPrint('[UMP] consent update failed: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  /// Whether the player must be offered a way to change ad consent.
  static Future<bool> privacyOptionsRequired() async {
    if (AdMobRewardedAds.adUnitId == null) return false;
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showPrivacyOptions() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('[UMP] options error: ${error.message}');
      done.complete();
    });
    return done.future;
  }
}

class AdService {
  /// The provider used by the game. main() installs AdMob on supported
  /// platforms; everywhere else (tests, desktop) no ads are shown.
  static RewardedAdProvider rewarded = const NoRewardedAds();

  /// Between-level ads; main() installs AdMob on supported platforms.
  static InterstitialAdProvider interstitial = const NoInterstitialAds();

  static int _levelsCompletedSinceLastAd = 0;
  static const int interstitialLevelInterval = 3;

  /// Called when the player taps "Next Level" in the campaign. Shows an
  /// interstitial after every [interstitialLevelInterval] completed levels,
  /// never during the tutorial levels 1-3. Completes once the ad is closed
  /// (or at once when no ad is shown).
  static Future<void> showInterstitialBetweenLevels(int completedLevel) async {
    if (completedLevel <= 3) return;
    _levelsCompletedSinceLastAd++;
    if (_levelsCompletedSinceLastAd < interstitialLevelInterval) return;
    _levelsCompletedSinceLastAd = 0;
    await interstitial.show();
  }

  /// Restarts the cadence; for tests.
  @visibleForTesting
  static void resetInterstitialCadence() => _levelsCompletedSinceLastAd = 0;
}

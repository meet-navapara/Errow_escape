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
/// Ad unit ids: debug builds use Google's public test ids. Release builds use
/// ids passed with --dart-define (ADMOB_REWARDED_ANDROID / ADMOB_REWARDED_IOS);
/// without them ads stay unavailable instead of showing test ads in
/// production.
class AdMobRewardedAds implements RewardedAdProvider {
  static const _testAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _releaseAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
  );
  static const _releaseIos = String.fromEnvironment('ADMOB_REWARDED_IOS');

  bool _initialized = false;

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

  /// Requests consent info and shows the consent form when required (e.g.
  /// EEA/UK), then initializes the SDK if ads may be requested.
  Future<void> initialize() async {
    if (adUnitId == null) return;
    try {
      await ConsentService.gatherConsent();
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
        _initialized = true;
      }
    } catch (e) {
      debugPrint('[AdMob] init failed: $e');
    }
  }

  @override
  Future<RewardedAdOutcome> showRewarded() async {
    final unitId = adUnitId;
    if (unitId == null) return RewardedAdOutcome.unavailable;
    if (!_initialized) {
      await initialize();
      if (!_initialized) return RewardedAdOutcome.unavailable;
    }

    final result = Completer<RewardedAdOutcome>();
    void finish(RewardedAdOutcome o) {
      if (!result.isCompleted) result.complete(o);
    }

    var earned = false;
    await RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
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

  static int _levelsCompletedSinceLastAd = 0;
  static const int interstitialLevelInterval = 3;

  /// Interstitial hook between levels. Interstitials are intentionally not
  /// shown in this version; this only tracks the cadence (never during the
  /// tutorial levels 1-3) so a future integration has one place to add it.
  static Future<void> showInterstitialBetweenLevels(int completedLevel) async {
    if (completedLevel <= 3) return;
    _levelsCompletedSinceLastAd++;
    if (_levelsCompletedSinceLastAd >= interstitialLevelInterval) {
      _levelsCompletedSinceLastAd = 0;
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../storage/storage_service.dart';
import '../storage/cloud_sync_service.dart';

enum AuthStatus { uninitialized, guest, authenticated }

/// Guest mode is purely local: no Firebase account (not even an anonymous
/// one) is created, and nothing leaves the device. Signing in with Google
/// merges the guest's local progress into the Google account.
class AuthService extends ChangeNotifier {
  final StorageService storage;
  late final CloudSyncService cloudSync;

  final FirebaseAuth? _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthStatus _status = AuthStatus.uninitialized;
  User? _currentUser;
  String? _guestId;
  String? _errorMessage;
  bool _isLoading = false;

  AuthService({
    required this.storage,
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    CloudSyncService? cloudSync,
  }) : _firebaseAuth = firebaseAuth ?? _tryGetFirebaseAuth(),
       _googleSignIn = googleSignIn ?? GoogleSignIn() {
    this.cloudSync =
        cloudSync ??
        CloudSyncService(storage: storage, firebaseAuth: _firebaseAuth);
  }

  static FirebaseAuth? _tryGetFirebaseAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      // Firebase was not initialized (missing native configuration).
      return null;
    }
  }

  /// False when Firebase could not be initialized on this build/platform.
  bool get isFirebaseAvailable => _firebaseAuth != null;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get guestId => _guestId;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isGuest => _status == AuthStatus.guest;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _currentUser != null;

  String get displayName {
    if (isAuthenticated && _currentUser?.displayName != null) {
      return _currentUser!.displayName!;
    }
    return 'Guest Player';
  }

  String? get email => _currentUser?.email;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  /// Initializes auth state on startup.
  Future<void> init() async {
    _setLoading(true);
    try {
      // Firebase restores the signed-in user itself; only sync if it did.
      final user = _firebaseAuth?.currentUser;
      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
        unawaited(cloudSync.syncProgress());
      } else {
        await _ensureGuestId();
        _status = AuthStatus.guest;
      }
    } catch (e) {
      debugPrint('[AuthService] Init error: $e');
      _status = AuthStatus.guest;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _ensureGuestId() async {
    _guestId = storage.getGuestId();
    if (_guestId == null) {
      _guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await storage.setGuestId(_guestId!);
    }
  }

  /// Continues playing as a local guest.
  Future<void> playAsGuest() async {
    _errorMessage = null;
    _status = AuthStatus.guest;
    await _ensureGuestId();
    await storage.setFirstLaunchCompleted(true);
    notifyListeners();
  }

  /// Signs in with Google and merges this device's progress into the account.
  /// Returns false on cancellation (with no error message) or failure (with
  /// [errorMessage] set).
  Future<bool> signInWithGoogle() async {
    _errorMessage = null;
    final auth = _firebaseAuth;
    if (auth == null) {
      _errorMessage =
          'Google sign-in is not available in this build (Firebase is not '
          'configured). You can keep playing as a guest.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final credential = await _googleCredential(interactive: true);
      if (credential == null) return false; // cancelled

      final result = await auth.signInWithCredential(credential);
      _currentUser = result.user;
      _status = AuthStatus.authenticated;

      // Verified Firebase session from here on; merge never discards guest data.
      await cloudSync.mergeGuestProgressToCloud();
      await storage.setFirstLaunchCompleted(true);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException: ${e.code}');
      _errorMessage = describeAuthError(e.code);
      return false;
    } on PlatformException catch (e) {
      debugPrint('[AuthService] Google sign-in PlatformException: ${e.code}');
      _errorMessage = describeGoogleSignInError(e.code, e.message);
      return false;
    } catch (e) {
      debugPrint('[AuthService] Google sign-in exception: $e');
      _errorMessage = 'Google sign-in failed. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthCredential?> _googleCredential({required bool interactive}) async {
    final account = interactive
        ? await _googleSignIn.signIn()
        : await _googleSignIn.signInSilently();
    if (account == null) return null;
    final tokens = await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
  }

  @visibleForTesting
  static String describeAuthError(String code) => switch (code) {
    'network-request-failed' =>
      'No internet connection. Check your network and try again.',
    'account-exists-with-different-credential' =>
      'This email is already linked to a different sign-in method.',
    'user-disabled' => 'This account has been disabled.',
    'invalid-credential' => 'Sign-in expired. Please try again.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    _ => 'Sign-in failed ($code). Please try again.',
  };

  /// google_sign_in reports Play Services errors as PlatformException.
  /// "ApiException: 10" (DEVELOPER_ERROR) means the app's SHA fingerprint or
  /// OAuth client is not registered in Firebase.
  @visibleForTesting
  static String describeGoogleSignInError(String code, String? message) {
    if (code == 'network_error') {
      return 'No internet connection. Check your network and try again.';
    }
    if (code == 'sign_in_canceled') return 'Sign-in was cancelled.';
    if ((message ?? '').contains('10:') || (message ?? '').contains(': 10')) {
      return 'Google sign-in is not configured for this build yet '
          '(missing SHA fingerprint or OAuth client). Playing as guest works.';
    }
    return 'Google sign-in failed. Please try again.';
  }

  /// Signs out and returns to guest mode. Progress already on this device
  /// stays on this device; the cloud copy stays in the account.
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth?.signOut();
    } catch (e) {
      debugPrint('[AuthService] Sign out error: $e');
    } finally {
      cloudSync.onSignedOut();
      _currentUser = null;
      _status = AuthStatus.guest;
      await _ensureGuestId();
      _setLoading(false);
    }
  }

  /// Permanently deletes the account: re-verifies the user with Google,
  /// deletes the Firestore document, deletes the Firebase user and wipes this
  /// device. If any step fails, nothing after it runs.
  Future<bool> deleteAccount() async {
    final user = _currentUser;
    if (!isAuthenticated || user == null) return false;

    _errorMessage = null;
    _setLoading(true);
    try {
      // Firebase requires a recent sign-in to delete an account.
      final credential =
          await _googleCredential(interactive: false) ??
          await _googleCredential(interactive: true);
      if (credential == null) {
        _errorMessage = 'Please confirm your Google account to delete it.';
        return false;
      }
      await user.reauthenticateWithCredential(credential);

      await cloudSync.deleteUserCloudData();
      await user.delete();
      await _googleSignIn.signOut();
      cloudSync.onSignedOut();

      await storage.wipeAllLocalData();
      _currentUser = null;
      _status = AuthStatus.guest;
      await _ensureGuestId();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Delete account error: ${e.code}');
      _errorMessage = e.code == 'requires-recent-login'
          ? 'Please sign in again, then retry deleting your account.'
          : describeAuthError(e.code);
      return false;
    } catch (e) {
      debugPrint('[AuthService] Delete account error: $e');
      _errorMessage =
          'Could not delete your account. Check your connection and try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }
}

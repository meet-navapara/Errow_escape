import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'progress_snapshot.dart';
import 'storage_service.dart';

enum SyncStatus { signedOut, idle, pending, syncing, synced, offline }

/// Syncs local progress with `users/{uid}` in Cloud Firestore.
///
/// Every sync runs a transaction that reads the cloud copy, merges it with
/// the local copy using [ProgressSnapshot.merge] and writes the result to
/// both places, so concurrent devices and stale copies never overwrite more
/// advanced progress. Local progress is always kept; the game stays fully
/// playable offline and pending changes are retried with backoff.
class CloudSyncService {
  final StorageService storage;
  final FirebaseAuth? firebaseAuth;
  final FirebaseFirestore? _firestore;
  final Duration debounce;

  final ValueNotifier<SyncStatus> status = ValueNotifier(SyncStatus.signedOut);
  DateTime? lastSyncedAt;

  Timer? _debounceTimer;
  Timer? _retryTimer;
  int _failures = 0;
  bool _running = false;
  bool _rerun = false;

  CloudSyncService({
    required this.storage,
    this.firebaseAuth,
    FirebaseFirestore? firestore,
    this.debounce = const Duration(seconds: 4),
  }) : _firestore = firestore ?? _tryGetFirestore() {
    storage.onProgressChanged = scheduleSync;
    if (_currentUid != null) status.value = SyncStatus.idle;
  }

  static FirebaseFirestore? _tryGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String? get _currentUid => firebaseAuth?.currentUser?.uid;

  bool get isAvailable => _firestore != null && _currentUid != null;

  /// Coalesces bursts of local changes into one sync.
  void scheduleSync() {
    if (!isAvailable) return;
    status.value = SyncStatus.pending;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, syncProgress);
  }

  /// Merges local and cloud progress. Safe to call at any time.
  Future<bool> syncProgress() async {
    _debounceTimer?.cancel();
    final uid = _currentUid;
    final firestore = _firestore;
    if (uid == null || firestore == null) {
      status.value = SyncStatus.signedOut;
      return false;
    }
    if (_running) {
      _rerun = true;
      return false;
    }
    _running = true;
    status.value = SyncStatus.syncing;

    try {
      final docRef = firestore.collection('users').doc(uid);
      final merged = await firestore.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        final local = ProgressSnapshot.fromStorage(storage);
        final data = snapshot.data();
        final result = data == null
            ? local
            : local.merge(ProgressSnapshot.fromFirestore(data));
        tx.set(docRef, {
          ...result.toFirestore(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastPlayedAt': storage.getLastPlayedAt()?.toIso8601String(),
          // Whole-document write (keeps the schema exact); carry createdAt over.
          'createdAt': data == null
              ? FieldValue.serverTimestamp()
              : data['createdAt'],
        });
        return result;
      });

      // Applying merged data must not trigger another sync.
      storage.onProgressChanged = null;
      try {
        await merged.applyTo(storage);
      } finally {
        storage.onProgressChanged = scheduleSync;
      }

      _failures = 0;
      lastSyncedAt = DateTime.now();
      status.value = SyncStatus.synced;
      debugPrint('[CloudSyncService] Progress synced for $uid');
      return true;
    } catch (e) {
      debugPrint('[CloudSyncService] Sync failed (will retry): $e');
      status.value = SyncStatus.offline;
      _scheduleRetry();
      return false;
    } finally {
      _running = false;
      if (_rerun) {
        _rerun = false;
        scheduleSync();
      }
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _failures++;
    final seconds = math.min(300, 5 * math.pow(2, _failures - 1).toInt());
    _retryTimer = Timer(Duration(seconds: seconds), syncProgress);
  }

  /// Called after Google sign-in: guest progress on this device is merged
  /// into the account (never discarded), then saved to the cloud.
  Future<bool> mergeGuestProgressToCloud() => syncProgress();

  void onSignedOut() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    status.value = SyncStatus.signedOut;
  }

  /// Deletes the user's Firestore document. Throws on failure so account
  /// deletion can stop before removing the auth account.
  Future<void> deleteUserCloudData() async {
    final uid = _currentUid;
    if (uid == null || _firestore == null) return;
    await _firestore.collection('users').doc(uid).delete();
    debugPrint('[CloudSyncService] Deleted Firestore document for $uid');
  }

  void dispose() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    status.dispose();
  }
}

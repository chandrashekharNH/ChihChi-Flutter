import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'premium_access.dart';

/// Remembers the last verified purchase so the app opens unlocked straight away, even offline,
/// while the store is asked again. It never unlocks on its own: the store's answer always wins.
abstract class EntitlementCache {
  Future<String?> load();
  Future<void> save(String purchaseID);
  Future<void> clear();
}

/// The cache lives in the Keychain (iOS) or the Keystore-backed storage (Android), not in
/// plain preferences.
class SecureEntitlementCache implements EntitlementCache {
  static const _key = 'com.chihchi.entitlements.fulladventure';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> load() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String purchaseID) async {
    try {
      await _storage.write(key: _key, value: purchaseID);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

/// A cache kept in memory, for tests.
class MemoryEntitlementCache implements EntitlementCache {
  String? value;
  @override
  Future<String?> load() async => value;
  @override
  Future<void> save(String purchaseID) async => value = purchaseID;
  @override
  Future<void> clear() async => value = null;
}

/// Knows whether this device may play the premium content. Separate from game progress: it never
/// touches levels, stars or profiles, it only answers "free or premium?".
class EntitlementManager extends ChangeNotifier {
  EntitlementManager({EntitlementCache? cache}) : _cache = cache ?? SecureEntitlementCache();

  final EntitlementCache _cache;
  EntitlementState _state = EntitlementState.checking;
  bool _isConfirmed = false;

  EntitlementState get state => _state;

  /// True once the store itself has answered at least once this launch.
  bool get isConfirmed => _isConfirmed;

  /// The store answered, or this launch stopped waiting for it: nothing is being checked any more.
  bool get isSettled => _isConfirmed || _isSettled;
  bool _isSettled = false;
  bool get isPremium => _state.isPremium;

  /// A purchase verified on an earlier launch: open unlocked while the store is asked again.
  Future<void> load() async {
    if (await _cache.load() != null) {
      _state = EntitlementState.premium;
      notifyListeners();
    }
  }

  /// The store reported what this account owns (`purchaseIDs` empty = nothing).
  Future<void> storeAnswered(List<String> purchaseIDs) async {
    if (purchaseIDs.isNotEmpty) {
      await _cache.save(purchaseIDs.first);
      _state = EntitlementState.premium;
    } else {
      await _cache.clear();
      _state = EntitlementState.free;
    }
    _isConfirmed = true;
    notifyListeners();
  }

  /// The store has not said anything yet, but this launch is unlikely to hear more (iOS without
  /// a restore): keep a cached purchase, otherwise play as free.
  void settleWithoutAnswer() {
    _isSettled = true;
    if (_state == EntitlementState.checking) {
      _state = EntitlementState.free;
      notifyListeners();
    }
  }
}

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'entitlement_manager.dart';
import 'premium_access.dart';

enum ProductStatus {
  loading,
  ready,

  /// The store couldn't be reached, or the product isn't available in this country.
  unavailable,
}

enum PurchaseFailure { network, notVerified, other }

enum PurchaseStatusKind { idle, purchasing, pending, purchased, cancelled, restoring, restored, nothingToRestore, failed }

/// Where the purchase is in its journey. `failure` is set only for `failed`.
class PurchaseState {
  const PurchaseState(this.kind, [this.failure]);
  final PurchaseStatusKind kind;
  final PurchaseFailure? failure;

  static const idle = PurchaseState(PurchaseStatusKind.idle);

  @override
  bool operator ==(Object other) => other is PurchaseState && other.kind == kind && other.failure == failure;
  @override
  int get hashCode => Object.hash(kind, failure);
}

/// Talks to the App Store / Google Play: loads the product and its local price, buys, restores,
/// and listens for purchases that arrive later (Ask to Buy approvals, purchases on another
/// device, refunds). What is unlocked is decided by `EntitlementManager`.
class StoreManager extends ChangeNotifier {
  StoreManager(this.entitlements, {InAppPurchase? store}) : _storeOverride = store;

  final EntitlementManager entitlements;
  final InAppPurchase? _storeOverride;
  InAppPurchase get _store => _storeOverride ?? InAppPurchase.instance;

  ProductStatus productStatus = ProductStatus.loading;
  PurchaseState purchaseStatus = PurchaseState.idle;
  ProductDetails? fullAdventure;

  StreamSubscription<List<PurchaseDetails>>? _updates;
  final Set<String> _owned = {};

  /// The local price exactly as the store gives it (for example "$2.99").
  String? get displayPrice => fullAdventure?.price;

  void _set(PurchaseState state) {
    purchaseStatus = state;
    notifyListeners();
  }

  /// Starts listening for purchases and checks what is owned. Call once at launch.
  Future<void> start() async {
    try {
      _updates ??= _store.purchaseStream.listen(_handle, onError: (_) {});
      if (!await _store.isAvailable()) {
        productStatus = ProductStatus.unavailable;
        entitlements.settleWithoutAnswer();
        notifyListeners();
        return;
      }
      // Google Play answers a restore from its own record on the phone, quietly. On iOS a restore
      // can ask for the Apple Account password, so it waits for the Restore button; unfinished
      // transactions still arrive through the purchase stream.
      if (Platform.isAndroid) {
        await _queryOwned();
      } else {
        entitlements.settleWithoutAnswer();
      }
      await loadProducts();
    } catch (_) {
      productStatus = ProductStatus.unavailable;
      entitlements.settleWithoutAnswer();
      notifyListeners();
    }
  }

  Future<void> _queryOwned() async {
    _owned.clear();
    await _store.restorePurchases();
    // Restored purchases arrive through the stream; give them a moment.
    await Future<void>.delayed(const Duration(seconds: 2));
    await entitlements.storeAnswered(_owned.toList());
  }

  Future<void> loadProducts() async {
    productStatus = ProductStatus.loading;
    notifyListeners();
    try {
      final response = await _store.queryProductDetails(PremiumProduct.allIDs);
      fullAdventure = response.productDetails
          .where((p) => p.id == PremiumProduct.fullAdventure.id)
          .cast<ProductDetails?>()
          .firstWhere((_) => true, orElse: () => null);
      productStatus = fullAdventure == null ? ProductStatus.unavailable : ProductStatus.ready;
    } catch (_) {
      productStatus = ProductStatus.unavailable;
    }
    notifyListeners();
  }

  Future<void> buyFullAdventure() async {
    if (fullAdventure == null) await loadProducts();
    final product = fullAdventure;
    if (product == null) {
      _set(const PurchaseState(PurchaseStatusKind.failed, PurchaseFailure.network));
      return;
    }
    _set(const PurchaseState(PurchaseStatusKind.purchasing));
    try {
      final started = await _store.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      if (!started) _set(const PurchaseState(PurchaseStatusKind.failed, PurchaseFailure.other));
    } catch (_) {
      _set(const PurchaseState(PurchaseStatusKind.failed, PurchaseFailure.other));
    }
  }

  /// Asks the store for this account's purchases (needs the internet).
  Future<void> restore() async {
    _set(const PurchaseState(PurchaseStatusKind.restoring));
    try {
      _owned.clear();
      await _store.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_owned.isNotEmpty || entitlements.isPremium) {
        if (_owned.isNotEmpty) await entitlements.storeAnswered(_owned.toList());
        _set(const PurchaseState(PurchaseStatusKind.restored));
      } else {
        // Google Play's answer is complete; on iOS an empty restore also means nothing is owned.
        await entitlements.storeAnswered(const []);
        _set(const PurchaseState(PurchaseStatusKind.nothingToRestore));
      }
    } catch (_) {
      _set(const PurchaseState(PurchaseStatusKind.failed, PurchaseFailure.network));
    }
  }

  void clearStatus() {
    if (purchaseStatus.kind != PurchaseStatusKind.purchasing && purchaseStatus.kind != PurchaseStatusKind.restoring) {
      _set(PurchaseState.idle);
    }
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (PremiumProduct.fromID(purchase.productID) == null) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _set(const PurchaseState(PurchaseStatusKind.pending));
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final id = purchase.purchaseID ?? purchase.productID;
          _owned.add(id);
          await entitlements.storeAnswered([id]);
          if (purchase.status == PurchaseStatus.purchased) {
            _set(const PurchaseState(PurchaseStatusKind.purchased));
          } else if (purchaseStatus.kind == PurchaseStatusKind.pending) {
            _set(const PurchaseState(PurchaseStatusKind.purchased));
          }
        case PurchaseStatus.canceled:
          _set(const PurchaseState(PurchaseStatusKind.cancelled));
        case PurchaseStatus.error:
          final message = purchase.error?.message.toLowerCase() ?? '';
          _set(PurchaseState(PurchaseStatusKind.failed,
              message.contains('network') ? PurchaseFailure.network : PurchaseFailure.other));
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _store.completePurchase(purchase);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }
}

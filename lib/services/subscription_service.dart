import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// App Store Connect auto-renewable subscription product.
const proMonthlyProductId = 'com.calendar.content.pro.monthly';

const appStoreAppUrl = 'https://apps.apple.com/app/id6772790980';
const manageSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions';

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  static const _entitlementKey = 'pro_subscription_active';

  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  var _initialized = false;
  var _storeAvailable = false;
  var _proEntitled = false;
  var _purchasePending = false;
  ProductDetails? _proProduct;
  String? _lastError;

  bool get supportsNativeStore => !kIsWeb && Platform.isIOS;
  bool get storeAvailable => _storeAvailable;
  bool get isPro => _proEntitled;
  bool get purchasePending => _purchasePending;
  ProductDetails? get proProduct => _proProduct;
  String? get lastError => _lastError;

  String? get localizedPrice => _proProduct?.price;

  /// Localized price from the App Store (e.g. £2.99 in the UK, $1.99 in the US).
  bool get hasLocalizedPrice =>
      _proProduct?.price != null && _proProduct!.price.isNotEmpty;

  String get subscribeButtonLabel {
    final price = _proProduct?.price;
    if (price != null && price.isNotEmpty) {
      return 'Subscribe · $price';
    }
    return 'Subscribe';
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _proEntitled = prefs.getBool(_entitlementKey) ?? false;

      if (!supportsNativeStore) {
        notifyListeners();
        return;
      }

      _storeAvailable = await _store.isAvailable().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      if (!_storeAvailable) {
        _lastError = _unavailableStoreMessage();
        notifyListeners();
        return;
      }

      _purchaseSub = _store.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error) {
          _lastError = error.toString();
          _purchasePending = false;
          notifyListeners();
        },
      );

      await _queryProducts().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          _lastError = 'App Store is taking longer than usual. Pull to refresh and try again.';
        },
      );
      _applyProductLoadResult();
      // Restore in background — awaiting here on launch caused white screens on device.
      unawaited(restorePurchases(silent: true));
    } catch (error, stack) {
      debugPrint('SubscriptionService.init error: $error\n$stack');
      _lastError ??= _friendlyStoreError(error);
    } finally {
      notifyListeners();
    }
  }

  Future<void> disposeService() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
  }

  /// Re-fetch product metadata (call when opening the paywall).
  Future<void> refreshStoreCatalog() async {
    if (!supportsNativeStore) return;

    _lastError = null;
    if (!_initialized) {
      await init();
      return;
    }

    if (!_storeAvailable) {
      _storeAvailable = await _store.isAvailable().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      if (!_storeAvailable) {
        _lastError = _unavailableStoreMessage();
        notifyListeners();
        return;
      }
    }

    await _queryProducts();
    _applyProductLoadResult();
    notifyListeners();
  }

  void _applyProductLoadResult() {
    if (_proProduct != null) {
      _lastError = null;
      return;
    }
    if (_lastError != null && _lastError!.isNotEmpty) return;
    _lastError =
        'Subscription is not available yet. Check App Store Connect has '
        'com.calendar.content.pro.monthly approved, or use StoreKit testing in Xcode.';
  }

  String _unavailableStoreMessage() {
    if (kDebugMode) {
      return 'StoreKit is unavailable. In Xcode, set the Runner scheme to use '
          'Products.storekit for simulator testing, or use a TestFlight build on a device.';
    }
    return 'Cannot reach the App Store right now. Check your connection and try again.';
  }

  String _friendlyStoreError(Object error) {
    if (error is PlatformException) {
      return error.message ?? 'Could not connect to the App Store.';
    }
    return 'Could not connect to the App Store.';
  }

  Future<void> _queryProducts() async {
    final response = await _store.queryProductDetails({proMonthlyProductId});
    if (response.error != null) {
      _lastError = response.error!.message;
      _proProduct = null;
      notifyListeners();
      return;
    }
    if (response.notFoundIDs.isNotEmpty) {
      _lastError =
          'Subscription product not found in the App Store. Verify '
          'com.calendar.content.pro.monthly in App Store Connect.';
      _proProduct = null;
      notifyListeners();
      return;
    }
    if (response.productDetails.isNotEmpty) {
      ProductDetails? match;
      for (final product in response.productDetails) {
        if (product.id == proMonthlyProductId) {
          match = product;
          break;
        }
      }
      _proProduct = match ?? response.productDetails.first;
    } else {
      _proProduct = null;
    }
    notifyListeners();
  }

  Future<bool> purchasePro() async {
    _lastError = null;

    if (!supportsNativeStore) {
      await openAppStoreListing();
      return false;
    }

    if (!_storeAvailable) {
      _lastError = 'App Store is unavailable right now.';
      notifyListeners();
      return false;
    }

    if (_proProduct == null) {
      await _queryProducts();
    }

    final product = _proProduct;
    if (product == null) {
      _lastError = 'Could not load subscription from the App Store.';
      notifyListeners();
      return false;
    }

    _purchasePending = true;
    notifyListeners();

    final started = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );

    if (!started) {
      _purchasePending = false;
      _lastError = 'Could not start purchase.';
      notifyListeners();
    }

    return started;
  }

  Future<void> restorePurchases({bool silent = false}) async {
    if (!supportsNativeStore || !_storeAvailable) return;

    if (!silent) {
      _purchasePending = true;
      _lastError = null;
      notifyListeners();
    }

    await _store.restorePurchases();
  }

  Future<void> openAppStoreListing() async {
    final uri = Uri.parse(appStoreAppUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> openManageSubscriptions() async {
    final uri = Uri.parse(manageSubscriptionsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    var entitlementChanged = false;

    for (final purchase in purchases) {
      if (purchase.productID != proMonthlyProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _setProEntitlement(true);
          entitlementChanged = true;
          _purchasePending = false;
          _lastError = null;
        case PurchaseStatus.error:
          _purchasePending = false;
          _lastError = purchase.error?.message ?? 'Purchase failed.';
        case PurchaseStatus.canceled:
          _purchasePending = false;
      }

      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }

    if (entitlementChanged) {
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  Future<void> _setProEntitlement(bool value) async {
    _proEntitled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_entitlementKey, value);
  }
}

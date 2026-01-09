/// 訂閱服務
/// 
/// 處理 Google Play 內購、訂閱狀態管理
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_status.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // 內購實例
  final InAppPurchase _iap = InAppPurchase.instance;
  
  // 訂閱狀態
  SubscriptionStatus _status = const SubscriptionStatus();
  SubscriptionStatus get status => _status;
  
  // 是否為 Premium
  bool get isPremium => _status.isPremium;
  bool get isFree => _status.isFree;

  // 可用商品
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // 購買狀態
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 購買監聽器
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // 初始化
  Future<void> initialize() async {
    // 載入本地儲存的訂閱狀態
    await _loadLocalStatus();

    // 檢查是否支援內購
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('SubscriptionService: 內購不可用');
      return;
    }

    // 監聽購買更新
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: (error) {
        debugPrint('SubscriptionService: 購買流錯誤 - $error');
      },
    );

    // 載入商品資訊
    await loadProducts();

    // 還原購買
    await restorePurchases();
  }

  // 釋放資源
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // 載入商品資訊
  Future<void> loadProducts() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _iap.queryProductDetails(
        SubscriptionProduct.productIds,
      );

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('SubscriptionService: 找不到商品 - ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('SubscriptionService: 載入 ${_products.length} 個商品');

    } catch (e) {
      _errorMessage = '載入商品失敗: $e';
      debugPrint('SubscriptionService: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 購買訂閱
  Future<bool> purchaseSubscription(ProductDetails product) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final purchaseParam = PurchaseParam(productDetails: product);
      
      // 執行購買
      final success = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        _errorMessage = '無法啟動購買流程';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = '購買失敗: $e';
      debugPrint('SubscriptionService: $_errorMessage');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 還原購買
  Future<void> restorePurchases() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _iap.restorePurchases();
      
    } catch (e) {
      _errorMessage = '還原購買失敗: $e';
      debugPrint('SubscriptionService: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 處理購買更新
  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint('SubscriptionService: 購買狀態 - ${purchase.productID}: ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          // 購買處理中
          _isLoading = true;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // 購買成功或還原成功
          final valid = await _verifyPurchase(purchase);
          if (valid) {
            await _activateSubscription(purchase);
          }
          
          // 完成購買流程
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          
          _isLoading = false;
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _errorMessage = purchase.error?.message ?? '購買失敗';
          _isLoading = false;
          notifyListeners();
          
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          _isLoading = false;
          notifyListeners();
          break;
      }
    }
  }

  // 驗證購買（簡化版，生產環境應該在伺服器端驗證）
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // TODO: 在生產環境中，應該將 purchase.verificationData 
    // 傳送到後端伺服器進行驗證
    
    // 這裡簡化處理，直接返回 true
    // 實際應用中需要：
    // 1. 將 serverVerificationData 傳送到您的後端
    // 2. 後端使用 Google Play Developer API 驗證
    // 3. 返回驗證結果
    
    debugPrint('SubscriptionService: 驗證購買 - ${purchase.productID}');
    return true;
  }

  // 啟用訂閱
  Future<void> _activateSubscription(PurchaseDetails purchase) async {
    // 根據商品 ID 判斷訂閱期間
    SubscriptionPeriod period;
    DateTime expiryDate;

    if (purchase.productID == SubscriptionProduct.monthly.productId) {
      period = SubscriptionPeriod.monthly;
      expiryDate = DateTime.now().add(const Duration(days: 30));
    } else if (purchase.productID == SubscriptionProduct.yearly.productId) {
      period = SubscriptionPeriod.yearly;
      expiryDate = DateTime.now().add(const Duration(days: 365));
    } else {
      return;
    }

    _status = SubscriptionStatus(
      tier: SubscriptionTier.premium,
      expiryDate: expiryDate,
      period: period,
      productId: purchase.productID,
    );

    await _saveLocalStatus();
    notifyListeners();

    debugPrint('SubscriptionService: 訂閱已啟用 - $_status');
  }

  // 儲存本地訂閱狀態
  Future<void> _saveLocalStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription_status', jsonEncode(_status.toJson()));
    } catch (e) {
      debugPrint('SubscriptionService: 儲存狀態失敗 - $e');
    }
  }

  // 載入本地訂閱狀態
  Future<void> _loadLocalStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('subscription_status');
      if (json != null) {
        _status = SubscriptionStatus.fromJson(jsonDecode(json));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('SubscriptionService: 載入狀態失敗 - $e');
    }
  }

  // 清除訂閱（僅供測試）
  @visibleForTesting
  Future<void> clearSubscription() async {
    _status = const SubscriptionStatus();
    await _saveLocalStatus();
    notifyListeners();
  }

  // 模擬購買（僅供測試）
  @visibleForTesting
  Future<void> simulatePurchase(SubscriptionPeriod period) async {
    final expiryDate = period == SubscriptionPeriod.monthly
        ? DateTime.now().add(const Duration(days: 30))
        : DateTime.now().add(const Duration(days: 365));

    _status = SubscriptionStatus(
      tier: SubscriptionTier.premium,
      expiryDate: expiryDate,
      period: period,
      productId: period == SubscriptionPeriod.monthly
          ? SubscriptionProduct.monthly.productId
          : SubscriptionProduct.yearly.productId,
    );

    await _saveLocalStatus();
    notifyListeners();
  }
}

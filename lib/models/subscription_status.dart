/// 訂閱狀態模型
/// 
/// 管理用戶的訂閱等級和相關資訊
library;

enum SubscriptionTier {
  free,     // 免費版
  premium,  // Premium 訂閱版
}

enum SubscriptionPeriod {
  monthly,  // 月訂閱 NT$50
  yearly,   // 年訂閱 NT$500
}

class SubscriptionStatus {
  final SubscriptionTier tier;
  final DateTime? expiryDate;
  final SubscriptionPeriod? period;
  final String? productId;
  final bool isTrialPeriod;

  const SubscriptionStatus({
    this.tier = SubscriptionTier.free,
    this.expiryDate,
    this.period,
    this.productId,
    this.isTrialPeriod = false,
  });

  /// 檢查訂閱是否有效
  bool get isActive {
    if (tier == SubscriptionTier.free) return false;
    if (expiryDate == null) return false;
    return expiryDate!.isAfter(DateTime.now());
  }

  /// 是否為 Premium 用戶
  bool get isPremium => isActive && tier == SubscriptionTier.premium;

  /// 免費版用戶
  bool get isFree => !isPremium;

  /// 剩餘天數
  int get remainingDays {
    if (expiryDate == null) return 0;
    final diff = expiryDate!.difference(DateTime.now());
    return diff.inDays > 0 ? diff.inDays : 0;
  }

  /// 訂閱方案名稱
  String get planName {
    if (tier == SubscriptionTier.free) return '免費版';
    switch (period) {
      case SubscriptionPeriod.monthly:
        return 'Premium 月訂閱';
      case SubscriptionPeriod.yearly:
        return 'Premium 年訂閱';
      default:
        return 'Premium';
    }
  }

  /// 從 JSON 還原
  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      expiryDate: json['expiryDate'] != null 
          ? DateTime.parse(json['expiryDate']) 
          : null,
      period: json['period'] != null
          ? SubscriptionPeriod.values.firstWhere(
              (e) => e.name == json['period'],
              orElse: () => SubscriptionPeriod.monthly,
            )
          : null,
      productId: json['productId'],
      isTrialPeriod: json['isTrialPeriod'] ?? false,
    );
  }

  /// 轉換為 JSON
  Map<String, dynamic> toJson() {
    return {
      'tier': tier.name,
      'expiryDate': expiryDate?.toIso8601String(),
      'period': period?.name,
      'productId': productId,
      'isTrialPeriod': isTrialPeriod,
    };
  }

  /// 複製並修改
  SubscriptionStatus copyWith({
    SubscriptionTier? tier,
    DateTime? expiryDate,
    SubscriptionPeriod? period,
    String? productId,
    bool? isTrialPeriod,
  }) {
    return SubscriptionStatus(
      tier: tier ?? this.tier,
      expiryDate: expiryDate ?? this.expiryDate,
      period: period ?? this.period,
      productId: productId ?? this.productId,
      isTrialPeriod: isTrialPeriod ?? this.isTrialPeriod,
    );
  }

  @override
  String toString() {
    return 'SubscriptionStatus(tier: $tier, expiry: $expiryDate, period: $period, isPremium: $isPremium)';
  }
}

/// 訂閱商品定義
class SubscriptionProduct {
  final String productId;
  final String title;
  final String description;
  final SubscriptionPeriod period;
  final double price;
  final String priceString;
  final double? originalPrice;
  final int? discountPercent;

  const SubscriptionProduct({
    required this.productId,
    required this.title,
    required this.description,
    required this.period,
    required this.price,
    required this.priceString,
    this.originalPrice,
    this.discountPercent,
  });

  /// 月訂閱商品
  static const monthly = SubscriptionProduct(
    productId: 'txf_premium_monthly',
    title: 'Premium 月訂閱',
    description: '解鎖所有功能，每月自動續訂',
    period: SubscriptionPeriod.monthly,
    price: 50,
    priceString: 'NT\$50/月',
  );

  /// 年訂閱商品（約 17% 折扣）
  static const yearly = SubscriptionProduct(
    productId: 'txf_premium_yearly',
    title: 'Premium 年訂閱',
    description: '解鎖所有功能，每年自動續訂，省更多！',
    period: SubscriptionPeriod.yearly,
    price: 500,
    priceString: 'NT\$500/年',
    originalPrice: 600, // 50 * 12
    discountPercent: 17,
  );

  /// 所有可用商品
  static const List<SubscriptionProduct> allProducts = [monthly, yearly];

  /// 商品 ID 列表
  static Set<String> get productIds => {monthly.productId, yearly.productId};
}

/// 訂閱購買頁面
/// 
/// 顯示訂閱方案、功能比較、購買按鈕
library;

import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../models/subscription_status.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _subscriptionService = SubscriptionService();
  int _selectedPlanIndex = 1; // 預設選擇年訂閱（較優惠）

  @override
  void initState() {
    super.initState();
    _subscriptionService.addListener(_onSubscriptionChanged);
  }

  @override
  void dispose() {
    _subscriptionService.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (mounted) setState(() {});
    
    // 如果購買成功，返回上一頁
    if (_subscriptionService.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 訂閱成功！已解鎖所有 Premium 功能'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = _subscriptionService.isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('升級 Premium'),
        centerTitle: true,
      ),
      body: isPremium
          ? _buildPremiumStatus(theme)
          : _buildSubscriptionOptions(theme),
    );
  }

  // Premium 用戶狀態顯示
  Widget _buildPremiumStatus(ThemeData theme) {
    final status = _subscriptionService.status;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.workspace_premium,
              size: 80,
              color: Colors.amber[600],
            ),
            const SizedBox(height: 24),
            Text(
              '您是 Premium 會員！',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status.planName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            if (status.expiryDate != null) ...[
              Text(
                '有效期至: ${_formatDate(status.expiryDate!)}',
                style: theme.textTheme.bodyLarge,
              ),
              Text(
                '剩餘 ${status.remainingDays} 天',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => _subscriptionService.restorePurchases(),
              icon: const Icon(Icons.restore),
              label: const Text('還原購買'),
            ),
          ],
        ),
      ),
    );
  }

  // 訂閱選項
  Widget _buildSubscriptionOptions(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 標題
          _buildHeader(theme),
          const SizedBox(height: 24),
          
          // 功能比較
          _buildFeatureComparison(theme),
          const SizedBox(height: 24),
          
          // 訂閱方案選擇
          _buildPlanSelection(theme),
          const SizedBox(height: 24),
          
          // 購買按鈕
          _buildPurchaseButton(theme),
          const SizedBox(height: 16),
          
          // 還原購買
          Center(
            child: TextButton.icon(
              onPressed: _subscriptionService.isLoading
                  ? null
                  : () => _subscriptionService.restorePurchases(),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('還原購買'),
            ),
          ),
          const SizedBox(height: 16),
          
          // 說明文字
          _buildDisclaimer(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.workspace_premium,
          size: 64,
          color: Colors.amber[600],
        ),
        const SizedBox(height: 16),
        Text(
          '升級到 Premium',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '解鎖完整功能，提升交易效率',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureComparison(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '功能比較',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureRow('基本槓桿計算', true, true, theme),
            _buildFeatureRow('即時報價查詢', true, true, theme),
            const Divider(height: 24),
            _buildFeatureRow('自動帶入報價', false, true, theme),
            _buildFeatureRow('歷史紀錄儲存', false, true, theme),
            _buildFeatureRow('自動記住設定', false, true, theme),
            _buildFeatureRow('多帳戶管理', false, true, theme),
            _buildFeatureRow('資料匯出', false, true, theme),
            _buildFeatureRow('無廣告體驗', false, true, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String feature, bool free, bool premium, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(feature),
          ),
          Expanded(
            child: Center(
              child: Icon(
                free ? Icons.check_circle : Icons.cancel,
                color: free ? Colors.green : Colors.grey[400],
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                premium ? Icons.check_circle : Icons.cancel,
                color: premium ? Colors.amber[600] : Colors.grey[400],
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelection(ThemeData theme) {
    final plans = [
      SubscriptionProduct.monthly,
      SubscriptionProduct.yearly,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '選擇方案',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...plans.asMap().entries.map((entry) {
          final index = entry.key;
          final plan = entry.value;
          final isSelected = _selectedPlanIndex == index;
          
          return _buildPlanCard(plan, isSelected, index, theme);
        }),
      ],
    );
  }

  Widget _buildPlanCard(
    SubscriptionProduct plan,
    bool isSelected,
    int index,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? theme.colorScheme.primaryContainer.withAlpha(30)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // 選擇指示器
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected 
                        ? theme.colorScheme.primary 
                        : theme.dividerColor,
                    width: 2,
                  ),
                  color: isSelected 
                      ? theme.colorScheme.primary 
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              
              // 方案資訊
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (plan.discountPercent != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '省 ${plan.discountPercent}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 價格
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.priceString,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (plan.originalPrice != null)
                    Text(
                      'NT\$${plan.originalPrice!.toInt()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseButton(ThemeData theme) {
    final isLoading = _subscriptionService.isLoading;
    final selectedPlan = _selectedPlanIndex == 0
        ? SubscriptionProduct.monthly
        : SubscriptionProduct.yearly;

    return FilledButton(
      onPressed: isLoading ? null : () => _handlePurchase(selectedPlan),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.amber[600],
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              '立即訂閱 ${selectedPlan.priceString}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildDisclaimer(ThemeData theme) {
    return Text(
      '訂閱將透過 Google Play 帳戶收費。\n'
      '訂閱會自動續訂，除非在當期結束前至少 24 小時取消。\n'
      '您可以在 Google Play 商店管理或取消訂閱。',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }

  Future<void> _handlePurchase(SubscriptionProduct plan) async {
    // 查找對應的 ProductDetails
    final products = _subscriptionService.products;
    final productDetails = products.firstWhere(
      (p) => p.id == plan.productId,
      orElse: () => throw Exception('找不到商品'),
    );

    final success = await _subscriptionService.purchaseSubscription(productDetails);
    
    if (!success && mounted) {
      final error = _subscriptionService.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? '購買失敗，請稍後再試'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

/// 升級提示對話框
/// 
/// 在用戶嘗試使用 Premium 功能時顯示
class UpgradePromptDialog extends StatelessWidget {
  final String feature;
  final String? description;

  const UpgradePromptDialog({
    super.key,
    required this.feature,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock, color: Colors.amber[600]),
          const SizedBox(width: 8),
          const Text('Premium 功能'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '「$feature」是 Premium 專屬功能',
            style: theme.textTheme.bodyLarge,
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '升級 Premium 即可解鎖：',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildBenefit('自動帶入即時報價'),
          _buildBenefit('歷史紀錄儲存'),
          _buildBenefit('多帳戶管理'),
          _buildBenefit('無廣告體驗'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('稍後再說'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber[600],
          ),
          child: const Text('查看方案'),
        ),
      ],
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  /// 顯示升級提示
  static Future<bool> show(
    BuildContext context, {
    required String feature,
    String? description,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => UpgradePromptDialog(
        feature: feature,
        description: description,
      ),
    );

    if (result == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SubscriptionScreen(),
        ),
      );
      return SubscriptionService().isPremium;
    }

    return false;
  }
}

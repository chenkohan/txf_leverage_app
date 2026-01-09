/// Premium 功能限制元件
/// 
/// 包裝需要 Premium 才能使用的功能
library;

import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_screen.dart';

/// 功能限制包裝器
/// 
/// 使用方式:
/// ```dart
/// PremiumFeatureGate(
///   feature: '歷史紀錄',
///   child: HistoryButton(),
/// )
/// ```
class PremiumFeatureGate extends StatelessWidget {
  /// 功能名稱（用於提示）
  final String feature;
  
  /// Premium 用戶看到的內容
  final Widget child;
  
  /// 免費用戶看到的內容（可選）
  final Widget? freeChild;
  
  /// 功能說明
  final String? description;
  
  /// 是否顯示鎖定圖示
  final bool showLockIcon;

  const PremiumFeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.freeChild,
    this.description,
    this.showLockIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionService = SubscriptionService();

    return ListenableBuilder(
      listenable: subscriptionService,
      builder: (context, _) {
        if (subscriptionService.isPremium) {
          return child;
        }
        
        if (freeChild != null) {
          return freeChild!;
        }

        // 預設：顯示帶鎖定的按鈕
        return _LockedFeature(
          feature: feature,
          description: description,
          showLockIcon: showLockIcon,
          child: child,
        );
      },
    );
  }
}

class _LockedFeature extends StatelessWidget {
  final String feature;
  final String? description;
  final bool showLockIcon;
  final Widget child;

  const _LockedFeature({
    required this.feature,
    this.description,
    required this.showLockIcon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showUpgradePrompt(context),
      child: Stack(
        children: [
          // 原本的 Widget（半透明）
          Opacity(
            opacity: 0.5,
            child: AbsorbPointer(child: child),
          ),
          
          // 鎖定圖示
          if (showLockIcon)
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock,
                        color: Colors.amber[400],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showUpgradePrompt(BuildContext context) async {
    await UpgradePromptDialog.show(
      context,
      feature: feature,
      description: description,
    );
  }
}

/// Premium 功能按鈕
/// 
/// 點擊時檢查是否為 Premium，否則顯示升級提示
class PremiumButton extends StatelessWidget {
  final String feature;
  final String? description;
  final VoidCallback onPressed;
  final Widget child;
  final ButtonStyle? style;

  const PremiumButton({
    super.key,
    required this.feature,
    required this.onPressed,
    required this.child,
    this.description,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionService = SubscriptionService();

    return ListenableBuilder(
      listenable: subscriptionService,
      builder: (context, _) {
        final isPremium = subscriptionService.isPremium;

        return ElevatedButton(
          style: style,
          onPressed: () async {
            if (isPremium) {
              onPressed();
            } else {
              final upgraded = await UpgradePromptDialog.show(
                context,
                feature: feature,
                description: description,
              );
              if (upgraded) {
                onPressed();
              }
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              if (!isPremium) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.lock,
                  size: 14,
                  color: Colors.amber[600],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Premium Icon Button
class PremiumIconButton extends StatelessWidget {
  final String feature;
  final String? description;
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? color;

  const PremiumIconButton({
    super.key,
    required this.feature,
    required this.onPressed,
    required this.icon,
    this.description,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionService = SubscriptionService();

    return ListenableBuilder(
      listenable: subscriptionService,
      builder: (context, _) {
        final isPremium = subscriptionService.isPremium;

        return IconButton(
          icon: Stack(
            children: [
              Icon(icon, color: color),
              if (!isPremium)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Icon(
                    Icons.lock,
                    size: 12,
                    color: Colors.amber[600],
                  ),
                ),
            ],
          ),
          tooltip: isPremium ? tooltip : '$tooltip (Premium)',
          onPressed: () async {
            if (isPremium) {
              onPressed();
            } else {
              final upgraded = await UpgradePromptDialog.show(
                context,
                feature: feature,
                description: description,
              );
              if (upgraded) {
                onPressed();
              }
            }
          },
        );
      },
    );
  }
}

/// 檢查 Premium 狀態的 Mixin
mixin PremiumFeatureMixin<T extends StatefulWidget> on State<T> {
  SubscriptionService get subscriptionService => SubscriptionService();
  
  bool get isPremium => subscriptionService.isPremium;
  bool get isFree => subscriptionService.isFree;

  /// 執行 Premium 功能，如果不是 Premium 則顯示升級提示
  Future<bool> requirePremium({
    required String feature,
    String? description,
  }) async {
    if (isPremium) return true;

    return UpgradePromptDialog.show(
      context,
      feature: feature,
      description: description,
    );
  }
}

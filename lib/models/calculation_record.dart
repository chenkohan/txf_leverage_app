import 'dart:convert';

/// 計算紀錄資料模型
class CalculationRecord {
  final String id; // 唯一識別碼 (使用時間戳)
  final DateTime timestamp; // 計算時間
  final int futuresType; // 期貨類型 (0=大台, 1=小台, 2=微台)
  final double currentPrice; // 當時價格
  final String priceSource; // 價格來源 (A6, A6 PM, 手動, 記錄)
  final double equity; // 權益數
  final double leverage; // 槓桿倍率
  final double theoreticalContracts; // 理論口數
  final int conservativeContracts; // 保守口數
  final double conservativeLeverage; // 保守實際槓桿
  final double conservativeExposure; // 保守曝險
  final int aggressiveContracts; // 積極口數
  final double aggressiveLeverage; // 積極實際槓桿
  final double aggressiveExposure; // 積極曝險

  CalculationRecord({
    required this.id,
    required this.timestamp,
    required this.futuresType,
    required this.currentPrice,
    required this.priceSource,
    required this.equity,
    required this.leverage,
    required this.theoreticalContracts,
    required this.conservativeContracts,
    required this.conservativeLeverage,
    required this.conservativeExposure,
    required this.aggressiveContracts,
    required this.aggressiveLeverage,
    required this.aggressiveExposure,
  });

  /// 從 Map 建立物件
  factory CalculationRecord.fromMap(Map<String, dynamic> map) {
    return CalculationRecord(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      futuresType: map['futuresType'] as int,
      currentPrice: (map['currentPrice'] as num).toDouble(),
      priceSource: map['priceSource'] as String,
      equity: (map['equity'] as num).toDouble(),
      leverage: (map['leverage'] as num).toDouble(),
      theoreticalContracts: (map['theoreticalContracts'] as num).toDouble(),
      conservativeContracts: map['conservativeContracts'] as int,
      conservativeLeverage: (map['conservativeLeverage'] as num).toDouble(),
      conservativeExposure: (map['conservativeExposure'] as num).toDouble(),
      aggressiveContracts: map['aggressiveContracts'] as int,
      aggressiveLeverage: (map['aggressiveLeverage'] as num).toDouble(),
      aggressiveExposure: (map['aggressiveExposure'] as num).toDouble(),
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'futuresType': futuresType,
      'currentPrice': currentPrice,
      'priceSource': priceSource,
      'equity': equity,
      'leverage': leverage,
      'theoreticalContracts': theoreticalContracts,
      'conservativeContracts': conservativeContracts,
      'conservativeLeverage': conservativeLeverage,
      'conservativeExposure': conservativeExposure,
      'aggressiveContracts': aggressiveContracts,
      'aggressiveLeverage': aggressiveLeverage,
      'aggressiveExposure': aggressiveExposure,
    };
  }

  /// 轉換為 JSON 字串
  String toJson() => jsonEncode(toMap());

  /// 從 JSON 字串建立物件
  factory CalculationRecord.fromJson(String source) =>
      CalculationRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// 取得期貨名稱
  String get futuresName {
    switch (futuresType) {
      case 0:
        return '大台(TX)';
      case 1:
        return '小台(MTX)';
      case 2:
        return '微台(TMF)';
      default:
        return '未知';
    }
  }

  /// 取得點值
  int get pointValue {
    switch (futuresType) {
      case 0:
        return 200;
      case 1:
        return 50;
      case 2:
        return 10;
      default:
        return 200;
    }
  }
}

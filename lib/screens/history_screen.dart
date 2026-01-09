import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/calculation_record.dart';

/// 歷史紀錄頁面
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<CalculationRecord> _records = [];
  bool _isLoading = true;
  final _numberFormat = NumberFormat('#,###', 'zh_TW');
  final _dateFormat = DateFormat('MM/dd HH:mm', 'zh_TW');

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  /// 從 SharedPreferences 載入歷史紀錄
  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList('calculation_records') ?? [];

      final records = recordsJson
          .map((json) => CalculationRecord.fromJson(json))
          .toList();

      // 依時間排序 (最新在前)
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入失敗: $e')),
        );
      }
    }
  }

  /// 刪除單筆紀錄
  Future<void> _deleteRecord(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList('calculation_records') ?? [];

      // 過濾掉要刪除的紀錄
      final updatedRecords = recordsJson.where((json) {
        final record = CalculationRecord.fromJson(json);
        return record.id != id;
      }).toList();

      await prefs.setStringList('calculation_records', updatedRecords);

      setState(() {
        _records.removeWhere((record) => record.id == id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已刪除'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗: $e')),
        );
      }
    }
  }

  /// 清空所有紀錄
  Future<void> _clearAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認清空', style: TextStyle(fontSize: 16)),
        content: const Text('確定要刪除所有歷史紀錄嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('calculation_records');
        setState(() => _records.clear());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已清空所有紀錄')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清空失敗: $e')),
          );
        }
      }
    }
  }

  /// 顯示紀錄詳情
  void _showRecordDetail(CalculationRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${record.futuresName} - ${_dateFormat.format(record.timestamp)}',
          style: const TextStyle(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('時間', _dateFormat.format(record.timestamp)),
              _detailRow('期貨', record.futuresName),
              _detailRow('價格', '${_numberFormat.format(record.currentPrice.round())} (${record.priceSource})'),
              _detailRow('權益數', '${_numberFormat.format(record.equity.round())} 元'),
              _detailRow('槓桿倍率', '${record.leverage.toStringAsFixed(1)} 倍'),
              const Divider(height: 20),
              _detailRow('理論口數', record.theoreticalContracts.toStringAsFixed(2)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('保守方案', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 4),
                    _detailRow('口數', '${record.conservativeContracts} 口'),
                    _detailRow('實際槓桿', '${record.conservativeLeverage.toStringAsFixed(2)} 倍'),
                    _detailRow('曝險金額', '${_numberFormat.format(record.conservativeExposure.round())} 元'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('積極方案', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 4),
                    _detailRow('口數', '${record.aggressiveContracts} 口'),
                    _detailRow('實際槓桿', '${record.aggressiveLeverage.toStringAsFixed(2)} 倍'),
                    _detailRow('曝險金額', '${_numberFormat.format(record.aggressiveExposure.round())} 元'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歷史紀錄', style: TextStyle(fontSize: 18)),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllRecords,
              tooltip: '清空全部',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '尚無歷史紀錄',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '完成計算後會自動儲存紀錄',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Dismissible(
                        key: Key(record.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('確認刪除', style: TextStyle(fontSize: 16)),
                              content: const Text('確定要刪除此筆紀錄嗎？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('取消'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('刪除'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) => _deleteRecord(record.id),
                        child: ListTile(
                          onTap: () => _showRecordDetail(record),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getFuturesColor(record.futuresType).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.show_chart,
                              color: _getFuturesColor(record.futuresType),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                record.futuresName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: Colors.blue.shade200, width: 0.5),
                                ),
                                child: Text(
                                  record.priceSource,
                                  style: TextStyle(fontSize: 9, color: Colors.blue.shade700),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                _dateFormat.format(record.timestamp),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_numberFormat.format(record.currentPrice.round())} ｜ ${record.leverage.toStringAsFixed(1)}倍 ｜ ${record.theoreticalContracts.toStringAsFixed(1)}口',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${record.conservativeContracts}口',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                '${record.aggressiveContracts}口',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getFuturesColor(int type) {
    switch (type) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.purple;
      case 2:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

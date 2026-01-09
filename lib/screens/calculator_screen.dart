import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../widgets/ad_banner.dart';
import '../models/calculation_record.dart';
import 'settings_screen.dart';
import 'history_screen.dart';

class CalculatorScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeChanged;

  const CalculatorScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> with WidgetsBindingObserver {
  int _futuresType = 0;
  double _currentPrice = 0.0;
  bool _isLoadingPrice = false;
  String _priceSource = '';
  String _priceError = '';
  bool _isManualPrice = false;
  String _lastError = '';
  bool _isNightSession = false;

  final _equityController = TextEditingController(text: '3000000');
  final _leverageController = TextEditingController(text: '2');
  final _manualPriceController = TextEditingController();

  // 商品設定 - 期交所 API CID
  // TXF=大台, MXF=小台, TMF=微台
  static const Map<int, int> pointValues = {0: 200, 1: 50, 2: 10};
  static const Map<int, String> futuresNames = {0: '大台(TX)', 1: '小台(MTX)', 2: '微台(TMF)'};
  static const Map<int, String> symbolCIDs = {0: 'TXF', 1: 'MXF', 2: 'TMF'};

  final _numberFormat = NumberFormat('#,###', 'zh_TW');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveSettings();
    _equityController.dispose();
    _leverageController.dispose();
    _manualPriceController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveSettings();
    }
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _futuresType = prefs.getInt('futuresType') ?? 0;
        _equityController.text = prefs.getString('equity') ?? '3000000';
        _leverageController.text = prefs.getString('leverage') ?? '2';
      });
      _fetchPrice();
    } catch (e) {
      _fetchPrice();
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('futuresType', _futuresType);
      await prefs.setString('equity', _equityController.text);
      await prefs.setString('leverage', _leverageController.text);
    } catch (e) {}
  }

  Future<void> _savePriceRecord(double price, int type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('savedPrice_$type', price);
      await prefs.setString('savedPriceTime_$type', DateTime.now().toIso8601String());
    } catch (e) {}
  }

  Future<double?> _loadSavedPrice(int type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble('savedPrice_$type');
    } catch (e) {
      return null;
    }
  }

  // 判斷現在應該顯示日盤還是夜盤
  // 日盤: 08:45-15:00 (MarketType=0, SymbolID 以 -F 結尾)
  // 夜盤: 其他時間 (MarketType=1, SymbolID 以 -M 結尾)
  bool _shouldShowDaySession() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final totalMinutes = hour * 60 + minute;
    
    // 08:45 = 525 分鐘, 15:00 = 900 分鐘
    return totalMinutes >= 525 && totalMinutes < 900;
  }

  Future<void> _fetchPrice() async {
    setState(() { _isLoadingPrice = true; _priceError = ''; _lastError = ''; });

    final cid = symbolCIDs[_futuresType] ?? 'TXF';
    final isDaySession = _shouldShowDaySession();
    
    // 根據時間決定查詢順序
    // 日盤時間: 先查日盤(0)，失敗再查夜盤(1)
    // 夜盤時間: 先查夜盤(1)，失敗再查日盤(0)
    final marketTypes = isDaySession ? ['0', '1'] : ['1', '0'];
    final suffixes = isDaySession ? ['-F', '-M'] : ['-M', '-F'];

    for (int i = 0; i < marketTypes.length; i++) {
      final marketType = marketTypes[i];
      final suffix = suffixes[i];
      
      try {
        final url = Uri.parse('https://mis.taifex.com.tw/futures/api/getQuoteList');
        final client = http.Client();
        
        final response = await client.post(url, headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
          'Origin': 'https://mis.taifex.com.tw',
          'Referer': 'https://mis.taifex.com.tw/futures/',
        }, body: jsonEncode({
          'MarketType': marketType,
          'SymbolType': 'F',
          'CID': cid,
        })).timeout(const Duration(seconds: 15));
        
        client.close();

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rtCode = data['RtCode']?.toString() ?? '';
          final quotes = data['RtData']?['QuoteList'] as List?;

          if (rtCode == '0' && quotes != null && quotes.isNotEmpty) {
            final matchedQuotes = <Map<String, dynamic>>[];

            for (var q in quotes) {
              final sid = q['SymbolID']?.toString() ?? '';
              final priceStr = q['CLastPrice']?.toString() ?? '';

              // 符合 CID 開頭，且符合對應的交易時段後綴
              if (sid.startsWith(cid) &&
                  sid.endsWith(suffix) &&
                  !sid.startsWith('MX2') &&
                  priceStr.isNotEmpty) {
                final price = double.tryParse(priceStr);
                if (price != null && price > 0) {
                  matchedQuotes.add({'sid': sid, 'price': price});
                }
              }
            }

            if (matchedQuotes.isNotEmpty) {
              matchedQuotes.sort((a, b) => (a['sid'] as String).compareTo(b['sid'] as String));
              final nearMonth = matchedQuotes.first;
              final sid = nearMonth['sid'] as String;
              final price = nearMonth['price'] as double;

              // 判斷是否為夜盤
              final isNight = sid.endsWith('-M');
              final sessionLabel = isNight ? 'PM' : '';
              // 簡化顯示: TXFA6-F -> A6, TXFA6-M -> A6 PM
              final shortName = sid.replaceAll(cid, '').replaceAll('-F', '').replaceAll('-M', '');

              setState(() {
                _currentPrice = price;
                _priceSource = sessionLabel.isEmpty ? shortName : '$shortName $sessionLabel';
                _isLoadingPrice = false;
                _isManualPrice = false;
                _isNightSession = isNight;
              });
              await _savePriceRecord(price, _futuresType);
              return;
            }
          } else if (rtCode != '0') {
            _lastError = 'API:$rtCode';
          }
        } else {
          _lastError = 'HTTP ${response.statusCode}';
        }
      } on SocketException catch (e) {
        _lastError = '網路連線失敗';
      } on HttpException catch (e) {
        _lastError = 'HTTP錯誤';
      } on FormatException catch (e) {
        _lastError = '資料格式錯誤';
      } catch (e) {
        _lastError = '${e.runtimeType}';
      }
    }

    await _useSavedPrice();
  }

  Future<void> _useSavedPrice() async {
    final savedPrice = await _loadSavedPrice(_futuresType);
    if (savedPrice != null && savedPrice > 0) {
      setState(() {
        _currentPrice = savedPrice;
        _priceSource = '記錄';
        _isLoadingPrice = false;
        _isManualPrice = true;
      });
    } else {
      setState(() {
        _priceError = _lastError.isNotEmpty ? _lastError : '無法取得';
        _isLoadingPrice = false;
      });
    }
  }

  void _showManualPriceDialog() {
    _manualPriceController.text = _currentPrice > 0 ? _currentPrice.round().toString() : '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手動輸入價格', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _manualPriceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '期貨點數',
                hintText: '例如: 22350',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            if (_lastError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('錯誤: $_lastError', style: const TextStyle(color: Colors.red, fontSize: 11)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(_manualPriceController.text);
              if (price != null && price > 0) {
                setState(() {
                  _currentPrice = price;
                  _priceSource = '手動';
                  _priceError = '';
                  _isManualPrice = true;
                });
                await _savePriceRecord(price, _futuresType);
                Navigator.pop(context);
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _showErrorDetail() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('連線問題', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('錯誤: ${_lastError.isNotEmpty ? _lastError : "未知"}'),
            const SizedBox(height: 12),
            const Text('可能原因:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(' 公司/學校網路封鎖', style: TextStyle(fontSize: 13)),
            const Text(' 期交所伺服器維護中', style: TextStyle(fontSize: 13)),
            const Text(' 非台灣地區 IP', style: TextStyle(fontSize: 13)),
            const Text(' 手機網路不穩定', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            const Text('建議:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(' 切換到行動數據試試', style: TextStyle(fontSize: 13)),
            const Text(' 點擊價格區域手動輸入', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualPriceDialog();
            },
            child: const Text('手動輸入'),
          ),
        ],
      ),
    );
  }

  int get _pointValue => pointValues[_futuresType] ?? 200;
  String get _currentFuturesName => futuresNames[_futuresType] ?? '大台';

  double get _calc {
    final eq = double.tryParse(_equityController.text) ?? 0;
    final lv = double.tryParse(_leverageController.text) ?? 0;
    if (_currentPrice <= 0 || _pointValue <= 0) return 0;
    return (eq * lv) / (_currentPrice * _pointValue);
  }
  int get _floor => _calc.floor();
  int get _ceil => _calc.ceil();
  double _actualLev(int c) {
    final eq = double.tryParse(_equityController.text) ?? 1;
    return eq > 0 ? (c * _currentPrice * _pointValue) / eq : 0;
  }

  void _onTypeChanged(Set<int> s) {
    setState(() => _futuresType = s.first);
    _saveSettings();
    _fetchPrice();
  }

  void _onInput(String _) { setState(() {}); _saveSettings(); }

  /// 儲存計算紀錄到歷史
  Future<void> _saveCalculationRecord() async {
    // 只有在有效計算結果時才儲存
    if (_currentPrice <= 0 || _calc <= 0) return;

    try {
      final record = CalculationRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        futuresType: _futuresType,
        currentPrice: _currentPrice,
        priceSource: _priceSource,
        equity: double.tryParse(_equityController.text) ?? 0,
        leverage: double.tryParse(_leverageController.text) ?? 0,
        theoreticalContracts: _calc,
        conservativeContracts: _floor,
        conservativeLeverage: _actualLev(_floor),
        conservativeExposure: _floor * _currentPrice * _pointValue,
        aggressiveContracts: _ceil,
        aggressiveLeverage: _actualLev(_ceil),
        aggressiveExposure: _ceil * _currentPrice * _pointValue,
      );

      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList('calculation_records') ?? [];

      // 加入新紀錄到列表開頭
      recordsJson.insert(0, record.toJson());

      // 限制最多保留 100 筆紀錄
      if (recordsJson.length > 100) {
        recordsJson.removeRange(100, recordsJson.length);
      }

      await prefs.setStringList('calculation_records', recordsJson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已儲存計算紀錄'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // 儲存失敗不影響使用
      debugPrint('儲存紀錄失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cid = symbolCIDs[_futuresType] ?? 'TXF';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 80,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _priceError.isNotEmpty ? _showErrorDetail : _showManualPriceDialog,
                            child: Row(children: [
                              Text('$cid ', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                              if (_isLoadingPrice)
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              else if (_priceError.isNotEmpty)
                                Flexible(
                                  child: Row(children: [
                                    Flexible(
                                      child: Text(_priceError, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('點擊', style: TextStyle(color: Colors.white, fontSize: 10)),
                                    ),
                                  ]),
                                )
                              else
                                Row(children: [
                                  Text(
                                    _numberFormat.format(_currentPrice.round()),
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isManualPrice ? Colors.orange : (_isNightSession ? Colors.purple : Colors.blue)),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _isManualPrice ? Colors.orange.shade100 : (_isNightSession ? Colors.purple.shade50 : Colors.blue.shade50),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: _isManualPrice ? Colors.orange : (_isNightSession ? Colors.purple : Colors.blue.shade200), width: 0.5),
                                    ),
                                    child: Text(_priceSource, style: TextStyle(fontSize: 9, color: _isManualPrice ? Colors.orange.shade800 : (_isNightSession ? Colors.purple.shade700 : Colors.blue.shade700))),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                                ]),
                            ]),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _isLoadingPrice ? null : _fetchPrice,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.history, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HistoryScreen(),
                              ),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '歷史紀錄',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.settings, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsScreen(
                                  currentThemeMode: widget.currentThemeMode,
                                  onThemeChanged: widget.onThemeChanged,
                                ),
                              ),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '設定',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('大台')),
                        ButtonSegment(value: 1, label: Text('小台')),
                        ButtonSegment(value: 2, label: Text('微台')),
                      ],
                      selected: {_futuresType},
                      onSelectionChanged: _onTypeChanged,
                      style: ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('$_currentFuturesName ｜每點 $_pointValue 元', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _equityController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: '權益數', suffixText: '元', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                            onChanged: _onInput,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _leverageController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            decoration: const InputDecoration(labelText: '槓桿倍率', suffixText: '倍', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                            onChanged: _onInput,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_currentPrice > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text('理論口數: ${_calc.toStringAsFixed(2)} 口', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                      ),
                      const SizedBox(height: 10),
                      _resultRow('保守', _floor, _actualLev(_floor), Colors.green),
                      const SizedBox(height: 8),
                      _resultRow('積極', _ceil, _actualLev(_ceil), Colors.orange),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveCalculationRecord,
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('儲存此次計算'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text(' 期貨風險高,可能損失超過本金,建議槓桿3倍以下', style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(flex: 20, child: AdBannerWidget()),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, int contracts, double leverage, Color color) {
    final exposure = contracts * _currentPrice * _pointValue;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Text('$contracts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                  Text('口', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ]),
                Column(children: [
                  Text(leverage.toStringAsFixed(2), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                  Text('倍', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ]),
                Column(children: [
                  Text(_numberFormat.format(exposure.round()), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                  Text('曝險', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
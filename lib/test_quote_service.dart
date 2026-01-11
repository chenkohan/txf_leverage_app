/// 報價服務測試腳本
/// 
/// 測試 Yahoo Finance 備援報價功能
/// 執行方式: flutter run -t lib/test_quote_service.dart
library;

import 'package:flutter/material.dart';
import 'services/services.dart';

void main() {
  runApp(const QuoteTestApp());
}

class QuoteTestApp extends StatelessWidget {
  const QuoteTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '報價服務測試',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const QuoteTestScreen(),
    );
  }
}

class QuoteTestScreen extends StatefulWidget {
  const QuoteTestScreen({super.key});

  @override
  State<QuoteTestScreen> createState() => _QuoteTestScreenState();
}

class _QuoteTestScreenState extends State<QuoteTestScreen> {
  final QuoteService _quoteService = QuoteService();
  final List<String> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  void _log(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
    debugPrint(message);
  }

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
    });

    try {
      _log('📦 初始化報價服務...');
      await _quoteService.initialize();
      _log('✅ 服務狀態: ${_quoteService.getStatus()}');

      // 測試 1: 股票報價
      _log('\n🧪 測試 1: 股票報價 (AAPL)');
      final stockResult = await _quoteService.getQuote('AAPL');
      if (stockResult.isSuccess) {
        _log('✅ ${stockResult.quote!.symbol}: \$${stockResult.quote!.currentPrice.toStringAsFixed(2)}');
        _log('   來源: ${stockResult.source.name}, 耗時: ${stockResult.responseTime.inMilliseconds}ms');
      } else {
        _log('❌ 失敗: ${stockResult.errorMessage}');
      }

      // 測試 2: 期貨報價 (ES)
      _log('\n🧪 測試 2: 期貨報價 (ES - S&P 500)');
      final esResult = await _quoteService.getFuturesQuote('ES');
      if (esResult.isSuccess) {
        _log('✅ ES: \$${esResult.quote!.currentPrice.toStringAsFixed(2)}');
        _log('   漲跌: ${esResult.quote!.changeFormatted}');
        _log('   來源: ${esResult.source.name}');
      } else {
        _log('❌ 失敗: ${esResult.errorMessage}');
      }

      // 測試 3: 期貨報價 (NQ)
      _log('\n🧪 測試 3: 期貨報價 (NQ - Nasdaq 100)');
      final nqResult = await _quoteService.getFuturesQuote('NQ');
      if (nqResult.isSuccess) {
        _log('✅ NQ: \$${nqResult.quote!.currentPrice.toStringAsFixed(2)}');
        _log('   漲跌: ${nqResult.quote!.changeFormatted}');
        _log('   來源: ${nqResult.source.name}');
      } else {
        _log('❌ 失敗: ${nqResult.errorMessage}');
      }

      // 測試 4: 期貨報價 (YM)
      _log('\n🧪 測試 4: 期貨報價 (YM - Dow Jones)');
      final ymResult = await _quoteService.getFuturesQuote('YM');
      if (ymResult.isSuccess) {
        _log('✅ YM: \$${ymResult.quote!.currentPrice.toStringAsFixed(2)}');
        _log('   漲跌: ${ymResult.quote!.changeFormatted}');
        _log('   來源: ${ymResult.source.name}');
      } else {
        _log('❌ 失敗: ${ymResult.errorMessage}');
      }

      // 測試 5: 批次取得主要指數期貨
      _log('\n🧪 測試 5: 批次取得主要指數期貨');
      final majorFutures = await _quoteService.getMajorIndexFutures();
      for (final entry in majorFutures.entries) {
        if (entry.value.isSuccess) {
          final q = entry.value.quote!;
          _log('✅ ${entry.key}: \$${q.currentPrice.toStringAsFixed(2)} (${q.changeFormatted})');
        } else {
          _log('❌ ${entry.key}: ${entry.value.errorMessage}');
        }
      }

      // 測試 6: 直接使用 Yahoo Finance
      _log('\n🧪 測試 6: 直接使用 Yahoo Finance (SPY)');
      final yahooResult = await _quoteService.getQuote('SPY', source: QuoteSource.yahooFinance);
      if (yahooResult.isSuccess) {
        _log('✅ SPY: \$${yahooResult.quote!.currentPrice.toStringAsFixed(2)}');
        _log('   來源: ${yahooResult.source.name}');
      } else {
        _log('❌ 失敗: ${yahooResult.errorMessage}');
      }

      _log('\n✅ 所有測試完成！');

    } catch (e) {
      _log('❌ 測試發生錯誤: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('報價服務測試'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _runTests,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                Color? color;
                if (log.contains('✅')) {
                  color = Colors.green.shade700;
                } else if (log.contains('❌')) {
                  color = Colors.red.shade700;
                } else if (log.contains('🧪')) {
                  color = Colors.blue.shade700;
                }
                return Text(
                  log,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: color,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

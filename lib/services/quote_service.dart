/// 統一報價服務
/// 
/// 整合多個報價來源，提供自動備援機制
/// 主要來源：Finnhub API
/// 備援來源：Yahoo Finance
/// 
/// 使用方式：
/// ```dart
/// final service = QuoteService();
/// await service.initialize();
/// final quote = await service.getQuote('AAPL');
/// final futuresQuote = await service.getFuturesQuote('ES');
/// ```
library;

import 'package:flutter/foundation.dart';
import 'finnhub_service.dart';
import 'yahoo_finance_service.dart';
import 'env_service.dart';

/// 報價來源列舉
enum QuoteSource {
  finnhub,
  yahooFinance,
  auto, // 自動選擇（優先 Finnhub，失敗則用 Yahoo Finance）
}

/// 報價結果（包含來源資訊）
class QuoteResult {
  final StockQuote? quote;
  final QuoteSource source;
  final bool isSuccess;
  final String? errorMessage;
  final Duration responseTime;

  QuoteResult({
    this.quote,
    required this.source,
    required this.isSuccess,
    this.errorMessage,
    required this.responseTime,
  });

  @override
  String toString() {
    if (isSuccess && quote != null) {
      return 'QuoteResult(${quote!.symbol}: \$${quote!.currentPrice}, source: ${source.name}, time: ${responseTime.inMilliseconds}ms)';
    }
    return 'QuoteResult(failed: $errorMessage, source: ${source.name})';
  }
}

/// 統一報價服務
/// 
/// 提供自動備援機制的報價查詢服務
/// 優先使用 Finnhub，若失敗則自動切換到 Yahoo Finance
class QuoteService {
  static final QuoteService _instance = QuoteService._internal();
  factory QuoteService() => _instance;
  QuoteService._internal();

  final FinnhubService _finnhubService = FinnhubService();
  final YahooFinanceService _yahooFinanceService = YahooFinanceService();
  final EnvService _envService = EnvService();

  bool _isInitialized = false;
  bool _finnhubAvailable = false;
  
  /// 預設報價來源
  QuoteSource _defaultSource = QuoteSource.auto;

  /// 連續失敗計數器（用於智能切換）
  int _finnhubFailCount = 0;
  int _yahooFailCount = 0;
  static const int _maxFailCount = 3;

  /// 初始化服務
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _envService.load();
    
    // 檢查 Finnhub API Key
    final finnhubKey = _envService.get(EnvKeys.finnhubApiKey);
    if (finnhubKey != null && finnhubKey.isNotEmpty) {
      FinnhubService.setApiKey(finnhubKey);
      _finnhubAvailable = true;
      debugPrint('QuoteService: Finnhub initialized');
    } else {
      debugPrint('QuoteService: Finnhub API key not found, using Yahoo Finance only');
      _finnhubAvailable = false;
    }

    _isInitialized = true;
    debugPrint('QuoteService: Initialized (Finnhub: $_finnhubAvailable)');
  }

  /// 設定預設報價來源
  void setDefaultSource(QuoteSource source) {
    _defaultSource = source;
  }

  /// 取得報價（自動備援機制）
  /// 
  /// [symbol]: 股票/期貨代碼
  /// [source]: 指定報價來源，預設為 auto（自動備援）
  Future<QuoteResult> getQuote(String symbol, {QuoteSource? source}) async {
    await initialize();
    
    final effectiveSource = source ?? _defaultSource;
    final stopwatch = Stopwatch()..start();

    switch (effectiveSource) {
      case QuoteSource.finnhub:
        return await _getFromFinnhub(symbol, stopwatch);
      case QuoteSource.yahooFinance:
        return await _getFromYahoo(symbol, stopwatch);
      case QuoteSource.auto:
        return await _getWithFallback(symbol, stopwatch);
    }
  }

  /// 取得期貨報價
  /// 
  /// [symbol]: 期貨代碼（ES, NQ, YM 等）
  /// 自動使用 Yahoo Finance（因為 Finnhub 免費版不支援期貨）
  Future<QuoteResult> getFuturesQuote(String symbol, {QuoteSource? source}) async {
    await initialize();
    
    final stopwatch = Stopwatch()..start();
    
    // 期貨報價優先使用 Yahoo Finance（因為 Finnhub 免費版不支援）
    final effectiveSource = source ?? QuoteSource.yahooFinance;

    if (effectiveSource == QuoteSource.yahooFinance || effectiveSource == QuoteSource.auto) {
      try {
        final quote = await _yahooFinanceService.getFuturesQuote(symbol);
        stopwatch.stop();
        
        if (quote != null && quote.currentPrice > 0) {
          _yahooFailCount = 0;
          return QuoteResult(
            quote: quote,
            source: QuoteSource.yahooFinance,
            isSuccess: true,
            responseTime: stopwatch.elapsed,
          );
        }
      } catch (e) {
        _yahooFailCount++;
        debugPrint('QuoteService: Yahoo Finance futures error: $e');
      }
    }

    // 若 Yahoo Finance 失敗，嘗試 Finnhub（使用 ETF 替代）
    if (_finnhubAvailable && effectiveSource != QuoteSource.yahooFinance) {
      try {
        final quote = await _finnhubService.getFuturesQuote(symbol);
        stopwatch.stop();
        
        if (quote != null && quote.currentPrice > 0) {
          _finnhubFailCount = 0;
          return QuoteResult(
            quote: quote,
            source: QuoteSource.finnhub,
            isSuccess: true,
            errorMessage: 'Using ETF substitute',
            responseTime: stopwatch.elapsed,
          );
        }
      } catch (e) {
        _finnhubFailCount++;
        debugPrint('QuoteService: Finnhub futures error: $e');
      }
    }

    stopwatch.stop();
    return QuoteResult(
      source: QuoteSource.auto,
      isSuccess: false,
      errorMessage: 'All sources failed for futures: $symbol',
      responseTime: stopwatch.elapsed,
    );
  }

  /// 批次取得多個報價
  Future<Map<String, QuoteResult>> getMultipleQuotes(List<String> symbols) async {
    await initialize();
    
    final results = <String, QuoteResult>{};
    
    // 優先嘗試 Yahoo Finance 批次查詢
    try {
      final yahooQuotes = await _yahooFinanceService.getMultipleQuotes(symbols);
      for (final entry in yahooQuotes.entries) {
        results[entry.key] = QuoteResult(
          quote: entry.value,
          source: QuoteSource.yahooFinance,
          isSuccess: true,
          responseTime: Duration.zero,
        );
      }
    } catch (e) {
      debugPrint('QuoteService: Batch Yahoo Finance error: $e');
    }

    // 對於缺失的報價，逐一嘗試其他來源
    for (final symbol in symbols) {
      if (!results.containsKey(symbol)) {
        final result = await getQuote(symbol);
        results[symbol] = result;
      }
    }

    return results;
  }

  /// 取得主要指數期貨報價
  Future<Map<String, QuoteResult>> getMajorIndexFutures() async {
    const symbols = MajorFutures.usIndexFutures;
    final results = <String, QuoteResult>{};

    for (final symbol in symbols) {
      results[symbol] = await getFuturesQuote(symbol);
    }

    return results;
  }

  /// 從 Finnhub 取得報價
  Future<QuoteResult> _getFromFinnhub(String symbol, Stopwatch stopwatch) async {
    if (!_finnhubAvailable) {
      stopwatch.stop();
      return QuoteResult(
        source: QuoteSource.finnhub,
        isSuccess: false,
        errorMessage: 'Finnhub API key not configured',
        responseTime: stopwatch.elapsed,
      );
    }

    try {
      final quote = await _finnhubService.getQuote(symbol);
      stopwatch.stop();
      
      if (quote.currentPrice > 0) {
        _finnhubFailCount = 0;
        return QuoteResult(
          quote: quote,
          source: QuoteSource.finnhub,
          isSuccess: true,
          responseTime: stopwatch.elapsed,
        );
      } else {
        _finnhubFailCount++;
        return QuoteResult(
          source: QuoteSource.finnhub,
          isSuccess: false,
          errorMessage: 'Invalid quote data',
          responseTime: stopwatch.elapsed,
        );
      }
    } catch (e) {
      _finnhubFailCount++;
      stopwatch.stop();
      return QuoteResult(
        source: QuoteSource.finnhub,
        isSuccess: false,
        errorMessage: e.toString(),
        responseTime: stopwatch.elapsed,
      );
    }
  }

  /// 從 Yahoo Finance 取得報價
  Future<QuoteResult> _getFromYahoo(String symbol, Stopwatch stopwatch) async {
    try {
      final quote = await _yahooFinanceService.getQuote(symbol);
      stopwatch.stop();
      
      if (quote != null && quote.currentPrice > 0) {
        _yahooFailCount = 0;
        return QuoteResult(
          quote: quote,
          source: QuoteSource.yahooFinance,
          isSuccess: true,
          responseTime: stopwatch.elapsed,
        );
      } else {
        _yahooFailCount++;
        return QuoteResult(
          source: QuoteSource.yahooFinance,
          isSuccess: false,
          errorMessage: 'Invalid quote data',
          responseTime: stopwatch.elapsed,
        );
      }
    } catch (e) {
      _yahooFailCount++;
      stopwatch.stop();
      return QuoteResult(
        source: QuoteSource.yahooFinance,
        isSuccess: false,
        errorMessage: e.toString(),
        responseTime: stopwatch.elapsed,
      );
    }
  }

  /// 自動備援機制
  Future<QuoteResult> _getWithFallback(String symbol, Stopwatch stopwatch) async {
    // 根據失敗計數決定優先順序
    final finnhubFirst = _finnhubAvailable && _finnhubFailCount < _maxFailCount;

    if (finnhubFirst) {
      // 先嘗試 Finnhub
      final finnhubResult = await _getFromFinnhub(symbol, Stopwatch()..start());
      if (finnhubResult.isSuccess) {
        stopwatch.stop();
        return QuoteResult(
          quote: finnhubResult.quote,
          source: finnhubResult.source,
          isSuccess: true,
          responseTime: stopwatch.elapsed,
        );
      }

      // Finnhub 失敗，嘗試 Yahoo Finance
      debugPrint('QuoteService: Finnhub failed, trying Yahoo Finance for $symbol');
      final yahooResult = await _getFromYahoo(symbol, Stopwatch()..start());
      stopwatch.stop();
      
      if (yahooResult.isSuccess) {
        return QuoteResult(
          quote: yahooResult.quote,
          source: yahooResult.source,
          isSuccess: true,
          responseTime: stopwatch.elapsed,
        );
      }

      // 兩個來源都失敗
      return QuoteResult(
        source: QuoteSource.auto,
        isSuccess: false,
        errorMessage: 'All sources failed: Finnhub(${finnhubResult.errorMessage}), Yahoo(${yahooResult.errorMessage})',
        responseTime: stopwatch.elapsed,
      );
    } else {
      // Finnhub 不可用或失敗過多，直接使用 Yahoo Finance
      final yahooResult = await _getFromYahoo(symbol, Stopwatch()..start());
      stopwatch.stop();

      if (yahooResult.isSuccess) {
        return QuoteResult(
          quote: yahooResult.quote,
          source: yahooResult.source,
          isSuccess: true,
          responseTime: stopwatch.elapsed,
        );
      }

      // Yahoo Finance 失敗且 Finnhub 可用，嘗試 Finnhub
      if (_finnhubAvailable) {
        final finnhubResult = await _getFromFinnhub(symbol, Stopwatch()..start());
        if (finnhubResult.isSuccess) {
          return QuoteResult(
            quote: finnhubResult.quote,
            source: finnhubResult.source,
            isSuccess: true,
            responseTime: stopwatch.elapsed,
          );
        }
      }

      return QuoteResult(
        source: QuoteSource.auto,
        isSuccess: false,
        errorMessage: 'All sources failed',
        responseTime: stopwatch.elapsed,
      );
    }
  }

  /// 重置失敗計數器
  void resetFailCounts() {
    _finnhubFailCount = 0;
    _yahooFailCount = 0;
  }

  /// 取得服務狀態
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'finnhubAvailable': _finnhubAvailable,
      'finnhubFailCount': _finnhubFailCount,
      'yahooFailCount': _yahooFailCount,
      'defaultSource': _defaultSource.name,
    };
  }
}

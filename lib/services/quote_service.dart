/// 統一報價服務
/// 
/// 整合多個報價來源，提供自動備援機制
/// 主要來源：台灣期貨交易所 (台指期)
/// 備援來源：Yahoo Finance (美股/期貨)
/// 停用來源：Finnhub (原本的美股即時報價)
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
  taifex,       // 台灣期貨交易所（主要，台指期專用）
  yahooFinance, // Yahoo Finance（備援，美股/期貨）
  finnhub,      // Finnhub（停用）
  auto,         // 自動選擇（優先 Yahoo Finance）
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
/// 主要來源：台灣期貨交易所（台指期）、Yahoo Finance（美股/期貨）
/// Finnhub 已停用
class QuoteService {
  static final QuoteService _instance = QuoteService._internal();
  factory QuoteService() => _instance;
  QuoteService._internal();

  // ignore: unused_field - 保留以備未來使用
  final FinnhubService _finnhubService = FinnhubService();
  final YahooFinanceService _yahooFinanceService = YahooFinanceService();
  final EnvService _envService = EnvService();

  bool _isInitialized = false;
  
  /// Finnhub 是否啟用（目前停用）
  bool _finnhubEnabled = false;  // 停用 Finnhub
  
  /// 預設報價來源（優先使用 Yahoo Finance）
  QuoteSource _defaultSource = QuoteSource.yahooFinance;

  /// 連續失敗計數器（用於智能切換）
  // ignore: unused_field - 保留以備未來使用
  int _finnhubFailCount = 0;
  int _yahooFailCount = 0;
  // ignore: unused_field - 保留以備未來使用
  static const int _maxFailCount = 3;

  /// 初始化服務
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _envService.load();
    
    // Finnhub 已停用，但保留程式碼以備未來使用
    // 若要啟用，可設定 _finnhubEnabled = true 並提供 API Key
    final finnhubKey = _envService.get(EnvKeys.finnhubApiKey);
    if (_finnhubEnabled && finnhubKey != null && finnhubKey.isNotEmpty) {
      FinnhubService.setApiKey(finnhubKey);
      debugPrint('QuoteService: Finnhub initialized (currently disabled)');
    } else {
      debugPrint('QuoteService: Using Yahoo Finance as primary source');
    }

    _isInitialized = true;
    debugPrint('QuoteService: Initialized');
    debugPrint('QuoteService: Primary - 台灣期交所 (台指期) / Yahoo Finance (美股)');
    debugPrint('QuoteService: Finnhub - 停用');
  }

  /// 設定預設報價來源
  void setDefaultSource(QuoteSource source) {
    _defaultSource = source;
  }

  /// 取得報價（自動備援機制）
  /// 
  /// [symbol]: 股票/期貨代碼
  /// [source]: 指定報價來源，預設為 yahooFinance
  /// 
  /// 報價來源優先順序：
  /// 1. 台灣期貨交易所（台指期專用，透過 taifex）
  /// 2. Yahoo Finance（美股/期貨）
  /// 3. Finnhub（停用）
  Future<QuoteResult> getQuote(String symbol, {QuoteSource? source}) async {
    await initialize();
    
    final effectiveSource = source ?? _defaultSource;
    final stopwatch = Stopwatch()..start();

    switch (effectiveSource) {
      case QuoteSource.taifex:
        // 台灣期交所報價（待實作，目前使用 Yahoo Finance）
        return await _getFromYahoo(symbol, stopwatch);
      case QuoteSource.yahooFinance:
        return await _getFromYahoo(symbol, stopwatch);
      case QuoteSource.finnhub:
        // Finnhub 已停用，改用 Yahoo Finance
        debugPrint('QuoteService: Finnhub is disabled, using Yahoo Finance instead');
        return await _getFromYahoo(symbol, stopwatch);
      case QuoteSource.auto:
        return await _getWithFallback(symbol, stopwatch);
    }
  }

  /// 取得期貨報價
  /// 
  /// [symbol]: 期貨代碼（ES, NQ, YM 等）
  /// 美股期貨使用 Yahoo Finance，台指期使用台灣期交所
  Future<QuoteResult> getFuturesQuote(String symbol, {QuoteSource? source}) async {
    await initialize();
    
    final stopwatch = Stopwatch()..start();
    
    // 判斷是否為台灣期貨
    final isTaiwanFutures = _isTaiwanFutures(symbol);
    
    if (isTaiwanFutures) {
      // 台灣期貨使用台灣期交所（待實作）
      // TODO: 實作台灣期交所 API 整合
      debugPrint('QuoteService: Taiwan futures - TAIFEX (to be implemented)');
    }
    
    // 美股期貨使用 Yahoo Finance
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

    // Finnhub 已停用，不再作為備援
    // 若需要啟用 Finnhub 作為備援，可取消以下註解
    /*
    if (_finnhubEnabled) {
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
    */

    stopwatch.stop();
    return QuoteResult(
      source: QuoteSource.yahooFinance,
      isSuccess: false,
      errorMessage: 'Failed to get futures quote: $symbol',
      responseTime: stopwatch.elapsed,
    );
  }
  
  /// 判斷是否為台灣期貨
  bool _isTaiwanFutures(String symbol) {
    final taiwanFutures = ['TX', 'MTX', 'TXO', 'TE', 'TF', 'XIF'];
    return taiwanFutures.any((f) => symbol.toUpperCase().startsWith(f));
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

  /// 從 Finnhub 取得報價（已停用）
  /// 
  /// 注意：此方法已停用，所有請求將返回錯誤
  /// 若需啟用，請設定 _finnhubEnabled = true
  // ignore: unused_element - 保留以備未來使用
  Future<QuoteResult> _getFromFinnhub(String symbol, Stopwatch stopwatch) async {
    // Finnhub 已停用
    stopwatch.stop();
    return QuoteResult(
      source: QuoteSource.finnhub,
      isSuccess: false,
      errorMessage: 'Finnhub is disabled. Using Yahoo Finance instead.',
      responseTime: stopwatch.elapsed,
    );
    
    /* 原始程式碼（停用）
    if (!_finnhubEnabled) {
      stopwatch.stop();
      return QuoteResult(
        source: QuoteSource.finnhub,
        isSuccess: false,
        errorMessage: 'Finnhub is disabled',
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
    */
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
  /// 
  /// 順序：Yahoo Finance（Finnhub 已停用）
  Future<QuoteResult> _getWithFallback(String symbol, Stopwatch stopwatch) async {
    // 新順序：直接使用 Yahoo Finance（Finnhub 已停用）
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

    // Yahoo Finance 失敗（Finnhub 已停用，不再嘗試）
    return QuoteResult(
      source: QuoteSource.auto,
      isSuccess: false,
      errorMessage: 'Yahoo Finance failed: ${yahooResult.errorMessage}',
      responseTime: stopwatch.elapsed,
    );
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
      'primarySource': 'Yahoo Finance',
      'taifexSupport': 'Planned (台指期)',
      'finnhubEnabled': _finnhubEnabled,
      'finnhubStatus': 'Disabled (停用)',
      'yahooFailCount': _yahooFailCount,
      'defaultSource': _defaultSource.name,
    };
  }
  
  /// 啟用/停用 Finnhub（預設停用）
  void setFinnhubEnabled(bool enabled) {
    _finnhubEnabled = enabled;
    debugPrint('QuoteService: Finnhub ${enabled ? "enabled" : "disabled"}');
  }
}

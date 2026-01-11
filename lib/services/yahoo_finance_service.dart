/// Yahoo Finance 備援報價服務
/// 
/// 提供美股、期貨報價查詢功能（作為 Finnhub 的備援來源）
/// 使用 Yahoo Finance 非官方 API
/// 
/// 特點：
/// - 免費使用
/// - 支援期貨報價 (ES=F, NQ=F, YM=F 等)
/// - 延遲約 15-20 分鐘
/// 
/// 使用方式：
/// ```dart
/// final service = YahooFinanceService();
/// final quote = await service.getQuote('AAPL');
/// final futuresQuote = await service.getFuturesQuote('ES');
/// ```
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'finnhub_service.dart'; // 共用 StockQuote 等資料類別

/// Yahoo Finance API 服務（備援報價來源）
/// 
/// 使用 Yahoo Finance v8 API
/// 注意：這是非官方 API，可能會變更
class YahooFinanceService {
  // Yahoo Finance API 基礎 URL
  static const String _baseUrlV8 = 'https://query1.finance.yahoo.com/v8/finance';
  static const String _baseUrlV7 = 'https://query1.finance.yahoo.com/v7/finance';
  
  /// 期貨代碼對照表（Yahoo Finance 格式）
  static const Map<String, String> _futuresSymbolMapping = {
    // 美國指數期貨
    'ES': 'ES=F',      // S&P 500 E-mini
    'NQ': 'NQ=F',      // Nasdaq 100 E-mini
    'YM': 'YM=F',      // Dow Jones E-mini
    'RTY': 'RTY=F',    // Russell 2000 E-mini
    'MES': 'MES=F',    // Micro E-mini S&P 500
    'MNQ': 'MNQ=F',    // Micro E-mini Nasdaq 100
    'MYM': 'MYM=F',    // Micro E-mini Dow Jones
    // 商品期貨
    'CL': 'CL=F',      // 原油期貨
    'GC': 'GC=F',      // 黃金期貨
    'SI': 'SI=F',      // 白銀期貨
    'NG': 'NG=F',      // 天然氣期貨
    'HG': 'HG=F',      // 銅期貨
    // VIX
    'VIX': '^VIX',     // VIX 波動率指數
    'VX': 'VX=F',      // VIX 期貨
  };

  /// 主要指數代碼
  static const Map<String, String> _indexSymbolMapping = {
    'SPX': '^GSPC',    // S&P 500 指數
    'NDX': '^NDX',     // Nasdaq 100 指數
    'DJI': '^DJI',     // 道瓊工業指數
    'RUT': '^RUT',     // Russell 2000 指數
    'IXIC': '^IXIC',   // Nasdaq Composite
  };

  /// 取得股票即時報價
  /// 
  /// 支援股票代碼：AAPL, MSFT, GOOGL 等
  /// 支援期貨代碼：ES=F, NQ=F, YM=F 等
  Future<StockQuote?> getQuote(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrlV8/chart/$symbol?interval=1d&range=1d'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseChartResponse(data, symbol);
      } else {
        debugPrint('YahooFinanceService: HTTP ${response.statusCode} for $symbol');
        return null;
      }
    } catch (e) {
      debugPrint('YahooFinanceService getQuote error: $e');
      return null;
    }
  }

  /// 取得期貨報價
  /// 
  /// 輸入簡化代碼：ES, NQ, YM 等
  /// 自動轉換為 Yahoo Finance 格式：ES=F, NQ=F, YM=F
  Future<StockQuote?> getFuturesQuote(String symbol) async {
    final yahooSymbol = _futuresSymbolMapping[symbol.toUpperCase()];
    if (yahooSymbol == null) {
      debugPrint('YahooFinanceService: Unknown futures symbol: $symbol');
      // 嘗試直接使用期貨格式
      final directSymbol = '${symbol.toUpperCase()}=F';
      return await getQuote(directSymbol);
    }
    return await getQuote(yahooSymbol);
  }

  /// 取得指數報價
  /// 
  /// 輸入簡化代碼：SPX, NDX, DJI 等
  Future<StockQuote?> getIndexQuote(String symbol) async {
    final yahooSymbol = _indexSymbolMapping[symbol.toUpperCase()];
    if (yahooSymbol == null) {
      debugPrint('YahooFinanceService: Unknown index symbol: $symbol');
      return null;
    }
    return await getQuote(yahooSymbol);
  }

  /// 批次取得多個股票報價
  Future<Map<String, StockQuote>> getMultipleQuotes(List<String> symbols) async {
    final results = <String, StockQuote>{};
    
    // Yahoo Finance 支援批次查詢
    try {
      final symbolsString = symbols.join(',');
      final response = await http.get(
        Uri.parse('$_baseUrlV7/quote?symbols=$symbolsString'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final quoteResults = data['quoteResponse']?['result'] as List? ?? [];
        
        for (final quote in quoteResults) {
          final stockQuote = _parseQuoteResponse(quote);
          if (stockQuote != null) {
            results[stockQuote.symbol] = stockQuote;
          }
        }
      }
    } catch (e) {
      debugPrint('YahooFinanceService getMultipleQuotes error: $e');
      // 發生錯誤時逐一查詢
      for (final symbol in symbols) {
        final quote = await getQuote(symbol);
        if (quote != null) {
          results[symbol] = quote;
        }
      }
    }
    
    return results;
  }

  /// 取得主要指數期貨報價
  /// 
  /// 回傳 ES, NQ, YM, RTY 的即時報價
  Future<Map<String, StockQuote>> getMajorIndexFutures() async {
    return await getMultipleQuotes(['ES=F', 'NQ=F', 'YM=F', 'RTY=F']);
  }

  /// 解析 Chart API 回應
  StockQuote? _parseChartResponse(Map<String, dynamic> data, String originalSymbol) {
    try {
      final result = data['chart']?['result']?[0];
      if (result == null) return null;

      final meta = result['meta'];
      if (meta == null) return null;

      final regularMarketPrice = (meta['regularMarketPrice'] ?? 0).toDouble();
      final previousClose = (meta['chartPreviousClose'] ?? meta['previousClose'] ?? 0).toDouble();
      final change = regularMarketPrice - previousClose;
      final changePercent = previousClose > 0 ? (change / previousClose * 100) : 0.0;

      // 取得當日高低價
      final indicators = result['indicators']?['quote']?[0];
      double high = regularMarketPrice;
      double low = regularMarketPrice;
      double open = previousClose;

      if (indicators != null) {
        final highs = indicators['high'] as List?;
        final lows = indicators['low'] as List?;
        final opens = indicators['open'] as List?;

        if (highs != null && highs.isNotEmpty) {
          high = highs.whereType<num>().fold<double>(0, (max, v) => v > max ? v.toDouble() : max);
        }
        if (lows != null && lows.isNotEmpty) {
          low = lows.whereType<num>().fold<double>(double.infinity, (min, v) => v < min ? v.toDouble() : min);
          if (low == double.infinity) low = regularMarketPrice;
        }
        if (opens != null && opens.isNotEmpty) {
          final firstOpen = opens.firstWhere((v) => v != null, orElse: () => null);
          if (firstOpen != null) open = (firstOpen as num).toDouble();
        }
      }

      return StockQuote(
        symbol: meta['symbol'] ?? originalSymbol,
        currentPrice: regularMarketPrice,
        change: change,
        changePercent: changePercent,
        high: high,
        low: low,
        open: open,
        previousClose: previousClose,
        timestamp: (meta['regularMarketTime'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000),
      );
    } catch (e) {
      debugPrint('YahooFinanceService _parseChartResponse error: $e');
      return null;
    }
  }

  /// 解析 Quote API 回應
  StockQuote? _parseQuoteResponse(Map<String, dynamic> quote) {
    try {
      final symbol = quote['symbol'] ?? '';
      if (symbol.isEmpty) return null;

      final regularMarketPrice = (quote['regularMarketPrice'] ?? 0).toDouble();
      final regularMarketChange = (quote['regularMarketChange'] ?? 0).toDouble();
      final regularMarketChangePercent = (quote['regularMarketChangePercent'] ?? 0).toDouble();

      return StockQuote(
        symbol: symbol,
        currentPrice: regularMarketPrice,
        change: regularMarketChange,
        changePercent: regularMarketChangePercent,
        high: (quote['regularMarketDayHigh'] ?? regularMarketPrice).toDouble(),
        low: (quote['regularMarketDayLow'] ?? regularMarketPrice).toDouble(),
        open: (quote['regularMarketOpen'] ?? regularMarketPrice).toDouble(),
        previousClose: (quote['regularMarketPreviousClose'] ?? 0).toDouble(),
        timestamp: (quote['regularMarketTime'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000),
      );
    } catch (e) {
      debugPrint('YahooFinanceService _parseQuoteResponse error: $e');
      return null;
    }
  }
}

/// 主要期貨代碼列表（便於外部使用）
class MajorFutures {
  /// 美國指數期貨
  static const List<String> usIndexFutures = [
    'ES',   // S&P 500 E-mini
    'NQ',   // Nasdaq 100 E-mini
    'YM',   // Dow Jones E-mini
    'RTY',  // Russell 2000 E-mini
  ];

  /// 微型期貨
  static const List<String> microFutures = [
    'MES',  // Micro E-mini S&P 500
    'MNQ',  // Micro E-mini Nasdaq 100
    'MYM',  // Micro E-mini Dow Jones
  ];

  /// 商品期貨
  static const List<String> commodityFutures = [
    'CL',   // 原油
    'GC',   // 黃金
    'SI',   // 白銀
    'NG',   // 天然氣
  ];

  /// 取得期貨名稱
  static String getName(String symbol) {
    return _futuresNames[symbol.toUpperCase()] ?? symbol;
  }

  static const Map<String, String> _futuresNames = {
    'ES': 'S&P 500 E-mini',
    'NQ': 'Nasdaq 100 E-mini',
    'YM': 'Dow Jones E-mini',
    'RTY': 'Russell 2000 E-mini',
    'MES': 'Micro E-mini S&P 500',
    'MNQ': 'Micro E-mini Nasdaq 100',
    'MYM': 'Micro E-mini Dow Jones',
    'CL': '原油期貨',
    'GC': '黃金期貨',
    'SI': '白銀期貨',
    'NG': '天然氣期貨',
    'VIX': 'VIX 波動率指數',
  };
}

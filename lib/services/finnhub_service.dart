/// Finnhub 股票查詢服務
/// 
/// 提供美股、期貨報價查詢功能
/// 參考來源：https://github.com/Open-Dev-Society/OpenStock
/// 
/// 使用方式：
/// ```dart
/// final service = FinnhubService();
/// final quote = await service.getQuote('AAPL');
/// final profile = await service.getCompanyProfile('AAPL');
/// final news = await service.getNews('AAPL');
/// ```
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Finnhub API 服務
/// 
/// 免費版限制：
/// - 60 次/分鐘 API 呼叫
/// - 即時報價（美股盤中）
/// - 延遲 15 分鐘（盤後）
class FinnhubService {
  static const String _baseUrl = 'https://finnhub.io/api/v1';
  
  // TODO: 替換為您的 Finnhub API Key
  // 免費申請：https://finnhub.io/register
  static String? _apiKey;
  
  /// 設定 API Key
  static void setApiKey(String key) {
    _apiKey = key;
  }

  /// 取得 API Key
  static String get apiKey {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Finnhub API key not set. Call FinnhubService.setApiKey() first.');
    }
    return _apiKey!;
  }

  /// 通用 HTTP GET 請求
  Future<Map<String, dynamic>> _get(String endpoint, [Map<String, String>? params]) async {
    final queryParams = {
      'token': apiKey,
      ...?params,
    };
    
    final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded (60/min)');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('FinnhubService error: $e');
      rethrow;
    }
  }

  /// 取得股票即時報價
  /// 
  /// 回傳：
  /// - c: 目前價格 (current price)
  /// - d: 漲跌金額 (change)
  /// - dp: 漲跌幅 % (percent change)
  /// - h: 最高價 (high)
  /// - l: 最低價 (low)
  /// - o: 開盤價 (open)
  /// - pc: 前收盤價 (previous close)
  /// - t: 時間戳記 (timestamp)
  Future<StockQuote> getQuote(String symbol) async {
    final data = await _get('/quote', {'symbol': symbol.toUpperCase()});
    return StockQuote.fromJson(data, symbol);
  }

  /// 搜尋股票
  Future<List<StockSearchResult>> searchStocks(String query) async {
    if (query.isEmpty) return [];
    
    final data = await _get('/search', {'q': query});
    final results = data['result'] as List? ?? [];
    
    return results
        .map((r) => StockSearchResult.fromJson(r))
        .where((r) => r.type == 'Common Stock' || r.type == 'ADR')
        .take(15)
        .toList();
  }

  /// 取得公司資料
  Future<CompanyProfile?> getCompanyProfile(String symbol) async {
    try {
      final data = await _get('/stock/profile2', {'symbol': symbol.toUpperCase()});
      if (data.isEmpty) return null;
      return CompanyProfile.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// 取得市場新聞
  /// 
  /// [category]: general, forex, crypto, merger
  Future<List<MarketNews>> getMarketNews({String category = 'general'}) async {
    final uri = Uri.parse('$_baseUrl/news').replace(queryParameters: {
      'token': apiKey,
      'category': category,
    });
    
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.take(10).map((n) => MarketNews.fromJson(n)).toList();
      }
    } catch (e) {
      debugPrint('getMarketNews error: $e');
    }
    return [];
  }

  /// 取得公司新聞
  Future<List<MarketNews>> getCompanyNews(String symbol, {int days = 7}) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    
    final uri = Uri.parse('$_baseUrl/company-news').replace(queryParameters: {
      'token': apiKey,
      'symbol': symbol.toUpperCase(),
      'from': _formatDate(from),
      'to': _formatDate(now),
    });
    
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.take(10).map((n) => MarketNews.fromJson(n)).toList();
      }
    } catch (e) {
      debugPrint('getCompanyNews error: $e');
    }
    return [];
  }

  /// 取得美股期貨報價（ES, NQ, YM 等）
  /// 
  /// 主要期貨代碼：
  /// - ES: S&P 500 E-mini
  /// - NQ: Nasdaq 100 E-mini
  /// - YM: Dow Jones E-mini
  /// - RTY: Russell 2000 E-mini
  /// - CL: 原油期貨
  /// - GC: 黃金期貨
  Future<StockQuote?> getFuturesQuote(String symbol) async {
    // Finnhub 期貨需要特殊格式
    // 例如：ES -> OANDA:SPX500USD
    final mapping = _futuresSymbolMapping[symbol.toUpperCase()];
    if (mapping == null) {
      debugPrint('Unknown futures symbol: $symbol');
      return null;
    }
    
    try {
      return await getQuote(mapping);
    } catch (e) {
      debugPrint('Error fetching futures $symbol: $e');
      return null;
    }
  }

  /// 期貨代碼對照表
  static const Map<String, String> _futuresSymbolMapping = {
    // 美國指數期貨
    'ES': 'SPY',      // S&P 500 (用 ETF 替代)
    'NQ': 'QQQ',      // Nasdaq 100 (用 ETF 替代)
    'YM': 'DIA',      // Dow Jones (用 ETF 替代)
    'RTY': 'IWM',     // Russell 2000 (用 ETF 替代)
    // 商品期貨
    'CL': 'USO',      // 原油 (用 ETF 替代)
    'GC': 'GLD',      // 黃金 (用 ETF 替代)
    'SI': 'SLV',      // 白銀 (用 ETF 替代)
  };

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 股票報價資料
class StockQuote {
  final String symbol;
  final double currentPrice;
  final double change;
  final double changePercent;
  final double high;
  final double low;
  final double open;
  final double previousClose;
  final int timestamp;

  StockQuote({
    required this.symbol,
    required this.currentPrice,
    required this.change,
    required this.changePercent,
    required this.high,
    required this.low,
    required this.open,
    required this.previousClose,
    required this.timestamp,
  });

  factory StockQuote.fromJson(Map<String, dynamic> json, String symbol) {
    return StockQuote(
      symbol: symbol.toUpperCase(),
      currentPrice: (json['c'] ?? 0).toDouble(),
      change: (json['d'] ?? 0).toDouble(),
      changePercent: (json['dp'] ?? 0).toDouble(),
      high: (json['h'] ?? 0).toDouble(),
      low: (json['l'] ?? 0).toDouble(),
      open: (json['o'] ?? 0).toDouble(),
      previousClose: (json['pc'] ?? 0).toDouble(),
      timestamp: json['t'] ?? 0,
    );
  }

  /// 是否上漲
  bool get isUp => change >= 0;

  /// 格式化價格
  String get priceFormatted => '\$${currentPrice.toStringAsFixed(2)}';

  /// 格式化漲跌
  String get changeFormatted => '${isUp ? '+' : ''}${change.toStringAsFixed(2)} (${changePercent.toStringAsFixed(2)}%)';

  @override
  String toString() => '$symbol: $priceFormatted $changeFormatted';
}

/// 股票搜尋結果
class StockSearchResult {
  final String symbol;
  final String description;
  final String displaySymbol;
  final String type;

  StockSearchResult({
    required this.symbol,
    required this.description,
    required this.displaySymbol,
    required this.type,
  });

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      symbol: json['symbol'] ?? '',
      description: json['description'] ?? '',
      displaySymbol: json['displaySymbol'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

/// 公司資料
class CompanyProfile {
  final String name;
  final String ticker;
  final String exchange;
  final String industry;
  final String logo;
  final String weburl;
  final double marketCapitalization;
  final String country;
  final String currency;

  CompanyProfile({
    required this.name,
    required this.ticker,
    required this.exchange,
    required this.industry,
    required this.logo,
    required this.weburl,
    required this.marketCapitalization,
    required this.country,
    required this.currency,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      name: json['name'] ?? '',
      ticker: json['ticker'] ?? '',
      exchange: json['exchange'] ?? '',
      industry: json['finnhubIndustry'] ?? '',
      logo: json['logo'] ?? '',
      weburl: json['weburl'] ?? '',
      marketCapitalization: (json['marketCapitalization'] ?? 0).toDouble(),
      country: json['country'] ?? '',
      currency: json['currency'] ?? '',
    );
  }

  /// 格式化市值
  String get marketCapFormatted {
    if (marketCapitalization >= 1000000) {
      return '\$${(marketCapitalization / 1000000).toStringAsFixed(2)}T';
    } else if (marketCapitalization >= 1000) {
      return '\$${(marketCapitalization / 1000).toStringAsFixed(2)}B';
    } else {
      return '\$${marketCapitalization.toStringAsFixed(2)}M';
    }
  }
}

/// 市場新聞
class MarketNews {
  final int id;
  final String headline;
  final String summary;
  final String source;
  final String url;
  final String image;
  final int datetime;
  final String category;

  MarketNews({
    required this.id,
    required this.headline,
    required this.summary,
    required this.source,
    required this.url,
    required this.image,
    required this.datetime,
    required this.category,
  });

  factory MarketNews.fromJson(Map<String, dynamic> json) {
    return MarketNews(
      id: json['id'] ?? 0,
      headline: json['headline'] ?? '',
      summary: json['summary'] ?? '',
      source: json['source'] ?? '',
      url: json['url'] ?? '',
      image: json['image'] ?? '',
      datetime: json['datetime'] ?? 0,
      category: json['category'] ?? '',
    );
  }

  /// 格式化時間
  String get timeFormatted {
    final date = DateTime.fromMillisecondsSinceEpoch(datetime * 1000);
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// 熱門美股代碼
class PopularStocks {
  static const List<String> techGiants = [
    'AAPL',  // Apple
    'MSFT',  // Microsoft
    'GOOGL', // Alphabet
    'AMZN',  // Amazon
    'TSLA',  // Tesla
    'META',  // Meta
    'NVDA',  // NVIDIA
    'NFLX',  // Netflix
  ];

  static const List<String> indices = [
    'SPY',   // S&P 500 ETF
    'QQQ',   // Nasdaq 100 ETF
    'DIA',   // Dow Jones ETF
    'IWM',   // Russell 2000 ETF
  ];

  static const List<String> commodities = [
    'GLD',   // 黃金 ETF
    'SLV',   // 白銀 ETF
    'USO',   // 原油 ETF
  ];

  static const List<String> all = [
    ...techGiants,
    ...indices,
    ...commodities,
  ];
}

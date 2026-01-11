/// 美股報價查詢頁面
/// 
/// 功能：
/// - 搜尋美股代號
/// - 查看即時報價
/// - 瀏覽市場新聞
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/finnhub_service.dart';
import '../widgets/us_stock_widgets.dart';

class UsStockScreen extends StatefulWidget {
  const UsStockScreen({super.key});

  @override
  State<UsStockScreen> createState() => _UsStockScreenState();
}

class _UsStockScreenState extends State<UsStockScreen> {
  final FinnhubService _service = FinnhubService();
  
  StockQuote? _quote;
  CompanyProfile? _profile;
  List<MarketNews> _news = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 預設載入 SPY (S&P 500 ETF)
    _fetchQuote('SPY');
  }

  Future<void> _fetchQuote(String symbol) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quote = await _service.getQuote(symbol);
      final profile = await _service.getCompanyProfile(symbol);
      final news = await _service.getCompanyNews(symbol, days: 3);

      setState(() {
        _quote = quote;
        _profile = profile;
        _news = news;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('美股報價'),
        actions: [
          if (_quote != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetchQuote(_quote!.symbol),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜尋框
            StockSearchBar(
              service: _service,
              onSelect: _fetchQuote,
            ),
            
            const SizedBox(height: 16),
            
            // 錯誤訊息
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // 載入中
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),

            // 報價卡片
            if (_quote != null && !_isLoading) ...[
              StockQuoteCard(quote: _quote!),
              
              // 公司資訊
              if (_profile != null) ...[
                const SizedBox(height: 16),
                _buildProfileSection(_profile!),
              ],
              
              // 新聞列表
              if (_news.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  '相關新聞',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._news.map((news) => NewsCard(
                  news: news,
                  onTap: () => _openUrl(news.url),
                )),
              ],
            ],

            // 熱門股票
            if (_quote == null && !_isLoading) ...[
              const SizedBox(height: 24),
              PopularStocksList(
                onSelect: _fetchQuote,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(CompanyProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (profile.logo.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      profile.logo,
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.business,
                        size: 48,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${profile.exchange} · ${profile.industry}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('市值', profile.marketCapFormatted),
            _buildInfoRow('國家', profile.country),
            _buildInfoRow('貨幣', profile.currency),
            if (profile.weburl.isNotEmpty)
              InkWell(
                onTap: () => _openUrl(profile.weburl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('官方網站'),
                      Row(
                        children: [
                          Text(
                            '前往',
                            style: TextStyle(color: Colors.blue[600]),
                          ),
                          Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: Colors.blue[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

# Finnhub 美股報價服務使用指南

## 簡介

這是一個基於 [Finnhub API](https://finnhub.io/) 的美股報價查詢服務，參考 [OpenStock](https://github.com/Open-Dev-Society/OpenStock) 專案架構設計。

## 功能特色

- ✅ 即時股票報價 (美股盤中即時、盤後延遲 15 分鐘)
- ✅ 股票搜尋 (代號、公司名稱)
- ✅ 公司資料 (名稱、產業、市值、Logo)
- ✅ 市場新聞 / 個股新聞
- ✅ ETF 報價 (SPY, QQQ, DIA 等)

## 使用前準備

### 1. 申請免費 API Key

1. 前往 [Finnhub 註冊頁面](https://finnhub.io/register)
2. 免費註冊帳號
3. 取得 API Key

### 2. 設定 API Key

在 App 啟動時設定：

```dart
import 'package:txf_leverage_app/services/finnhub_service.dart';

void main() {
  // 設定 API Key
  FinnhubService.setApiKey('YOUR_API_KEY_HERE');
  
  runApp(MyApp());
}
```

建議使用環境變數儲存 API Key：

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();
  FinnhubService.setApiKey(dotenv.env['FINNHUB_API_KEY'] ?? '');
  runApp(MyApp());
}
```

## 基本用法

### 查詢股票報價

```dart
final service = FinnhubService();

// 取得 Apple 股票報價
final quote = await service.getQuote('AAPL');

print('股票: ${quote.symbol}');
print('價格: ${quote.priceFormatted}');  // $189.50
print('漲跌: ${quote.changeFormatted}');  // +2.35 (1.26%)
print('是否上漲: ${quote.isUp}');  // true
```

### 搜尋股票

```dart
final results = await service.searchStocks('Apple');

for (final stock in results) {
  print('${stock.symbol} - ${stock.description}');
}
// AAPL - APPLE INC
// APLE - Apple Hospitality REIT Inc
```

### 取得公司資料

```dart
final profile = await service.getCompanyProfile('TSLA');

if (profile != null) {
  print('公司: ${profile.name}');  // Tesla Inc
  print('產業: ${profile.industry}');  // Automobiles
  print('市值: ${profile.marketCapFormatted}');  // $789.12B
  print('國家: ${profile.country}');  // US
}
```

### 取得新聞

```dart
// 市場新聞
final marketNews = await service.getMarketNews();

// 個股新聞 (最近 7 天)
final companyNews = await service.getCompanyNews('NVDA', days: 7);

for (final news in companyNews) {
  print('${news.headline}');
  print('來源: ${news.source} - ${news.timeFormatted}');
}
```

### 期貨報價 (使用對應 ETF)

由於 Finnhub 免費版不支援期貨，我們使用對應的 ETF 替代：

```dart
// ES (S&P 500 期貨) -> 使用 SPY ETF
final es = await service.getFuturesQuote('ES');

// NQ (Nasdaq 100 期貨) -> 使用 QQQ ETF
final nq = await service.getFuturesQuote('NQ');

// CL (原油期貨) -> 使用 USO ETF
final cl = await service.getFuturesQuote('CL');
```

| 期貨代碼 | 名稱 | 替代 ETF |
|---------|------|----------|
| ES | S&P 500 E-mini | SPY |
| NQ | Nasdaq 100 E-mini | QQQ |
| YM | Dow Jones E-mini | DIA |
| RTY | Russell 2000 E-mini | IWM |
| CL | 原油 | USO |
| GC | 黃金 | GLD |
| SI | 白銀 | SLV |

## 使用 Widget

### 報價卡片

```dart
if (quote != null) {
  StockQuoteCard(
    quote: quote,
    onTap: () {
      // 點擊處理
    },
  )
}
```

### 搜尋框

```dart
StockSearchBar(
  onSelect: (symbol) {
    // 用戶選擇股票
    print('Selected: $symbol');
    fetchQuote(symbol);
  },
)
```

### 熱門股票列表

```dart
PopularStocksList(
  onSelect: (symbol) {
    fetchQuote(symbol);
  },
)
```

## 導航到美股頁面

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const UsStockScreen(),
  ),
);
```

## API 限制

| 方案 | 呼叫次數 | 即時報價 | 價格 |
|-----|---------|---------|------|
| 免費 | 60 次/分鐘 | 是 (盤後延遲 15 分鐘) | $0 |
| 付費 | 300 次/分鐘 | 是 | $49.99/月起 |

## 錯誤處理

```dart
try {
  final quote = await service.getQuote('AAPL');
  // 成功
} catch (e) {
  if (e.toString().contains('Invalid API key')) {
    // API Key 無效
  } else if (e.toString().contains('Rate limit')) {
    // 超過呼叫次數限制，等待後重試
  } else {
    // 其他錯誤
  }
}
```

## 檔案結構

```
lib/
├── services/
│   └── finnhub_service.dart    # Finnhub API 服務
├── widgets/
│   └── us_stock_widgets.dart   # 美股相關 Widget
└── screens/
    └── us_stock_screen.dart    # 美股報價頁面
```

## 參考資源

- [Finnhub API 文件](https://finnhub.io/docs/api)
- [OpenStock 原始碼](https://github.com/Open-Dev-Society/OpenStock)

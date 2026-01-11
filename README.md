# 台指期槓桿計算器 App

## � 核心理念

**直接操作期貨，省下 ETF 管理費！**

- ETF 每年收取 0.03%~1% 管理費，長期累積可觀
- 期貨無管理費，只有交易手續費和稅金
- 本 App 幫助計算期貨槓桿，讓散戶安全操作期貨替代 ETF

### 為何不用 ETF？

| 項目 | ETF (如 0050) | 台指期 |
|------|--------------|--------|
| 管理費 | 0.32%/年 | 0 |
| 交易成本 | 手續費+證交稅 | 手續費+期交稅(更低) |
| 槓桿 | 無 | 可調整 |
| 到期 | 無 | 每月結算 |

---

## �🚀 快速開始

### 步驟 1：安裝 Flutter

**以系統管理員身分**開啟 PowerShell，執行：

```powershell
# 方法一：執行安裝腳本
cd "d:\Dropbox\ko1\自寫程式\TXF_Leverage"
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install_flutter.ps1
```

**或手動安裝：**
1. 下載 Flutter：https://docs.flutter.dev/get-started/install/windows/mobile
2. 解壓縮到 `C:\flutter`
3. 將 `C:\flutter\bin` 加入系統 PATH 環境變數
4. 重新開啟 VS Code

### 步驟 2：安裝 Android Studio

1. 下載：https://developer.android.com/studio
2. 安裝時選擇 Standard
3. 完成後開啟，讓它下載 Android SDK

### 步驟 3：驗證安裝

```powershell
flutter doctor
```

### 步驟 4：初始化專案

```powershell
cd "d:\Dropbox\ko1\自寫程式\TXF_Leverage\txf_leverage_app"
flutter create . --platforms=android
flutter pub get
```

### 步驟 5：執行 App

```powershell
# 列出裝置
flutter devices

# 執行（連接手機或啟動模擬器後）
flutter run
```

---

## 📱 編譯 APK

```powershell
# Debug 版本（測試用）
flutter build apk --debug

# Release 版本（上架用）
flutter build apk --release

# 輸出位置：build\app\outputs\flutter-apk\app-release.apk
```

---

## 📝 上架前清單

- [ ] 替換 AdMob App ID（AndroidManifest.xml）
- [ ] 替換廣告單元 ID（ad_banner.dart）
- [ ] 修改 applicationId（build.gradle）
- [ ] 建立正式簽名金鑰
- [ ] 準備 App 圖示和截圖
- [ ] 撰寫 App 說明

---

## 📊 報價服務架構

本專案整合多個報價來源，提供自動備援機制：

### 報價來源

| 來源 | 用途 | 免費限制 | 期貨支援 |
|------|------|----------|----------|
| **Finnhub** (主) | 美股即時報價 | 60次/分鐘 | ❌ 僅 ETF |
| **Yahoo Finance** (備援) | 美股/期貨延遲報價 | 無限制 | ✅ 完整支援 |
| **台灣期貨交易所** | 台指期報價 | 免費即時 | ✅ 台灣期貨 |

### 使用方式

```dart
import 'package:txf_leverage_app/services/services.dart';

// 初始化
final quoteService = QuoteService();
await quoteService.initialize();

// 取得股票報價（自動備援）
final result = await quoteService.getQuote('AAPL');
if (result.isSuccess) {
  print('${result.quote!.symbol}: \$${result.quote!.currentPrice}');
  print('來源: ${result.source.name}');
}

// 取得期貨報價（使用 Yahoo Finance）
final futuresResult = await quoteService.getFuturesQuote('ES');
if (futuresResult.isSuccess) {
  print('ES 期貨: \$${futuresResult.quote!.currentPrice}');
}

// 批次取得主要指數期貨
final majorFutures = await quoteService.getMajorIndexFutures();
majorFutures.forEach((symbol, result) {
  if (result.isSuccess) {
    print('$symbol: \$${result.quote!.currentPrice}');
  }
});
```

### 支援的期貨代碼

- **美國指數期貨**: ES (S&P 500), NQ (Nasdaq 100), YM (Dow Jones), RTY (Russell 2000)
- **微型期貨**: MES, MNQ, MYM
- **商品期貨**: CL (原油), GC (黃金), SI (白銀), NG (天然氣)

---

## 🔧 環境變數設定

環境變數統一存放於 `D:\Dropbox\FlutterProjects\.env`：

```env
# Finnhub API（可選，有則優先使用）
FINNHUB_API_KEY=your_api_key

# Yahoo Finance 不需要 API Key
```

---

## 📁 專案結構

```
lib/
├── main.dart                 # App 進入點
├── screens/
│   ├── calculator_screen.dart  # 槓桿計算器畫面
│   └── us_stock_screen.dart    # 美股查詢畫面
├── services/
│   ├── services.dart           # 服務匯出
│   ├── env_service.dart        # 環境變數服務
│   ├── quote_service.dart      # 統一報價服務（含備援機制）
│   ├── finnhub_service.dart    # Finnhub API 服務
│   ├── yahoo_finance_service.dart  # Yahoo Finance 服務
│   └── subscription_service.dart   # 訂閱服務
└── widgets/
    ├── ad_banner.dart          # 廣告元件
    └── us_stock_widgets.dart   # 美股相關元件
```

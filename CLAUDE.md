# CLAUDE.md - 專案說明文件

> 這個檔案是給 Claude Code 的指導文件，整個團隊共同維護。
> 當發現 Claude 做錯某件事，請將指導加入此文件。

## 專案名稱
台指期槓桿計算器 (TXF Leverage Calculator)

## 專案概述
這是一個 Flutter APP，用於計算台灣期貨交易所（TAIFEX）期貨的槓桿倍數和曝險金額。

## 語言設定
- **所有輸出必須使用繁體中文**（台灣用語）
- 程式碼註解使用繁體中文
- 變數名稱和函數名稱使用英文
- Git 提交訊息使用繁體中文

## 技術棧
- Flutter 3.27.2
- Dart
- Google Mobile Ads (AdMob)
- SharedPreferences

## 目錄結構
```
lib/
├── main.dart                   # APP 入口
├── models/
│   └── calculation_record.dart # 資料模型
├── screens/
│   ├── calculator_screen.dart  # 主計算頁面
│   ├── settings_screen.dart    # 設定頁面
│   └── history_screen.dart     # 歷史紀錄頁面
└── widgets/
    └── ad_banner.dart          # 廣告元件

.claude/
├── commands/                   # 斜線指令
│   ├── build.md               # /build - 建置專案
│   ├── verify.md              # /verify - 驗證工作
│   ├── simplify.md            # /simplify - 簡化程式碼
│   ├── implement.md           # /implement - 實作功能
│   ├── review.md              # /review - 程式碼審查
│   ├── status.md              # /status - 狀態報告
│   ├── plan.md                # /plan - 計畫功能
│   └── commit.md              # /commit - Git 提交
├── hooks/                      # 自動化鉤子
│   ├── post-tool-use.ps1      # 寫入後自動格式化
│   └── stop-hook.sh           # 完成後自動驗證
├── tasks/
│   ├── development-loop.md    # 開發循環流程
│   └── product_backlog.md     # 產品待辦清單
├── settings.json              # 專案設定
├── settings.local.json        # 本地設定（含權限）
└── system-prompt.md           # 系統提示詞
```

## 開發工作流程

### 推薦流程（來自 Boris 的建議）
1. **先計畫**：使用 `/plan` 或計畫模式（shift+tab 兩次）討論實作方案
2. **實作**：確認計畫後，切換到自動接受編輯模式
3. **驗證**：使用 `/verify` 或讓 Claude 執行 `flutter analyze`
4. **簡化**：使用 `/simplify` 審查並優化程式碼
5. **提交**：使用 `/commit` 提交變更

### 重要原則
- **讓 Claude 驗證工作**：這是獲得好結果最重要的事
- **使用斜線指令**：避免重複輸入常用提示
- **保持 CLAUDE.md 更新**：發現問題就加入指導

## 開發指令

### 編譯 Debug 版
```bash
flutter build apk --debug
```

### 編譯 Release 版
```bash
flutter build apk --release
```

### 編譯後複製 APK
```bash
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" -Destination "D:\FlutterProjects\txf_leverage_app.apk" -Force
```

### 執行分析
```bash
flutter analyze
```

## 自動化任務

任務定義文件位於 `.claude/tasks/`:
- `development-loop.md` - 開發循環流程定義
- `product_backlog.md` - 產品待辦清單

### 啟動自動化循環
```
/loop 10 .claude/tasks/development-loop.md
```

## 程式碼規範
- 使用繁體中文註解
- 遵循 Flutter/Dart 官方風格
- 每個 Widget 保持單一職責
- 命名使用 camelCase

## 重要檔案
- `AndroidManifest.xml` - APP 名稱、權限設定
- `pubspec.yaml` - 依賴套件
- `.claude/tasks/product_backlog.md` - 功能待辦清單

## 注意事項
- 期交所 API 有 CORS 限制，網頁版無法直接呼叫
- AdMob 測試時使用測試 ID，上架前需替換正式 ID
- APP 名稱：「台指槓桿」
- 圖示：紅色圓圈 + TXFL 暗綠色文字

## 常見錯誤與解決方案

### ❌ 不要這樣做

1. **不要忘記執行 `flutter analyze`**
   - 每次修改程式碼後都要驗證

2. **不要硬編碼 API Key**
   - AdMob ID 應該從設定檔讀取
   - 敏感資訊不要提交到 git

3. **不要在 async 函數中直接使用 BuildContext**
   - 使用 `mounted` 檢查或在 async 前保存引用

4. **不要忽略 linter 警告**
   - 所有 warning 都應該修復

### ✅ 要這樣做

1. **每次修改後執行驗證**
   ```bash
   flutter analyze
   ```

2. **使用 const 提升效能**
   ```dart
   const Text('固定文字')  // ✅
   Text('固定文字')       // ❌
   ```

3. **正確處理 nullable**
   ```dart
   final value = data?.value ?? defaultValue;  // ✅
   ```

4. **保持函數簡短**
   - 單一函數不超過 50 行
   - 複雜邏輯拆分成小函數

## 斜線指令快速參考

| 指令 | 說明 |
|------|------|
| `/build` | 建置並複製 APK |
| `/verify` | 驗證程式碼 |
| `/simplify` | 簡化程式碼 |
| `/implement [功能]` | 實作功能 |
| `/review` | 程式碼審查 |
| `/status` | 專案狀態 |
| `/plan [功能]` | 計畫功能 |
| `/commit [訊息]` | Git 提交 |


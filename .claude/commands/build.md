# 建置專案
# 用法: /build [debug|release]

執行 Flutter 專案建置流程：

1. 先執行 `flutter analyze` 檢查程式碼
2. 如果分析通過，執行 `flutter build apk --$ARGUMENTS`（預設 release）
3. 編譯成功後，將 APK 複製到 `D:\Dropbox\FlutterProjects\txf_leverage_app.apk`
4. 報告編譯結果和 APK 大小

所有輸出使用繁體中文。

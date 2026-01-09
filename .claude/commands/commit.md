# Git 提交
# 用法: /commit [提交訊息]

執行 Git 提交流程：

1. 執行 `flutter analyze` 確保沒有錯誤
2. 顯示 `git status` 確認要提交的檔案
3. 執行 `git add .` 加入所有變更
4. 使用繁體中文提交訊息執行 `git commit -m "$ARGUMENTS"`
5. 如果沒有提供訊息，自動生成描述性的提交訊息

## 提交訊息格式
```
[類型] 簡短描述

- 詳細變更 1
- 詳細變更 2
```

類型：
- feat: 新功能
- fix: 修復錯誤
- refactor: 重構
- style: 樣式調整
- docs: 文件更新
- test: 測試相關

所有輸出使用繁體中文。

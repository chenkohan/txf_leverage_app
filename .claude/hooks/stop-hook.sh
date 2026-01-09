#!/bin/bash
# Stop Hook - 工作完成後驗證
# 當 Claude 完成工作時自動執行驗證

echo "=========================================="
echo "🔍 執行工作完成驗證..."
echo "=========================================="

cd "$(dirname "$0")/../.."

# 1. 執行 flutter analyze
echo ""
echo "📋 程式碼分析..."
flutter analyze

if [ $? -ne 0 ]; then
    echo "❌ 程式碼分析發現問題，請修復後再繼續"
    exit 1
fi

echo ""
echo "✅ 驗證完成！"
echo "=========================================="

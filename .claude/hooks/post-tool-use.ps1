# PostToolUse Hook - 自動格式化 Dart 程式碼
# 當 Claude 寫入 .dart 檔案後自動執行格式化

param(
    [string]$ToolName,
    [string]$FilePath
)

# 只處理 Write 工具且是 .dart 檔案
if ($ToolName -eq "Write" -and $FilePath -match "\.dart$") {
    # 檢查檔案是否存在
    if (Test-Path $FilePath) {
        # 執行 dart format
        $result = dart format $FilePath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[Hook] 已格式化: $FilePath" -ForegroundColor Green
        } else {
            Write-Host "[Hook] 格式化失敗: $FilePath" -ForegroundColor Yellow
            Write-Host $result
        }
    }
}

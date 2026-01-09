@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Claude Code Automation Script
REM Usage: claude-dev.bat "Your task description"

if "%~1"=="" (
    echo Usage: claude-dev.bat "task description"
    echo Example: claude-dev.bat "Implement history feature"
    exit /b 1
)

set "TASK=%~1"
set "MODEL=sonnet"
set "SYSTEM_PROMPT=You are a professional Flutter developer assistant. ALL output MUST be in Traditional Chinese (Taiwan). Project: Taiwan Futures Leverage Calculator. Framework: Flutter 3.27.2. Check .claude/tasks/product_backlog.md for backlog. Run flutter analyze after changes."

REM API Key should be set as environment variable, not hardcoded
if not defined ANTHROPIC_API_KEY (
    echo ERROR: ANTHROPIC_API_KEY environment variable is not set.
    echo Please set it first: set ANTHROPIC_API_KEY=your-api-key
    exit /b 1
)

echo ========================================
echo Claude Code Automation
echo ========================================
echo Task: %TASK%
echo Model: %MODEL%
echo ========================================

claude -p "%TASK%" --model %MODEL% --system-prompt "%SYSTEM_PROMPT%"

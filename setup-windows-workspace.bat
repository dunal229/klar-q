@echo off
REM Double-click launcher for setup-windows-workspace.ps1
REM Downloads the latest setup script and runs it end-to-end.
REM The first private clone opens a GitHub login in your browser - sign in and it continues.

echo Starting workspace setup...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://github.com/dunal229/klar-q/raw/claude/github-windows-setup-u13thr/setup-windows-workspace.ps1' | iex"

echo.
echo Setup finished. Review the REPORT above.
pause

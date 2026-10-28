@echo off
setlocal
cd /d "%~dp0"
where vsim >nul 2>nul
if errorlevel 1 (
  echo Add your Questa win64 directory to PATH first.
  exit /b 1
)
vsim -c -do "do run.do"
exit /b %ERRORLEVEL%

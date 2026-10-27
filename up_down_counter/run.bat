@echo off
setlocal
rem Run from Windows Command Prompt. Add Questa's win64 directory to PATH.
rem Usage: run.bat [test_name] [seed] [width] [num_items]
cd /d "%~dp0"
set "TEST=counter_base_test"
set "SEED=1"
set "WIDTH=8"
set "NUM_ITEMS=1000"
if not "%~1"=="" set "TEST=%~1"
if not "%~2"=="" set "SEED=%~2"
if not "%~3"=="" set "WIDTH=%~3"
if not "%~4"=="" set "NUM_ITEMS=%~4"
where vsim >nul 2>nul
if errorlevel 1 (
  echo ERROR: vsim is not on PATH. Add the Questa win64 directory to PATH.
  exit /b 1
)
vsim -c -do "set TEST {%TEST%}; set SEED {%SEED%}; set WIDTH {%WIDTH%}; set NUM_ITEMS {%NUM_ITEMS%}; do run.do"
exit /b %ERRORLEVEL%

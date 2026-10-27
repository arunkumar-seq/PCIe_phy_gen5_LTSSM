@echo off
setlocal
cd /d "%~dp0"
for %%T in (counter_reset_test counter_directed_test counter_wrap_test counter_random_test counter_base_test) do (
  call run.bat %%T 1 8 1000
  if errorlevel 1 exit /b 1
)
echo REGRESSION PASS
exit /b 0

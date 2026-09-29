@echo off
setlocal enabledelayedexpansion
title Virtual Gamepad - PC Launcher
color 0A

echo =========================================
echo   Virtual Gamepad - PC Launcher
echo   Run this EVERY TIME you want to play
echo =========================================
echo.

:: --- Check exe exists beside this bat ---
if not exist "%~dp0VirtualControllerServer.exe" (
  echo [!] VirtualControllerServer.exe not found!
  echo     Put this launcher in SAME folder as VirtualControllerServer.exe
  echo     Folder: %~dp0
  pause
  exit /b 1
)

:: --- Check ViGEmBus driver ---
echo [*] Checking ViGEmBus driver...
sc query vigembus >nul 2>&1
if %errorlevel% neq 0 (
  if exist "C:\Windows\System32\drivers\vigembus.sys" goto vigem_ok
  echo [!] ViGEmBus not found.
  echo [*] Attempting auto-download of ViGEmBus installer...
  echo     URL: https://github.com/nefarius/ViGEmBus/releases/download/v1.22.0/ViGEmBusSetup_x64.msi
  echo.
  :: Try PowerShell download
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri 'https://github.com/nefarius/ViGEmBus/releases/download/v1.22.0/ViGEmBusSetup_x64.msi' -OutFile '%TEMP%\ViGEmBusSetup_x64.msi' -UseBasicParsing; exit 0 } catch { exit 1 }"
  if not exist "%TEMP%\ViGEmBusSetup_x64.msi" (
    echo [!] Auto-download failed. No internet or blocked.
    echo.
    echo     Manual install:
    echo     1. Open: https://github.com/nefarius/ViGEmBus/releases
    echo     2. Download ViGEmBusSetup_x64.msi
    echo     3. Install, then RESTART PC, then run this launcher again.
    echo.
    pause
    exit /b 1
  )
  echo [+] Downloaded to %TEMP%\ViGEmBusSetup_x64.msi
  echo [*] Installing ViGEmBus - UAC prompt will appear, click Yes...
  :: Need admin - msiexec will trigger UAC
  msiexec /i "%TEMP%\ViGEmBusSetup_x64.msi" /passive
  if %errorlevel% neq 0 (
    echo [!] Installer failed or cancelled.
    echo     Try manual install from link above.
    pause
    exit /b 1
  )
  echo [*] Waiting for driver to register...
  timeout /t 5 /nobreak >nul
  sc query vigembus >nul 2>&1
  if %errorlevel% neq 0 (
    if not exist "C:\Windows\System32\drivers\vigembus.sys" (
      echo [!] Install seemed ok but driver not detected.
      echo     Please RESTART PC then run this launcher again.
      pause
      exit /b 0
    )
  )
  echo [+] ViGEmBus installed.
  echo [!] If this was first install, RESTART PC once, then run this launcher again.
  timeout /t 3 >nul
) else (
  :vigem_ok
  echo [+] ViGEmBus found.
)

echo.
:: --- Firewall ---
echo [*] Checking firewall for UDP 8888...
netsh advfirewall firewall show rule name="Virtual Gamepad UDP 8888" >nul 2>&1
if %errorlevel% neq 0 (
  echo [*] Adding firewall rule - may need admin, allow UAC...
  netsh advfirewall firewall add rule name="Virtual Gamepad UDP 8888" dir=in action=allow protocol=UDP localport=8888 >nul 2>&1
  if %errorlevel% equ 0 (
    echo [+] Firewall rule added.
  ) else (
    echo [!] Could not add firewall rule. If controller won't connect, allow UDP 8888 manually.
  )
) else (
  echo [+] Firewall rule already exists.
)

echo.
echo -----------------------------------------
echo  Your PC IP addresses:
echo  Wi-Fi mode: use Wireless LAN adapter Wi-Fi IPv4
echo  USB  mode: use Remote NDIS adapter IPv4
echo -----------------------------------------
ipconfig | findstr /R /C:"adapter" /C:"IPv4"
echo -----------------------------------------
echo.
echo [*] Starting controller server...
echo     Keep this window OPEN while playing.
echo     Close window or Ctrl+C to disconnect.
echo =========================================
echo.

:: --- Run server (foreground, user must keep open) ---
"%~dp0VirtualControllerServer.exe"

echo.
echo [*] Server stopped.
pause
endlocal

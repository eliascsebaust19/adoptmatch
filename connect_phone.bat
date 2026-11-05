@echo off
title AdoptMatch - Wireless Debugging Connector
color 0B
echo =======================================================
echo          AdoptMatch - Wireless Debugging Setup
echo =======================================================
echo.
echo Make sure your Phone and PC are on the same Wi-Fi network!
echo PC Wi-Fi IP: 192.168.1.108
echo.
echo -------------------------------------------------------
echo Step 1: On your phone:
echo    1. Go to Settings -^> Developer Options -^> Wireless debugging
echo    2. Turn ON "Wireless debugging"
echo    3. Tap "Pair device with pairing code"
echo -------------------------------------------------------
echo.
set /p PAIR_IP="Enter Pairing IP & Port (e.g. 192.168.1.xxx:xxxxx) [or press Enter to skip pairing]: "

if "%PAIR_IP%"=="" goto CONNECT_ONLY

set /p PAIR_CODE="Enter 6-digit Wi-Fi pairing code: "
echo.
echo Pairing device...
"E:\Android\platform-tools\adb.exe" pair %PAIR_IP% %PAIR_CODE%
echo.

:CONNECT_ONLY
echo -------------------------------------------------------
echo Step 2: Now enter the main IP & Port shown on your phone
echo (Under "IP address & Port", NOT the pairing port)
echo -------------------------------------------------------
set /p CONNECT_IP="Enter Connect IP & Port (e.g. 192.168.1.xxx:xxxxx): "
echo.
echo Connecting to %CONNECT_IP%...
"E:\Android\platform-tools\adb.exe" connect %CONNECT_IP%
echo.
echo Connected devices:
"E:\Android\platform-tools\adb.exe" devices
echo.
echo =======================================================
echo Now launching Phone Screen Mirroring (scrcpy)...
echo =======================================================
start "" scrcpy --video-codec=h264 -m 1280 --max-fps 60
pause


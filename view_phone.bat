@echo off
title AdoptMatch - Live Phone View Mirroring
color 0A
echo =======================================================
echo          AdoptMatch - Live Phone Screen View
echo =======================================================
echo.
set ADB=E:\Android\platform-tools\adb.exe
"E:\Android\platform-tools\adb.exe" connect 192.168.1.109:43011
echo.
echo Launching Live Phone Screen Mirroring on your Desktop...
"C:\Users\ALPHA TECH\AppData\Local\Microsoft\WinGet\Packages\Genymobile.scrcpy_Microsoft.Winget.Source_8wekyb3d8bbwe\scrcpy-win64-v5.0.1\scrcpy.exe" -s 192.168.1.109:43011 --window-title="AdoptMatch Phone View" --always-on-top --video-codec=h264 -m 1280 --max-fps 60
pause

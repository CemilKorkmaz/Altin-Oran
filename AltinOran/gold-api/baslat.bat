@echo off
title Gold API - Altin Fiyati Sunucusu
cd /d "%~dp0"
set "NODE=C:\Program Files\nodejs\node.exe"
set "NPM=C:\Program Files\nodejs\npm.cmd"
if not exist "%NODE%" (
  echo Node.js bulunamadi. Lutfen https://nodejs.org adresinden kurun.
  pause
  exit /b 1
)
echo Bagimliliklari kontrol ediyorum...
if not exist "node_modules" "%NPM%" install
echo.
echo Sunucu baslatiliyor: http://localhost:3030
echo Kapatmak icin bu pencereyi kapatin.
echo.
"%NODE%" server.js
pause

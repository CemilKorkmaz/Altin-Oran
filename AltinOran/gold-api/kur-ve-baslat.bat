@echo off
chcp 65001 >nul
title Gold API - Kurulum ve Baslat
cd /d "%~dp0"

set "NODE=C:\Program Files\nodejs\node.exe"
set "NPM=C:\Program Files\nodejs\npm.cmd"

if not exist "%NODE%" (
    echo [HATA] Node.js bulunamadi.
    echo https://nodejs.org adresinden kurun.
    pause
    exit /b 1
)

echo ========================================
echo 1. Bagimliliklari yukluyorum...
echo ========================================
"%NPM%" install
if errorlevel 1 (
    echo [HATA] npm install basarisiz.
    pause
    exit /b 1
)

echo.
echo ========================================
echo 2. Sunucu baslatiliyor.
echo    Adres: http://localhost:3030
echo    Bu pencereyi KAPATMA - kapatirsan sunucu durur.
echo ========================================
echo.
"%NODE%" server.js

pause

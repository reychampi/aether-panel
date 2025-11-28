@echo off
setlocal enabledelayedexpansion
title Aether Panel - Windows Launcher
color 0b

:: ==========================================
::   VERIFICACION DE PERMISOS
:: ==========================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [!] Necesitas ejecutar esto como Administrador para la primera instalacion.
    echo     (Click derecho -> Ejecutar como administrador)
    echo.
    pause
    exit
)

cls
echo ==========================================
echo        AETHER PANEL - WINDOWS
echo ==========================================
echo.

:: 1. INSTALACION DE DEPENDENCIAS (Solo si faltan)
node -v >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Instalando Node.js...
    winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements
)

java -version >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Instalando Java 21...
    winget install -e --id EclipseAdoptium.Temurin.21.JDK --accept-source-agreements
)

:: 2. PREPARAR PANEL
if not exist "node_modules" (
    echo [!] Instalando librerias...
    call npm install --production
)

if not exist "public" mkdir public
if not exist "servers\default" mkdir servers\default

if not exist "public\logo.ico" (
    echo [!] Bajando logos...
    powershell -Command "Invoke-WebRequest https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.svg -OutFile public\logo.svg"
    powershell -Command "Invoke-WebRequest https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.ico -OutFile public\logo.ico"
)

:: 3. OBTENER IP LOCAL REAL
for /f "delims=" %%a in ('powershell -command "([System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | Where-Object {$_.AddressFamily -eq 'InterNetwork'})[0].IPAddressToString"') do set SERVER_IP=%%a

cls
echo ==========================================
echo    AETHER PANEL ESTA LISTO
echo ==========================================
echo.
echo [V] Servidor iniciado.
echo.
echo     Acceso Local:   http://localhost:3000
echo     Acceso Red:     http://%SERVER_IP%:3000
echo.
echo [!] Comparte la IP de Red para que otros entren.
echo [!] Cierra esta ventana para apagar el panel.
echo.

:: Arrancar
node server.js
pause

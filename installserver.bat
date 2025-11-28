@echo off
title Aether Panel - Windows Launcher
cls
echo ==========================================
echo        AETHER PANEL FOR WINDOWS
echo ==========================================
echo.

:: 1. Verificar Node.js
node -v >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] Node.js no esta instalado. Por favor instalalo desde nodejs.org
    pause
    exit
)
echo [V] Node.js detectado.

:: 2. Verificar Java
java -version >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] Java no esta instalado. Minecraft no funcionara.
    echo     Instala Java 17 o superior.
    pause
) else (
    echo [V] Java detectado.
)

:: 3. Instalar Dependencias (Si faltan)
if not exist "node_modules" (
    echo.
    echo [!] Instalando dependencias del panel...
    call npm install
)

:: 4. Crear directorios basicos
if not exist "public" mkdir public
if not exist "servers\default" mkdir servers\default

:: 5. Descargar Assets si faltan (Usando Powershell porque Windows no tiene curl/wget fiable en todos)
if not exist "public\logo.ico" (
    echo [!] Descargando logos...
    powershell -Command "Invoke-WebRequest https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.svg -OutFile public\logo.svg"
    powershell -Command "Invoke-WebRequest https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.ico -OutFile public\logo.ico"
)

:: 6. Iniciar Servidor
echo.
echo [!] Iniciando Aether Panel en el puerto 3000...
echo     Accede en tu navegador a: http://localhost:3000
echo.

node server.js
pause

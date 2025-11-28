@echo off
title Aether Panel - Actualizador
color 0b
cls

echo ==========================================
echo      AETHER PANEL - ACTUALIZADOR
echo ==========================================
echo.

:: CONFIGURACION
set "REPO_ZIP=https://github.com/reychampi/aether-panel/archive/refs/heads/main.zip"
set "TEMP_DIR=%TEMP%\aether_update_%RANDOM%"
set "APP_DIR=%~dp0"

:: 1. MATAR PROCESO NODE (Cierra el panel actual para poder sobrescribir)
echo [1/5] Deteniendo Aether Panel...
taskkill /F /IM node.exe >nul 2>&1

:: 2. DESCARGA
echo [2/5] Descargando ultima version...
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"
powershell -Command "Invoke-WebRequest '%REPO_ZIP%' -OutFile '%TEMP_DIR%\update.zip'"

:: 3. DESCOMPRIMIR
echo [3/5] Extrayendo archivos...
powershell -Command "Expand-Archive -Path '%TEMP_DIR%\update.zip' -DestinationPath '%TEMP_DIR%' -Force"

:: Buscar la carpeta interna (a veces se llama aether-panel-main)
for /d %%I in ("%TEMP_DIR%\aether-panel-*") do set "SOURCE_DIR=%%I"

:: 4. COPIAR ARCHIVOS (Excluyendo configuraciones)
echo [4/5] Aplicando actualizacion...
:: Usamos robocopy porque es robusto. /E=Recursivo, /XO=Excluir antiguos, /XC=Excluir cambiados (Opcional)
:: Excluimos settings.json, carpeta servers, backups y node_modules para ir rapido
robocopy "%SOURCE_DIR%" "%APP_DIR%." /E /IS /IT /XF settings.json server.properties update.log /XD servers backups node_modules .git

:: 5. REINSTALAR DEPENDENCIAS Y REINICIAR
echo [5/5] Actualizando dependencias...
call npm install --production

echo.
echo [V] Actualizacion completada. Reiniciando...
timeout /t 3 >nul

:: Volver a abrir el lanzador
start "" "start_windows.bat"

:: Limpieza y salida
rmdir /s /q "%TEMP_DIR%"
exit

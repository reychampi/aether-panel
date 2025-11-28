#!/bin/bash

# ============================================================
# AETHER PANEL - LIVE UPDATER (CURL MODE)
# Descarga y sobrescribe en caliente. Reinicia al final.
# ============================================================

LOG="/opt/aetherpanel/update.log"
APP_DIR="/opt/aetherpanel"
REPO_ZIP="https://github.com/reychampi/aether-panel/archive/refs/heads/main.zip"

# Función de log simple
log() { echo "[$(date +'%T')] $1" >> $LOG; }

log "--- INICIANDO ACTUALIZACIÓN ---"

# 1. IR AL DIRECTORIO
cd "$APP_DIR" || exit 1

# 2. DESCARGAR Y EXTRAER (Usando CURL como pediste)
log "⬇️ Descargando código..."
curl -sL "$REPO_ZIP" -o update.zip
unzip -q -o update.zip

# 3. INSTALAR SOBRE LA MARCHA
# Movemos los archivos de la carpeta extraída a la raíz, forzando sobrescritura
log "♻️ Aplicando archivos..."
cp -rf aether-panel-main/* .
rm -rf aether-panel-main update.zip

# 4. ASEGURAR PERMISOS
chmod +x updater.sh installserver.sh

# 5. ACTUALIZAR DEPENDENCIAS (Silencioso)
log "📦 Actualizando librerías..."
npm install --production > /dev/null 2>&1

# 6. REINICIO FINAL
# Solo aquí reiniciamos. Como es el último paso, si el script muere, ya ha terminado.
log "🚀 Reiniciando servicio..."
systemctl restart aetherpanel

log "✅ ACTUALIZACIÓN COMPLETADA"

#!/bin/bash

# ============================================================
# AETHER PANEL - DIRECT UPDATER (Live Mode)
# Estrategia: Descargar -> Descomprimir -> Sobrescribir -> Reiniciar
# ============================================================

LOG="/opt/aetherpanel/update.log"
APP_DIR="/opt/aetherpanel"
REPO_ZIP="https://github.com/reychampi/aether-panel/archive/refs/heads/main.zip"

# Función para registrar logs
log() { echo "[$(date +'%T')] $1" >> $LOG; }

log "--- ⚡ ACTUALIZACIÓN DIRECTA INICIADA ---"

# 1. Ir al directorio del panel
cd "$APP_DIR" || { log "❌ Error: No encuentro el directorio"; exit 1; }

# 2. Limpieza previa de temporales antiguos
rm -rf update.zip aether-panel-main

# 3. Descargar la última versión
log "⬇️ Descargando código..."
curl -sL "$REPO_ZIP" -o update.zip

# 4. Descomprimir
log "📦 Descomprimiendo..."
unzip -q -o update.zip

# 5. Aplicar actualización (Sobrescribir archivos)
log "♻️ Aplicando cambios..."
# Copiamos el contenido de la carpeta descomprimida a la raíz
cp -rf aether-panel-main/* .

# 6. Limpieza post-instalación
rm -rf aether-panel-main update.zip

# 7. Asegurar permisos de ejecución
chmod +x updater.sh installserver.sh

# 8. Actualizar dependencias (por si cambiaron)
log "📚 Actualizando librerías..."
npm install --production > /dev/null 2>&1

# 9. Reiniciar el servicio para aplicar cambios
# Este paso es el final. Al reiniciar, el panel nuevo tomará el control.
log "🚀 Reiniciando servicio..."
systemctl restart aetherpanel

log "✅ ACTUALIZACIÓN COMPLETADA"

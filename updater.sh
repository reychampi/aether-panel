#!/bin/bash

# ============================================================
# AETHER PANEL - SMART UPDATER
# ============================================================

LOG="/opt/aetherpanel/update.log"
APP_DIR="/opt/aetherpanel"
BACKUP_DIR="/opt/aetherpanel_backup_temp"
TEMP_DIR="/tmp/aether_update_temp"
REPO_ZIP="https://github.com/reychampi/aether-panel/archive/refs/heads/main.zip"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG
    echo -e "$1"
}

log_msg "--- 🌌 AETHER UPDATE PROCESS STARTED ---"

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

log_msg "⬇️  Bajando código fuente..."
wget -q "$REPO_ZIP" -O /tmp/aether_update.zip || curl -L "$REPO_ZIP" -o /tmp/aether_update.zip
unzip -q -o /tmp/aether_update.zip -d "$TEMP_DIR"

NEW_SOURCE=$(find "$TEMP_DIR" -name "package.json" | head -n 1 | xargs dirname)

if [ -z "$NEW_SOURCE" ]; then
    log_msg "❌ ERROR: ZIP corrupto."
    exit 1
fi

# Detectar cambios en núcleo para reiniciar
RESTART_REQUIRED=0
CORE_FILES=("server.js" "mc_manager.js" "package.json")
for file in "${CORE_FILES[@]}"; do
    if ! diff -q "$APP_DIR/$file" "$NEW_SOURCE/$file" > /dev/null 2>&1; then
        RESTART_REQUIRED=1
    fi
done

log_msg "🔄 Sincronizando archivos..."
rsync -avc --delete \
    --exclude='settings.json' \
    --exclude='servers/' \
    --exclude='backups/' \
    --exclude='node_modules/' \
    --exclude='update.log' \
    --exclude='eula.txt' \
    --exclude='server.properties' \
    --exclude='updater.sh' \
    --exclude='installserver.sh' \
    "$NEW_SOURCE/" "$APP_DIR/" >> $LOG 2>&1

chmod +x "$APP_DIR/updater.sh"
chmod +x "$APP_DIR/installserver.sh"

if [ $RESTART_REQUIRED -eq 1 ]; then
    log_msg "📦 Actualizando dependencias..."
    cd "$APP_DIR"
    npm install --production >> $LOG 2>&1
    log_msg "🚀 Reiniciando servicio..."
    systemctl restart aetherpanel
else
    log_msg "✅ Sincronización visual completada (Sin reinicio)."
fi

rm -rf "$TEMP_DIR" /tmp/aether_update.zip

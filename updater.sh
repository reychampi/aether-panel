#!/bin/bash

# ============================================================
# AETHER PANEL - ATOMIC UPDATER
# Método: Sobrescribir todo excepto datos de usuario.
# ============================================================

LOG="/opt/aetherpanel/update.log"
APP_DIR="/opt/aetherpanel"
TEMP_DIR="/tmp/aether_update_temp"
REPO_ZIP="https://github.com/reychampi/aether-panel/archive/refs/heads/main.zip"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG
    echo -e "$1"
}

log_msg "--- ⚡ INICIANDO ACTUALIZACIÓN FORZADA ---"

# 1. DESCARGA EN LIMPIO
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

log_msg "⬇️  Descargando código..."
wget -q "$REPO_ZIP" -O /tmp/update.zip || curl -L "$REPO_ZIP" -o /tmp/update.zip
unzip -q -o /tmp/update.zip -d "$TEMP_DIR"

NEW_SOURCE=$(find "$TEMP_DIR" -name "package.json" | head -n 1 | xargs dirname)

if [ -z "$NEW_SOURCE" ]; then
    log_msg "❌ ERROR: Descarga fallida."
    exit 1
fi

# 2. PARADA DE SEGURIDAD
log_msg "🛑 Deteniendo servicio..."
systemctl stop aetherpanel

# 3. SOBRESCRITURA MASIVA (Salvo configs)
log_msg "♻️  Reemplazando archivos del sistema..."

# Usamos rsync para forzar el estado exacto del repo, pero protegiendo tus datos
# --delete: Borra archivos basura que ya no existan en el repo
rsync -a --delete \
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

# 4. REPARACIÓN DE PERMISOS Y DEPENDENCIAS
log_msg "🔧 Ajustando permisos y dependencias..."
cd "$APP_DIR"
# Forzamos reinstalación de dependencias por si el package.json cambió
npm install --production >> $LOG 2>&1

# Asegurar ejecutables
chmod +x "$APP_DIR/updater.sh"
chmod +x "$APP_DIR/installserver.sh"

# 5. ARRANQUE
log_msg "🚀 Iniciando Aether Panel..."
systemctl start aetherpanel

# Verificación final
sleep 5
if systemctl is-active --quiet aetherpanel; then
    log_msg "✅ ACTUALIZACIÓN COMPLETADA EXITOSAMENTE."
else
    log_msg "🚨 ERROR: El panel no arrancó. Revisa 'sudo journalctl -u aetherpanel -n 50'"
fi

# Limpieza
rm -rf "$TEMP_DIR" /tmp/update.zip

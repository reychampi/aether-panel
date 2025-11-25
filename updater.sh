#!/bin/bash

# ============================================================
# NEBULA SMART UPDATER V2 (FIXED)
# - Estructura de carpetas inteligente
# - Corrección de permisos
# - Limpieza de node_modules
# ============================================================

LOG="/opt/aetherpanel/update.log"
BACKUP_DIR="/opt/aetherpanel_backup_temp"
APP_DIR="/opt/aetherpanel"
REPO_ZIP="https://github.com/reychampi/nebula/archive/refs/heads/main.zip"

# Función de log
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG
}

log_msg "--- UPDATE START ---"

# 1. CREAR BACKUP
log_msg "Creating backup snapshot..."
rm -rf $BACKUP_DIR
cp -r $APP_DIR $BACKUP_DIR

# 2. DETENER SERVICIO
# Intentamos parar cualquier proceso de node o el servicio
systemctl stop aetherpanel >> $LOG 2>&1
pkill -f "node server.js" >> $LOG 2>&1

# 3. DESCARGAR Y PREPARAR
log_msg "Downloading update..."
rm -rf /tmp/nebula_update /tmp/update.zip
mkdir -p /tmp/nebula_update
wget -q $REPO_ZIP -O /tmp/update.zip

# 4. DESCOMPRIMIR
log_msg "Unzipping..."
unzip -q -o /tmp/update.zip -d /tmp/nebula_update

# 5. DETECCIÓN INTELIGENTE DE LA CARPETA RAÍZ
# Buscamos la carpeta que contenga el 'server.js' para asegurar que es la correcta
EXTRACTED_DIR=$(find /tmp/nebula_update -name "server.js" | head -n 1 | xargs dirname)

if [ -z "$EXTRACTED_DIR" ]; then
    log_msg "🚨 ERROR: No se encontró server.js en la actualización. Abortando."
    # Restaurar servicio y salir
    systemctl start aetherpanel
    exit 1
fi

log_msg "Valid source found at: $EXTRACTED_DIR"

# 6. INSTALACIÓN DE ARCHIVOS (Con lógica de 'public')
log_msg "Applying files..."

# Copiamos todo lo de la raíz primero
cp -rf "$EXTRACTED_DIR"/* "$APP_DIR/" >> $LOG 2>&1

# === CORRECCIÓN CRÍTICA DE PUBLIC ===
# Si los archivos web quedaron en la raíz, los movemos a public
mkdir -p "$APP_DIR/public"

if [ -f "$APP_DIR/index.html" ]; then
    log_msg "Fixing file structure: Moving web files to public/..."
    mv "$APP_DIR/index.html" "$APP_DIR/public/" 2>/dev/null
    mv "$APP_DIR/style.css" "$APP_DIR/public/" 2>/dev/null
    mv "$APP_DIR/app.js" "$APP_DIR/public/" 2>/dev/null
    mv "$APP_DIR/logo.svg" "$APP_DIR/public/" 2>/dev/null
    mv "$APP_DIR/logo.ico" "$APP_DIR/public/" 2>/dev/null
    mv "$APP_DIR/logo.png" "$APP_DIR/public/" 2>/dev/null
fi
# ====================================

# 7. LIMPIEZA Y PERMISOS
log_msg "Cleaning and fixing permissions..."
rm -f "$APP_DIR/installserver.sh" "$APP_DIR/README.md" "$APP_DIR/.gitignore"
chmod +x "$APP_DIR/updater.sh"

# 8. INSTALAR DEPENDENCIAS (Limpio)
cd "$APP_DIR"
# Borramos node_modules para evitar conflictos de versiones viejas
rm -rf node_modules
log_msg "Installing dependencies..."
npm install --production >> $LOG 2>&1

# 9. ARREGLAR DUEÑO DE ARCHIVOS (Importante si no eres root)
# Asumimos que el usuario actual o root debe ser el dueño, ajusta si usas un usuario 'nebula'
chown -R root:root "$APP_DIR" 
chmod -R 755 "$APP_DIR"

# 10. REINICIAR Y VERIFICAR
log_msg "Starting server..."
systemctl start aetherpanel >> $LOG 2>&1

sleep 10

if systemctl is-active --quiet aetherpanel; then
    log_msg "✅ UPDATE SUCCESSFUL: System is stable."
    rm -rf $BACKUP_DIR
    # Notificar al socket (opcional, requiere curl local)
else
    log_msg "🚨 UPDATE FAILED: System crashed. ROLLING BACK..."
    
    systemctl stop aetherpanel
    rm -rf $APP_DIR/*
    cp -r $BACKUP_DIR/* $APP_DIR/
    chmod +x $APP_DIR/updater.sh
    cd $APP_DIR
    npm install --production
    systemctl start aetherpanel
    
    log_msg "✅ ROLLBACK COMPLETED."
fi

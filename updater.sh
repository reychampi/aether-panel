#!/bin/bash

# ============================================================
# NEBULA SMART UPDATER (V1.3.5 LOGO HUNTER)
# - Busca logo.svg/ico en cualquier subcarpeta y los coloca bien.
# - Rollback automático si el servidor crashea.
# ============================================================

LOG="/opt/aetherpanel/update.log"
BACKUP_DIR="/opt/aetherpanel_backup_temp"
APP_DIR="/opt/aetherpanel"
REPO_ZIP="https://github.com/reychampi/nebula/archive/refs/heads/main.zip"

echo "--- UPDATE START $(date) ---" > $LOG

# 1. CREAR PUNTO DE RESTAURACIÓN (Seguridad)
echo "Creating backup..." >> $LOG
rm -rf $BACKUP_DIR
cp -r $APP_DIR $BACKUP_DIR

# 2. DETENER SERVICIO
systemctl stop aetherpanel >> $LOG 2>&1

# 3. DESCARGAR Y DESCOMPRIMIR
echo "Downloading..." >> $LOG
rm -rf /tmp/nebula_update /tmp/update.zip
mkdir -p /tmp/nebula_update
wget -q $REPO_ZIP -O /tmp/update.zip
unzip -q -o /tmp/update.zip -d /tmp/nebula_update

# 4. INSTALACIÓN INTELIGENTE
# Detectamos la carpeta raíz del ZIP
EXTRACTED_DIR=$(ls /tmp/nebula_update | head -n 1)
SOURCE="$tmp/nebula_update/$EXTRACTED_DIR"

echo "Copying core files..." >> $LOG
# Copiamos todo recursivamente
cp -rf /tmp/nebula_update/$EXTRACTED_DIR/* $APP_DIR/ >> $LOG 2>&1

# --- FIX LOGOS (RASTREADOR) ---
# Busca los logos en la descarga y fuerzalos a /public
echo "Hunting logos..." >> $LOG
find /tmp/nebula_update -name "logo.svg" -exec cp {} $APP_DIR/public/ \;
find /tmp/nebula_update -name "logo.ico" -exec cp {} $APP_DIR/public/ \;
find /tmp/nebula_update -name "logo.png" -exec cp {} $APP_DIR/public/ \;

# 5. LIMPIEZA Y PERMISOS
rm -f $APP_DIR/installserver.sh $APP_DIR/README.md
chmod +x $APP_DIR/updater.sh
chmod -R 755 $APP_DIR/public
cd $APP_DIR
npm install --production >> $LOG 2>&1

# 6. HEALTH CHECK (Rollback si falla)
echo "Testing boot..." >> $LOG
systemctl start aetherpanel >> $LOG 2>&1
sleep 10

if systemctl is-active --quiet aetherpanel; then
    echo "✅ UPDATE SUCCESSFUL" >> $LOG
    rm -rf $BACKUP_DIR
else
    echo "🚨 CRASH DETECTED -> ROLLING BACK" >> $LOG
    systemctl stop aetherpanel
    rm -rf $APP_DIR/*
    cp -r $BACKUP_DIR/* $APP_DIR/
    systemctl start aetherpanel
fi

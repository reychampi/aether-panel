#!/bin/bash

# ============================================================
# AETHER PANEL - SMART UPDATER
# Soft Update: Cambios en /public (Sin reinicio)
# Hard Update: Cambio de versión en package.json (Con reinicio)
# ============================================================

LOG="/opt/aetherpanel/update.log"
APP_DIR="/opt/aetherpanel"
REPO_ZIP="https://github.com/reychampi/nebula/archive/refs/heads/main.zip"
TEMP_DIR="/tmp/nebula_update_temp"

# Función para loguear
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG
    echo "$1"
}

log_msg "--- CHECKING FOR UPDATES ---"

# 1. LIMPIEZA Y DESCARGA
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Descargamos el repo en una carpeta temporal
wget -q "$REPO_ZIP" -O /tmp/nebula_update.zip || curl -L "$REPO_ZIP" -o /tmp/nebula_update.zip
unzip -q -o /tmp/nebula_update.zip -d "$TEMP_DIR"

# Identificar la raíz descomprimida (donde está package.json)
NEW_SOURCE=$(find "$TEMP_DIR" -name "package.json" | head -n 1 | xargs dirname)

if [ -z "$NEW_SOURCE" ]; then
    log_msg "🚨 ERROR: Descarga corrupta o estructura inválida."
    exit 1
fi

# 2. LECTURA DE VERSIONES (Usando Node para precisión JSON)
# Si no existe el package.json local (primera instalación), asumimos versión 0.0.0
if [ -f "$APP_DIR/package.json" ]; then
    CURRENT_VERSION=$(node -p "require('$APP_DIR/package.json').version")
else
    CURRENT_VERSION="0.0.0"
fi

NEW_VERSION=$(node -p "require('$NEW_SOURCE/package.json').version")

log_msg "🔍 Versión Actual: $CURRENT_VERSION | Nueva Versión: $NEW_VERSION"

# 3. LÓGICA DE ACTUALIZACIÓN

# CASO A: CAMBIO DE VERSIÓN (HARD UPDATE)
# Si las versiones son diferentes, reiniciamos todo.
if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
    log_msg "⚠️  Cambio de versión detectado ($CURRENT_VERSION -> $NEW_VERSION). Iniciando HARD UPDATE."
    
    # Detener servicio
    systemctl stop aetherpanel
    
    # Copiar TODO (Sobrescribe lógica y visual)
    cp -rf "$NEW_SOURCE/"* "$APP_DIR/"
    
    # Instalar nuevas dependencias si las hay
    cd "$APP_DIR"
    npm install --production >> $LOG 2>&1
    
    # Restaurar permisos del updater
    chmod +x "$APP_DIR/updater.sh"
    
    # Reiniciar servicio
    systemctl start aetherpanel
    log_msg "✅ Sistema actualizado y reiniciado."

# CASO B: MISMA VERSIÓN (SOFT UPDATE / VISUAL CHECK)
else
    log_msg "ℹ️  Misma versión. Buscando cambios visuales en /public..."
    
    # Comparamos recursivamente solo la carpeta public
    # diff -r -q devuelve 1 si hay diferencias, 0 si son iguales
    diff -r -q "$APP_DIR/public" "$NEW_SOURCE/public" > /dev/null
    
    if [ $? -ne 0 ]; then
        log_msg "🎨 Cambios visuales detectados. Aplicando SOFT UPDATE (Hot-swap)."
        
        # Solo copiamos la carpeta public
        cp -rf "$NEW_SOURCE/public/"* "$APP_DIR/public/"
        
        log_msg "✅ Interfaz actualizada sin reiniciar el servicio."
    else
        log_msg "💤 No hay cambios visuales ni de sistema. Todo al día."
    fi
fi

# Limpieza final
rm -rf "$TEMP_DIR" /tmp/nebula_update.zip

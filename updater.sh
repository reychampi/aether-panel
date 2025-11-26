#!/bin/bash
APP_DIR="/opt/aetherpanel"
BACKUP_DIR="/opt/aetherpanel_backup_temp"
TEMP_DIR="/tmp/aether_update_temp"
REPO_ZIP="https://github.com/reychampi/aether-panel/archive/refs/heads/main.zip"

echo "🌌 UPDATING..."
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

wget -q "$REPO_ZIP" -O /tmp/aether_update.zip || curl -L "$REPO_ZIP" -o /tmp/aether_update.zip
unzip -q -o /tmp/aether_update.zip -d "$TEMP_DIR"

NEW_SOURCE=$(find "$TEMP_DIR" -name "package.json" | head -n 1 | xargs dirname)
if [ -z "$NEW_SOURCE" ]; then exit 1; fi

if [ -f "$APP_DIR/package.json" ]; then
    CUR_VER=$(node -p "require('$APP_DIR/package.json').version")
else
    CUR_VER="0.0.0"
fi
NEW_VER=$(node -p "require('$NEW_SOURCE/package.json').version")

if [ "$CUR_VER" == "$NEW_VER" ]; then
    if ! diff -r -q "$APP_DIR/public" "$NEW_SOURCE/public" > /dev/null; then
        cp -rf "$NEW_SOURCE/public/"* "$APP_DIR/public/"
    fi
else
    rm -rf "$BACKUP_DIR"
    cp -r "$APP_DIR" "$BACKUP_DIR"
    systemctl stop aetherpanel
    rsync -av --exclude='settings.json' --exclude='servers' "$NEW_SOURCE/" "$APP_DIR/"
    cd "$APP_DIR"
    npm install --production
    chmod +x "$APP_DIR/updater.sh"
    systemctl start aetherpanel
    sleep 10
    if ! systemctl is-active --quiet aetherpanel; then
        systemctl stop aetherpanel
        cp -r "$BACKUP_DIR/"* "$APP_DIR/"
        systemctl start aetherpanel
    fi
fi
rm -rf "$TEMP_DIR" /tmp/aether_update.zip

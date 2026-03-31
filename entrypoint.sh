#!/bin/bash
set -e

BACKUP_DIR="/workspace/.opencode-backup"
AUTH_FILE="/root/.local/share/opencode/auth.json"
CONFIG_FILE="/root/.config/opencode/opencode.json"
DB_FILE="/root/.local/share/opencode/opencode.db"

mkdir -p "$BACKUP_DIR"

backup() {
  echo "[opencode-persist] Backing up state..."
  cp -f "$AUTH_FILE" "$BACKUP_DIR/auth.json" 2>/dev/null || true
  cp -f "$CONFIG_FILE" "$BACKUP_DIR/opencode.json" 2>/dev/null || true
  cp -f "$DB_FILE" "$BACKUP_DIR/opencode.db" 2>/dev/null || true
  echo "[opencode-persist] Backup complete."
}

restore() {
  RESTORED=false
  if [ ! -f "$AUTH_FILE" ] && [ -f "$BACKUP_DIR/auth.json" ]; then
    mkdir -p "$(dirname "$AUTH_FILE")"
    cp -f "$BACKUP_DIR/auth.json" "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
    RESTORED=true
    echo "[opencode-persist] Restored auth.json"
  fi
  if [ ! -f "$CONFIG_FILE" ] && [ -f "$BACKUP_DIR/opencode.json" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cp -f "$BACKUP_DIR/opencode.json" "$CONFIG_FILE"
    RESTORED=true
    echo "[opencode-persist] Restored opencode.json"
  fi
  if [ ! -f "$DB_FILE" ] && [ -f "$BACKUP_DIR/opencode.db" ]; then
    mkdir -p "$(dirname "$DB_FILE")"
    cp -f "$BACKUP_DIR/opencode.db" "$DB_FILE"
    RESTORED=true
    echo "[opencode-persist] Restored opencode.db"
  fi
  if [ "$RESTORED" = true ]; then
    echo "[opencode-persist] State restored from backup."
  else
    echo "[opencode-persist] No restore needed - state files present."
  fi
}

case "$1" in
  backup) backup ;;
  restore) restore ;;
  *) restore ;;
esac

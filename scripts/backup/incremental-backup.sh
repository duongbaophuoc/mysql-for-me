#!/bin/bash
# =============================================================================
# Incremental Backup Script
# Script Backup Gia Tăng
# =============================================================================
# Uses XtraBackup incremental backup on top of a full backup base
# Sử dụng XtraBackup incremental trên nền full backup
#
# Schedule / Lịch:
#   Daily full:        0 2 * * * bash full-backup.sh
#   Hourly incremental: 0 * * * * bash incremental-backup.sh
# =============================================================================

set -euo pipefail

MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-/backups}"
TODAY=$(date '+%Y%m%d')
NOW=$(date '+%Y%m%d_%H%M%S')
FULL_BACKUP_DIR="$BACKUP_BASE_DIR/full_$TODAY"
INCR_BACKUP_DIR="$BACKUP_BASE_DIR/incr_$NOW"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $*" >&2; exit 1; }

# Check if today's full backup exists / Kiểm tra full backup hôm nay có tồn tại
if [[ ! -d "$FULL_BACKUP_DIR" ]]; then
    error "No full backup found for today at $FULL_BACKUP_DIR. Run full-backup.sh first."
fi

# Find the most recent backup (full or last incremental) to use as base
# Tìm backup gần nhất (full hoặc incremental cuối) để làm base
LAST_BACKUP=$(ls -dt "$BACKUP_BASE_DIR/incr_${TODAY}"_* 2>/dev/null | head -1 || echo "$FULL_BACKUP_DIR")
if [[ -z "$LAST_BACKUP" ]]; then
    LAST_BACKUP="$FULL_BACKUP_DIR"
fi
log "Base backup: $LAST_BACKUP"

# Run incremental backup / Chạy incremental backup
log "Starting incremental backup to $INCR_BACKUP_DIR..."
mkdir -p "$INCR_BACKUP_DIR"

if command -v xtrabackup &>/dev/null; then
    xtrabackup \
        --backup \
        --user="$MYSQL_USER" \
        --password="$MYSQL_PASSWORD" \
        --target-dir="$INCR_BACKUP_DIR" \
        --incremental-basedir="$LAST_BACKUP" \
        --parallel=2 \
        --compress
    log "✅ XtraBackup incremental completed: $INCR_BACKUP_DIR"
else
    # Fallback: binlog backup / Dự phòng: backup binlog
    log "XtraBackup not found — backing up binary logs instead..."
    BINLOG_DIR="$BACKUP_BASE_DIR/binlogs_$TODAY"
    mkdir -p "$BINLOG_DIR"
    mysqlbinlog \
        --read-from-remote-server \
        --host=localhost \
        --user="$MYSQL_USER" \
        --password="$MYSQL_PASSWORD" \
        --to-last-log \
        --raw \
        --result-file="$BINLOG_DIR/" \
        mysql-bin.000001
    log "✅ Binary log backup completed: $BINLOG_DIR"
fi

# Report size / Báo cáo kích thước
BACKUP_SIZE=$(du -sh "$INCR_BACKUP_DIR" 2>/dev/null | awk '{print $1}')
log "Backup size: $BACKUP_SIZE"
log "=== Incremental backup complete / Backup gia tăng hoàn tất ==="

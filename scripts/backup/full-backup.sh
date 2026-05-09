#!/bin/bash
# =============================================================================
# Full MySQL Backup Script / Script Backup MySQL Đầy Đủ
# Uses XtraBackup for hot physical backup / Dùng XtraBackup backup vật lý nóng
# =============================================================================

set -euo pipefail

# Configuration / Cấu hình
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_BASE_DIR}/full_${TIMESTAMP}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "=== MySQL Full Backup Started / Backup MySQL Đầy Đủ Bắt Đầu ==="
log "Host: $MYSQL_HOST:$MYSQL_PORT"
log "Destination / Đích: $BACKUP_DIR"

# Create backup directory / Tạo thư mục backup
mkdir -p "$BACKUP_DIR"

# Check if XtraBackup is available / Kiểm tra XtraBackup có sẵn
if command -v xtrabackup &>/dev/null; then
    log "Using XtraBackup (hot backup, no downtime) / Dùng XtraBackup (không gián đoạn)..."
    
    xtrabackup \
        --backup \
        --host="$MYSQL_HOST" \
        --port="$MYSQL_PORT" \
        --user="$MYSQL_USER" \
        --password="$MYSQL_PASSWORD" \
        --target-dir="$BACKUP_DIR" \
        --compress \
        --parallel=4

    # Prepare the backup / Chuẩn bị backup
    log "Preparing backup / Chuẩn bị backup..."
    xtrabackup \
        --prepare \
        --target-dir="$BACKUP_DIR" \
        --decompress

    BACKUP_TYPE="xtrabackup"
else
    log "XtraBackup not found, using mysqldump / Không tìm thấy XtraBackup, dùng mysqldump..."

    mysqldump \
        --host="$MYSQL_HOST" \
        --port="$MYSQL_PORT" \
        --user="$MYSQL_USER" \
        --password="$MYSQL_PASSWORD" \
        --all-databases \
        --single-transaction \
        --master-data=2 \
        --flush-logs \
        --routines \
        --triggers \
        --events \
        | gzip > "${BACKUP_DIR}/all_databases.sql.gz"

    BACKUP_TYPE="mysqldump"
fi

# Record backup metadata / Ghi metadata backup
cat > "${BACKUP_DIR}/backup_info.txt" << EOF
Backup Type    / Loại backup: $BACKUP_TYPE
Start Time     / Thời gian bắt đầu: $TIMESTAMP
MySQL Host     / Host MySQL: $MYSQL_HOST:$MYSQL_PORT
MySQL Version  / Phiên bản MySQL: $(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -se "SELECT VERSION()" 2>/dev/null)
Backup Size    / Kích thước backup: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

log "Backup completed / Backup hoàn tất: $BACKUP_DIR"
log "$(cat "${BACKUP_DIR}/backup_info.txt")"

# Cleanup old backups / Dọn backup cũ
log "Cleaning backups older than ${RETENTION_DAYS} days..."
log "Dọn backup cũ hơn ${RETENTION_DAYS} ngày..."

find "$BACKUP_BASE_DIR" -maxdepth 1 -name "full_*" \
    -mtime "+${RETENTION_DAYS}" \
    -exec rm -rf {} +

log "=== Backup completed successfully / Backup hoàn tất thành công ==="

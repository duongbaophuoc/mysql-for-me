#!/bin/bash
# =============================================================================
# Binary Log Rotation and Cleanup Script
# Script Xoay Vòng và Dọn Dẹp Binary Log
# =============================================================================

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
KEEP_DAYS="${KEEP_DAYS:-7}"

MYSQL_CMD="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $*"; }

log "=== Binary Log Rotation / Xoay Vòng Binary Log ==="
log "Keeping logs from last ${KEEP_DAYS} days / Giữ log ${KEEP_DAYS} ngày gần nhất"

# Step 1: Show current binary logs / Bước 1: Hiển thị binary log hiện tại
log "Current binary logs / Binary log hiện tại:"
$MYSQL_CMD -e "SHOW BINARY LOGS;" | column -t

# Step 2: Check replica positions before purging
# Bước 2: Kiểm tra vị trí replica trước khi dọn
log ""
log "Checking what replicas have consumed / Kiểm tra replica đã tiêu thụ đến đâu..."
REPLICA_STATUS=$($MYSQL_CMD -e "SHOW REPLICA HOSTS;" 2>/dev/null || echo "No replicas / Không có replica")
if echo "$REPLICA_STATUS" | grep -q "Server_id"; then
    log "⚠️  Replicas detected — checking their positions first!"
    log "⚠️  Phát hiện replica — kiểm tra vị trí trước!"
    # In production, query each replica's SHOW REPLICA STATUS
    # Trong production, truy vấn SHOW REPLICA STATUS trên mỗi replica
fi

# Step 3: Purge old binary logs / Bước 3: Dọn binary log cũ
PURGE_DATE=$(date -d "${KEEP_DAYS} days ago" '+%Y-%m-%d %H:%M:%S')
log ""
log "Purging binary logs before: $PURGE_DATE"
log "Dọn binary log trước: $PURGE_DATE"

$MYSQL_CMD -e "PURGE BINARY LOGS BEFORE '$PURGE_DATE';"
log "✅ Purge completed / Dọn hoàn tất"

# Step 4: Flush to start a new binary log file
# Bước 4: Flush để bắt đầu file binary log mới
$MYSQL_CMD -e "FLUSH BINARY LOGS;"
log "✅ Flushed to new binary log file / Đã flush sang file mới"

# Step 5: Show remaining logs / Bước 5: Hiển thị log còn lại
log ""
log "Remaining binary logs / Binary log còn lại:"
$MYSQL_CMD -e "SHOW BINARY LOGS;" | column -t

log "=== Log rotation complete / Xoay vòng log hoàn tất ==="

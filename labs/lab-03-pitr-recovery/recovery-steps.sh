#!/bin/bash
# =============================================================================
# PITR Recovery Script / Script Phục Hồi Theo Thời Điểm
# Usage: ./recovery-steps.sh "YYYY-MM-DD HH:MM:SS"
# =============================================================================

set -e

TARGET_TIME="${1:-$(date '+%Y-%m-%d %H:%M:%S')}"
BACKUP_FILE="/tmp/shop_db_backup.sql"
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASSWORD="secret"
BINLOG_PATH="/var/lib/mysql"

echo "============================================================"
echo "PITR Recovery / Phục hồi theo thời điểm"
echo "Target time / Thời điểm mục tiêu: $TARGET_TIME"
echo "============================================================"

# Step 1: Restore base backup / Bước 1: Khôi phục backup cơ sở
echo ""
echo "[Step 1] Restoring base backup / Khôi phục backup cơ sở..."
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" shop_db < "$BACKUP_FILE"
echo "✅ Base backup restored / Backup cơ sở đã khôi phục"

# Step 2: Find binlog position from backup / Bước 2: Tìm vị trí binlog từ backup
echo ""
echo "[Step 2] Finding binlog start position / Tìm vị trí bắt đầu binlog..."
START_FILE=$(grep "MASTER_LOG_FILE" "$BACKUP_FILE" | grep -oP "(?<=')[^']*")
START_POS=$(grep "MASTER_LOG_POS"  "$BACKUP_FILE" | grep -oP "[0-9]+(?=;)")
echo "Binlog file / File binlog: $START_FILE"
echo "Start position / Vị trí bắt đầu: $START_POS"

# Step 3: Apply binlogs up to target time
# Bước 3: Áp dụng binlog đến thời điểm mục tiêu
echo ""
echo "[Step 3] Applying binary logs to: $TARGET_TIME"
echo "[Step 3] Áp dụng binary log đến: $TARGET_TIME"

# Get all binlog files from container / Lấy tất cả file binlog từ container
BINLOG_FILES=$(docker exec mysql-primary ls "$BINLOG_PATH"/mysql-bin.[0-9]* 2>/dev/null | tr '\n' ' ')

docker exec mysql-primary mysqlbinlog \
    --start-position="$START_POS" \
    --stop-datetime="$TARGET_TIME" \
    $BINLOG_FILES \
    | mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" shop_db

echo "✅ Binlogs applied / Đã áp dụng binlog"

# Step 4: Verify / Bước 4: Xác minh
echo ""
echo "[Step 4] Verification / Xác minh..."
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "
USE shop_db;
SELECT 'orders' AS tbl, COUNT(*) AS rows FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments;
"

echo ""
echo "============================================================"
echo "PITR Recovery Complete / Phục Hồi Hoàn Tất"
echo "Restored to: $TARGET_TIME"
echo "============================================================"

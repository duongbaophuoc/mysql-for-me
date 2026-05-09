#!/bin/bash
# =============================================================================
# GTID Replication Setup Script / Script Thiết Lập GTID Replication
# Run from the host to configure primary-to-replica replication
# Chạy từ host để cấu hình primary-to-replica replication
# =============================================================================

set -euo pipefail

PRIMARY_HOST="${PRIMARY_HOST:-127.0.0.1}"
PRIMARY_PORT="${PRIMARY_PORT:-3306}"
REPLICA_HOST="${REPLICA_HOST:-127.0.0.1}"
REPLICA_PORT="${REPLICA_PORT:-3307}"
ROOT_PASSWORD="${ROOT_PASSWORD:-secret}"
REPL_USER="${REPL_USER:-replicator}"
REPL_PASSWORD="${REPL_PASSWORD:-repl_secret}"

PRIMARY_CMD="mysql -h $PRIMARY_HOST -P $PRIMARY_PORT -u root -p$ROOT_PASSWORD"
REPLICA_CMD="mysql -h $REPLICA_HOST -P $REPLICA_PORT -u root -p$ROOT_PASSWORD"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: $*" >&2; exit 1; }

log "=== Setting Up GTID Replication / Thiết Lập GTID Replication ==="
log "Primary: $PRIMARY_HOST:$PRIMARY_PORT"
log "Replica: $REPLICA_HOST:$REPLICA_PORT"

# Step 1: Verify GTID is enabled on primary
# Bước 1: Xác minh GTID được bật trên primary
log "[1/6] Checking GTID mode on primary / Kiểm tra chế độ GTID trên primary..."
GTID_MODE=$($PRIMARY_CMD -se "SELECT @@gtid_mode")
if [ "$GTID_MODE" != "ON" ]; then
    err "GTID mode is not ON on primary. Set gtid_mode=ON in my.cnf and restart."
fi
log "✅ GTID mode: $GTID_MODE"

# Step 2: Create replication user on primary
# Bước 2: Tạo user replication trên primary
log "[2/6] Creating replication user / Tạo user replication..."
$PRIMARY_CMD -e "
CREATE USER IF NOT EXISTS '$REPL_USER'@'%'
    IDENTIFIED WITH mysql_native_password BY '$REPL_PASSWORD';
GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';
FLUSH PRIVILEGES;
"
log "✅ Replication user created / User replication đã tạo: $REPL_USER"

# Step 3: Get primary GTID information
# Bước 3: Lấy thông tin GTID primary
log "[3/6] Getting primary GTID / Lấy GTID primary..."
PRIMARY_STATUS=$($PRIMARY_CMD -e "SHOW MASTER STATUS\G")
EXECUTED_GTIDS=$($PRIMARY_CMD -se "SELECT @@GLOBAL.gtid_executed")
log "Primary executed GTIDs / GTID đã thực thi: ${EXECUTED_GTIDS:0:50}..."

# Step 4: Configure replica to use GTID auto-positioning
# Bước 4: Cấu hình replica dùng GTID tự động định vị
log "[4/6] Configuring replica / Cấu hình replica..."
$REPLICA_CMD -e "
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='$PRIMARY_HOST',
    SOURCE_PORT=$PRIMARY_PORT,
    SOURCE_USER='$REPL_USER',
    SOURCE_PASSWORD='$REPL_PASSWORD',
    SOURCE_AUTO_POSITION=1,
    SOURCE_RETRY_COUNT=10,
    SOURCE_CONNECT_RETRY=30;
"
log "✅ Replica configured / Replica đã cấu hình"

# Step 5: Start replica and verify
# Bước 5: Khởi động replica và xác minh
log "[5/6] Starting replica / Khởi động replica..."
$REPLICA_CMD -e "START REPLICA;"
sleep 5

IO_RUNNING=$($REPLICA_CMD -se "SHOW REPLICA STATUS\G" | grep "Replica_IO_Running:" | awk '{print $2}' || echo "UNKNOWN")
SQL_RUNNING=$($REPLICA_CMD -se "SHOW REPLICA STATUS\G" | grep "Replica_SQL_Running:" | awk '{print $2}' || echo "UNKNOWN")

if [ "$IO_RUNNING" = "Yes" ] && [ "$SQL_RUNNING" = "Yes" ]; then
    log "✅ Replication started successfully / Replication khởi động thành công"
else
    LAST_ERROR=$($REPLICA_CMD -e "SHOW REPLICA STATUS\G" | grep "Last_Error:" | head -1)
    err "Replication failed to start / Replication khởi động thất bại: $LAST_ERROR"
fi

# Step 6: Show final status / Bước 6: Hiển thị trạng thái cuối
log "[6/6] Final status / Trạng thái cuối:"
$REPLICA_CMD -e "
SELECT 
    CHANNEL_NAME             AS channel,
    SERVICE_STATE            AS state,
    COUNT_TRANSACTIONS_BEHIND_SOURCE AS lag_txns
FROM performance_schema.replication_applier_status\G
"

log ""
log "=== GTID Replication Setup Complete / Thiết Lập GTID Replication Hoàn Tất ==="
log "Monitor with / Giám sát với:"
log "  mysql -h $REPLICA_HOST -P $REPLICA_PORT -u root -p$ROOT_PASSWORD -e 'SHOW REPLICA STATUS\\G'"

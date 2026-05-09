#!/bin/bash
# =============================================================================
# Replication Health Check Script / Script Kiểm Tra Trạng Thái Sao Chép
# Run on replicas / Chạy trên replica
# =============================================================================

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
LAG_WARNING="${LAG_WARNING:-30}"    # Seconds / Giây
LAG_CRITICAL="${LAG_CRITICAL:-120}"

MYSQL_CMD="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD -s --skip-column-names"

log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
warn()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  WARNING: $*"; }
error()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ CRITICAL: $*" >&2; }

log "=== MySQL Replication Check / Kiểm Tra Sao Chép MySQL ==="

# Get replica status / Lấy trạng thái replica
IO_RUNNING=$($MYSQL_CMD -e "SHOW REPLICA STATUS\G" | grep "Replica_IO_Running:" | awk '{print $2}')
SQL_RUNNING=$($MYSQL_CMD -e "SHOW REPLICA STATUS\G" | grep "Replica_SQL_Running:" | awk '{print $2}')
LAG=$($MYSQL_CMD -e "SHOW REPLICA STATUS\G" | grep "Seconds_Behind_Source:" | awk '{print $2}')
LAST_ERROR=$($MYSQL_CMD -e "SHOW REPLICA STATUS\G" | grep "Last_Error:" | cut -d' ' -f2-)

EXIT_CODE=0

# Check IO Thread / Kiểm tra IO Thread
if [ "$IO_RUNNING" != "Yes" ]; then
    error "Replica IO Thread is not running! / IO Thread không chạy!"
    error "Last IO Error: $($MYSQL_CMD -e 'SHOW REPLICA STATUS\G' | grep Last_IO_Error)"
    EXIT_CODE=2
else
    log "✅ IO Thread: Running / Đang chạy"
fi

# Check SQL Thread / Kiểm tra SQL Thread
if [ "$SQL_RUNNING" != "Yes" ]; then
    error "Replica SQL Thread is not running! / SQL Thread không chạy!"
    error "Last Error: $LAST_ERROR"
    EXIT_CODE=2
else
    log "✅ SQL Thread: Running / Đang chạy"
fi

# Check lag / Kiểm tra độ trễ
if [ "$LAG" = "NULL" ]; then
    error "Cannot determine replication lag (NULL) / Không thể xác định độ trễ"
    EXIT_CODE=2
elif [ "$LAG" -ge "$LAG_CRITICAL" ]; then
    error "Critical replication lag: ${LAG}s (threshold: ${LAG_CRITICAL}s)"
    error "Độ trễ nghiêm trọng: ${LAG}s (ngưỡng: ${LAG_CRITICAL}s)"
    EXIT_CODE=2
elif [ "$LAG" -ge "$LAG_WARNING" ]; then
    warn "Replication lag is high: ${LAG}s / Độ trễ cao: ${LAG}s"
    [ "$EXIT_CODE" -eq 0 ] && EXIT_CODE=1
else
    log "✅ Replication Lag / Độ trễ: ${LAG}s (OK)"
fi

# GTIDs comparison / So sánh GTID
PRIMARY_GTIDS=$($MYSQL_CMD -e "SHOW MASTER STATUS\G" 2>/dev/null | grep "Executed_Gtid_Set:" | cut -d' ' -f2-)
REPLICA_GTIDS=$($MYSQL_CMD -e "SHOW REPLICA STATUS\G" | grep "Executed_Gtid_Set:" | cut -d' ' -f2-)

log "Primary GTIDs applied / GTID primary đã áp dụng: ${PRIMARY_GTIDS:0:40}..."
log "Replica GTIDs applied / GTID replica đã áp dụng: ${REPLICA_GTIDS:0:40}..."

log "=== Check completed. Exit code: $EXIT_CODE ==="
exit "$EXIT_CODE"

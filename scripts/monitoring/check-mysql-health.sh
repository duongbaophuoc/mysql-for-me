#!/bin/bash
# =============================================================================
# MySQL Health Check Script
# Script Kiểm Tra Sức Khỏe MySQL
# =============================================================================
# Run as cron every 5 minutes / Chạy cron mỗi 5 phút:
#   */5 * * * * /opt/scripts/check-mysql-health.sh >> /var/log/mysql-health.log 2>&1
# =============================================================================

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
ALERT_THRESHOLD_CONNECTIONS=80    # % of max_connections
ALERT_THRESHOLD_LAG=30            # seconds
#ALERT_THRESHOLD_SLOW_QPS=5        # slow queries per second

TS="$(date '+%Y-%m-%d %H:%M:%S')"
STATUS="OK"
ALERTS=()

log()   { echo "[$TS] $*"; }
alert() { ALERTS+=("$*"); STATUS="ALERT"; }

# ─── 1. Connectivity / Kết Nối ────────────────────────────────────────────────
if ! mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" --skip-column-names -e "SELECT 1" > /dev/null 2>&1; then
    echo "[$TS] CRITICAL: Cannot connect to MySQL at $MYSQL_HOST:$MYSQL_PORT!"
    exit 2
fi
log "✅ Connectivity: OK"

# ─── 2. Connection Usage / Sử Dụng Kết Nối ───────────────────────────────────
THREADS_CONNECTED=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" --skip-column-names -e "SHOW STATUS LIKE 'Threads_connected'" | awk '{print $2}')
MAX_CONNECTIONS=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" --skip-column-names -e "SHOW VARIABLES LIKE 'max_connections'" | awk '{print $2}')
CONN_PCT=$(( THREADS_CONNECTED * 100 / MAX_CONNECTIONS ))
log "📊 Connections: $THREADS_CONNECTED / $MAX_CONNECTIONS (${CONN_PCT}%)"
if (( CONN_PCT > ALERT_THRESHOLD_CONNECTIONS )); then
    alert "HIGH CONNECTIONS: ${CONN_PCT}% (${THREADS_CONNECTED}/${MAX_CONNECTIONS})"
fi

# ─── 3. Buffer Pool Hit Rate / Tỷ Lệ Hit Buffer Pool ─────────────────────────
BP_READS=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" --skip-column-names -e "SHOW STATUS LIKE 'Innodb_buffer_pool_reads'" | awk '{print $2}')
BP_READ_REQS=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" --skip-column-names -e "SHOW STATUS LIKE 'Innodb_buffer_pool_read_requests'" | awk '{print $2}')
if (( BP_READ_REQS > 0 )); then
    HIT_RATE=$(( (BP_READ_REQS - BP_READS) * 100 / BP_READ_REQS ))
    log "📊 Buffer Pool Hit Rate: ${HIT_RATE}%"
    if (( HIT_RATE < 95 )); then
        alert "LOW BUFFER POOL HIT RATE: ${HIT_RATE}% (consider increasing innodb_buffer_pool_size)"
    fi
fi

# ─── 4. Replication Lag / Độ Trễ Sao Chép ────────────────────────────────────
REPLICA_HOST="${REPLICA_HOST:-}"
if [[ -n "$REPLICA_HOST" ]]; then
    LAG=$(mysql -h "$REPLICA_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        --skip-column-names \
        -e "SHOW REPLICA STATUS" 2>/dev/null | awk '{print $33}' || echo "NULL")
    if [[ "$LAG" == "NULL" ]] || [[ -z "$LAG" ]]; then
        alert "REPLICATION NOT RUNNING on $REPLICA_HOST"
    elif (( LAG > ALERT_THRESHOLD_LAG )); then
        alert "REPLICATION LAG HIGH: ${LAG}s on $REPLICA_HOST"
    else
        log "✅ Replication lag: ${LAG}s"
    fi
fi

# ─── 5. Slow Queries / Truy Vấn Chậm ─────────────────────────────────────────
SLOW_QUERIES=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" --skip-column-names -e "SHOW STATUS LIKE 'Slow_queries'" | awk '{print $2}')
log "📊 Slow queries (since startup): $SLOW_QUERIES"

# ─── 6. Disk Space Check / Kiểm Tra Dung Lượng Đĩa ──────────────────────────
MYSQL_DATADIR=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" --skip-column-names -e "SHOW VARIABLES LIKE 'datadir'" | awk '{print $2}')
DISK_USAGE=$(df "$MYSQL_DATADIR" 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
log "💾 Disk usage on $MYSQL_DATADIR: ${DISK_USAGE}%"
if (( DISK_USAGE > 80 )); then
    alert "HIGH DISK USAGE: ${DISK_USAGE}% on $MYSQL_DATADIR"
fi

# ─── Summary / Tóm Tắt ──────────────────────────────────────────────────────
echo ""
if [[ "$STATUS" == "OK" ]]; then
    log "✅ Overall Status: OK — All checks passed / Tất cả kiểm tra đạt"
else
    log "🚨 Overall Status: ALERT"
    for a in "${ALERTS[@]}"; do
        log "   ⚠️  $a"
    done
    exit 1
fi

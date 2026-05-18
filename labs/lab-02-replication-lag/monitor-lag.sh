#!/bin/bash
# =============================================================================
# Lab 02: Replication Lag Monitor Script
# Lab 02: Script Giám Sát Độ Trễ Sao Chép
# =============================================================================
# Usage / Sử dụng:
#   bash monitor-lag.sh [--continuous]
# =============================================================================

set -euo pipefail

PRIMARY_HOST="${PRIMARY_HOST:-127.0.0.1}"
PRIMARY_PORT="${PRIMARY_PORT:-3306}"
REPLICA_HOST="${REPLICA_HOST:-127.0.0.1}"
REPLICA_PORT="${REPLICA_PORT:-3307}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"

CON_FLAG="${1:-}"

print_header() {
    echo "============================================================"
    echo " MySQL Replication Lag Monitor / Giám Sát Độ Trễ Sao Chép"
    echo " $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================================"
}

check_lag() {
    echo ""
    echo "─── Primary GTID Position / Vị Trí GTID Primary ───"
    mysql -h "$PRIMARY_HOST" -P "$PRIMARY_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -se "SELECT @@global.gtid_executed" 2>/dev/null | head -c 200
    echo ""

    echo ""
    echo "─── Replica Status / Trạng Thái Replica ───"
    mysql -h "$REPLICA_HOST" -P "$REPLICA_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "
    SELECT
        Replica_IO_Running         AS io_running,
        Replica_SQL_Running        AS sql_running,
        Seconds_Behind_Source      AS lag_seconds,
        Last_IO_Error              AS io_error,
        Last_SQL_Error             AS sql_error,
        Received_Transaction_Set   AS recv_gtids
    FROM performance_schema.replication_connection_status
    JOIN performance_schema.replication_applier_status USING (CHANNEL_NAME)
    " 2>/dev/null || \
    mysql -h "$REPLICA_HOST" -P "$REPLICA_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW REPLICA STATUS\G" 2>/dev/null | grep -E \
        "Replica_IO_Running|Replica_SQL_Running|Seconds_Behind|Last_Error|Last_IO_Error|Last_SQL"

    echo ""
    echo "─── Parallel Workers / Worker Song Song ───"
    mysql -h "$REPLICA_HOST" -P "$REPLICA_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -se "SELECT @@replica_parallel_workers, @@replica_parallel_type" | \
        awk '{printf "  Workers: %s   Type: %s\n", $1, $2}'
}

print_header
check_lag

if [[ "$CON_FLAG" == "--continuous" ]]; then
    echo ""
    echo "Monitoring every 2s... Press Ctrl+C to stop / Nhấn Ctrl+C để dừng"
    while true; do
        sleep 2
        echo ""
        echo "─── $(date '+%H:%M:%S') ───"
        mysql -h "$REPLICA_HOST" -P "$REPLICA_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -se "
            SELECT IFNULL(Seconds_Behind_Source, 'NULL (IO not running)') AS lag_seconds
            FROM performance_schema.replication_connection_status" 2>/dev/null || \
        mysql -h "$REPLICA_HOST" -P "$REPLICA_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -se "SHOW REPLICA STATUS" 2>/dev/null | awk '{print "Lag:", $NF, "sec"}'
    done
fi

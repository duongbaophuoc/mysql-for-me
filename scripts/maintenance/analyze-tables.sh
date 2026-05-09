#!/bin/bash
# =============================================================================
# Table Analysis & Optimization Script
# Script Phân Tích & Tối Ưu Hóa Bảng
# =============================================================================

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
TARGET_DB="${1:-shop_db}"

MYSQL_CMD="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "=== Table Analysis for $TARGET_DB / Phân Tích Bảng cho $TARGET_DB ==="

# Update statistics for all tables / Cập nhật thống kê cho mọi bảng
log "Running ANALYZE TABLE on all tables / Chạy ANALYZE TABLE trên mọi bảng..."

TABLES=$($MYSQL_CMD -se "SHOW TABLES FROM $TARGET_DB")
for table in $TABLES; do
    log "Analyzing: $TARGET_DB.$table"
    $MYSQL_CMD -e "ANALYZE TABLE $TARGET_DB.$table;" | awk '{print "  " $0}'
done

log ""
log "=== Table Size Report / Báo Cáo Kích Thước Bảng ==="
$MYSQL_CMD -e "
SELECT
    TABLE_NAME                                    AS table_name,
    TABLE_ROWS                                    AS estimated_rows,
    ROUND(DATA_LENGTH/1024/1024, 2)              AS data_mb,
    ROUND(INDEX_LENGTH/1024/1024, 2)             AS index_mb,
    ROUND((DATA_LENGTH+INDEX_LENGTH)/1024/1024, 2) AS total_mb,
    ROUND(INDEX_LENGTH / DATA_LENGTH * 100, 1)   AS index_ratio_pct
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = '$TARGET_DB'
ORDER BY DATA_LENGTH + INDEX_LENGTH DESC;
"

log ""
log "=== Unused Indexes Detection / Phát Hiện Index Không Dùng ==="
$MYSQL_CMD -e "
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME          AS table_name,
    INDEX_NAME,
    COUNT_STAR           AS times_used
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = '$TARGET_DB'
  AND INDEX_NAME IS NOT NULL
  AND COUNT_STAR = 0
  AND INDEX_NAME != 'PRIMARY'
ORDER BY OBJECT_NAME, INDEX_NAME;
" 2>/dev/null || log "(Enable performance_schema for index usage stats)"

log "=== Analysis complete / Phân tích hoàn tất ==="

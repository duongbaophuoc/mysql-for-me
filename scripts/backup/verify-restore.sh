#!/bin/bash
# =============================================================================
# Restore Verification Script
# Script Xác Minh Khôi Phục
# =============================================================================
# Tests that a backup can actually be restored and data is consistent.
# Kiểm tra rằng backup thực sự có thể khôi phục và dữ liệu nhất quán.
# Run weekly in isolated environment / Chạy hàng tuần trong môi trường riêng biệt
# =============================================================================

set -euo pipefail

MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
BACKUP_FILE="${1:-}"
TEST_PORT="${TEST_PORT:-3399}"   # Isolated port for test / Cổng riêng cho test
PASS=0
FAIL=0

log()    { echo "[$(date '+%H:%M:%S')] $*"; }
pass()   { echo "[$(date '+%H:%M:%S')] ✅ PASS: $*"; (( PASS++ )); }
fail()   { echo "[$(date '+%H:%M:%S')] ❌ FAIL: $*"; (( FAIL++ )); }

if [[ -z "$BACKUP_FILE" ]]; then
    echo "Usage: $0 <backup_file_or_directory>"
    echo "Example: $0 /backups/full_20241215"
    exit 1
fi

log "=== Backup Restore Verification / Xác Minh Khôi Phục Backup ==="
log "Backup: $BACKUP_FILE"
log "Test port: $TEST_PORT"

# ─── Step 1: Start isolated MySQL instance for test
# Bước 1: Khởi động MySQL instance riêng biệt để test
TEST_DATADIR=/tmp/mysql_restore_test_$$
mkdir -p "$TEST_DATADIR"
log "Step 1: Starting test MySQL instance at port $TEST_PORT..."

if command -v docker &>/dev/null; then
    docker run -d \
        --name mysql_restore_test_$$ \
        -p "$TEST_PORT:3306" \
        -e MYSQL_ROOT_PASSWORD="$MYSQL_PASSWORD" \
        -v "$TEST_DATADIR:/var/lib/mysql" \
        mysql:8.0 \
        --gtid-mode=ON \
        --enforce-gtid-consistency=ON \
        > /dev/null 2>&1
    sleep 20
    TEST_MYSQL="mysql -h 127.0.0.1 -P $TEST_PORT -u root -p$MYSQL_PASSWORD"
    CLEANUP_CMD="docker rm -f mysql_restore_test_$$"
else
    log "⚠️  Docker not available — using local MySQL on port $TEST_PORT"
    TEST_MYSQL="mysql -h 127.0.0.1 -P $TEST_PORT -u root -p$MYSQL_PASSWORD"
    CLEANUP_CMD="true"
fi

# ─── Step 2: Restore backup / Bước 2: Khôi phục backup
log "Step 2: Restoring backup..."
if [[ -f "$BACKUP_FILE" && "$BACKUP_FILE" == *.sql* ]]; then
    # SQL dump restore / Khôi phục SQL dump
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        zcat "$BACKUP_FILE" | $TEST_MYSQL
    else
        $TEST_MYSQL < "$BACKUP_FILE"
    fi
    pass "SQL dump restored successfully"
elif [[ -d "$BACKUP_FILE" ]]; then
    log "Directory backup (XtraBackup) — manual restoration required"
    log "Run: xtrabackup --copy-back --target-dir=$BACKUP_FILE"
fi

# ─── Step 3: Verify critical data / Bước 3: Xác minh dữ liệu quan trọng
log "Step 3: Running data integrity checks..."

# Check databases exist / Kiểm tra CSDL tồn tại
if $TEST_MYSQL -se "SHOW DATABASES" | grep -q "shop_db"; then
    pass "shop_db database exists"
else
    fail "shop_db database NOT found"
fi

# Check tables / Kiểm tra bảng
TABLES=("orders" "customers" "products" "order_items" "payments")
for table in "${TABLES[@]}"; do
    COUNT=$($TEST_MYSQL -se "SELECT COUNT(*) FROM shop_db.$table" 2>/dev/null || echo 0)
    if (( COUNT > 0 )); then
        pass "Table shop_db.$table has $COUNT rows"
    else
        fail "Table shop_db.$table is EMPTY or missing"
    fi
done

# Check referential integrity / Kiểm tra tính toàn vẹn tham chiếu
ORPHAN_ITEMS=$($TEST_MYSQL -se "
    SELECT COUNT(*) FROM shop_db.order_items oi
    LEFT JOIN shop_db.orders o ON o.id = oi.order_id
    WHERE o.id IS NULL" 2>/dev/null || echo -1)
if (( ORPHAN_ITEMS == 0 )); then
    pass "No orphaned order_items found"
else
    fail "$ORPHAN_ITEMS orphaned order_items found — referential integrity broken!"
fi

# ─── Summary / Tóm Tắt ───────────────────────────────────────────────────────
eval "$CLEANUP_CMD" 2>/dev/null || true
rm -rf "$TEST_DATADIR"

echo ""
log "=== Verification Complete / Xác Minh Hoàn Tất ==="
log "PASS: $PASS | FAIL: $FAIL"
if (( FAIL > 0 )); then
    log "🚨 BACKUP VERIFICATION FAILED — Do NOT use this backup for production restore!"
    exit 1
else
    log "✅ Backup is verified and safe to use / Backup đã xác minh và an toàn để dùng"
fi

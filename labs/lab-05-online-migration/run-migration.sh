#!/bin/bash
# =============================================================================
# Lab 05: Online Schema Migration with gh-ost
# Lab 05: Di Chuyển Schema Không Gián Đoạn Với gh-ost
# =============================================================================
# Prerequisites / Điều kiện:
#   - MySQL running / MySQL đang chạy
#   - gh-ost installed / gh-ost đã cài đặt
#   - shop_db populated with seed data / shop_db có dữ liệu mẫu
# =============================================================================

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
DATABASE="${DATABASE:-shop_db}"
TABLE="${TABLE:-orders}"

MYSQL_CMD="mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[$(date '+%H:%M:%S')] ⚠️  $*"; }

log "=== Lab 05: Online Schema Migration / Di Chuyển Schema Không Gián Đoạn ==="

# ─── Step 1: Check current table structure / Kiểm tra cấu trúc bảng hiện tại ─────
log "Step 1: Current orders table structure / Cấu trúc bảng orders hiện tại:"
$MYSQL_CMD -e "DESCRIBE $DATABASE.$TABLE;"

# ─── Step 2: Check gh-ost is available / Kiểm tra gh-ost ────────────────────────
if ! command -v gh-ost &> /dev/null; then
    warn "gh-ost not found. Installing..."
    warn "Download from: https://github.com/github/gh-ost/releases"
    warn "Or run: docker pull github/gh-ost"
    echo ""
    echo "Alternative: use Docker / Dùng Docker:"
    echo "  docker run --rm --network=host github/gh-ost \\"
    echo "    --mysql-host=$MYSQL_HOST \\"
    echo "    --mysql-port=$MYSQL_PORT \\"
    echo "    --mysql-user=$MYSQL_USER \\"
    echo "    --mysql-password=$MYSQL_PASSWORD \\"
    echo "    --database=$DATABASE \\"
    echo "    --table=$TABLE \\"
    echo "    --alter='ADD COLUMN delivery_notes TEXT NULL AFTER status' \\"
    echo "    --allow-on-master \\"
    echo "    --execute"
    exit 0
fi

# ─── Step 3: Dry run first (no --execute flag) / Chạy thử trước (không có --execute) ─
log "Step 3: Dry-run gh-ost migration / Chạy thử di chuyển gh-ost..."
gh-ost \
    --mysql-host="$MYSQL_HOST" \
    --mysql-port="$MYSQL_PORT" \
    --mysql-user="$MYSQL_USER" \
    --mysql-password="$MYSQL_PASSWORD" \
    --database="$DATABASE" \
    --table="$TABLE" \
    --alter="ADD COLUMN delivery_notes TEXT NULL AFTER status,
             ADD COLUMN estimated_delivery_at DATETIME NULL,
             ADD INDEX idx_estimated_delivery (estimated_delivery_at)" \
    --allow-on-master \
    --initially-drop-old-table \
    --verbose
    # Note: no --execute → DRY RUN only / Không có --execute → CHỈ CHẠY THỬ

log "Dry run complete. Review output above."
log "To execute: add --execute flag to gh-ost command."
log "Chạy thử hoàn tất. Kiểm tra kết quả ở trên."
log "Để thực thi: thêm flag --execute vào lệnh gh-ost."

# ─── Step 4: Verify table after migration / Xác minh bảng sau di chuyển ─────────
log ""
log "Step 4: (After --execute) Verify new structure / Xác minh cấu trúc mới:"
log "  mysql -e 'DESCRIBE $DATABASE.$TABLE;'"

# ─── Alternative: MySQL 8.0 INSTANT DDL ────────────────────────────────────────
log ""
log "=== Alternative: MySQL 8.0 INSTANT DDL / Thay Thế: INSTANT DDL ==="
log "For simple column additions, INSTANT is better than gh-ost:"
log "Cho việc thêm cột đơn giản, INSTANT tốt hơn gh-ost:"
echo ""
log "Try this: / Thử lệnh này:"
$MYSQL_CMD -e "
    ALTER TABLE $DATABASE.$TABLE
        ADD COLUMN delivery_notes_instant TEXT NULL,
        ALGORITHM=INSTANT;
    DESCRIBE $DATABASE.$TABLE;" && \
log "✅ INSTANT DDL completed in milliseconds! / Hoàn tất trong milliseconds!"

# Cleanup the instant column / Dọn cột instant
$MYSQL_CMD -e "ALTER TABLE $DATABASE.$TABLE DROP COLUMN delivery_notes_instant;"
log "Cleanup done / Dọn dẹp hoàn tất"

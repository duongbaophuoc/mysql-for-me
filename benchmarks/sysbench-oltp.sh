#!/bin/bash
# =============================================================================
# MySQL sysbench OLTP Benchmarking / Đánh Giá Hiệu Năng MySQL với sysbench
# =============================================================================

set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_DB="${MYSQL_DB:-shop_db}"
THREADS="${THREADS:-16}"
DURATION="${DURATION:-60}"         # Seconds / Giây
TABLE_SIZE="${TABLE_SIZE:-100000}"
TABLES="${TABLES:-4}"

# Chuyển đổi cấu hình thành dạng Mảng (Array) để loại bỏ hoàn toàn lỗi SC2086
SYSBENCH_COMMON=(
    "--mysql-host=$MYSQL_HOST"
    "--mysql-port=$MYSQL_PORT"
    "--mysql-user=$MYSQL_USER"
    "--mysql-password=$MYSQL_PASSWORD"
    "--mysql-db=$MYSQL_DB"
    "--tables=$TABLES"
    "--table-size=$TABLE_SIZE"
    "--threads=$THREADS"
    "--time=$DURATION"
    "--report-interval=10"
)

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "=== MySQL sysbench Benchmark / Đánh Giá Hiệu Năng MySQL ==="
log "Host: $MYSQL_HOST:$MYSQL_PORT | Threads: $THREADS | Duration: ${DURATION}s"

# Check sysbench / Kiểm tra sysbench
if ! command -v sysbench &>/dev/null; then
    log "ERROR: sysbench not found. Install: apt-get install sysbench"
    exit 1
fi

# Step 1: Prepare test data / Bước 1: Chuẩn bị dữ liệu test
log "Preparing test tables / Chuẩn bị bảng test..."
sysbench /usr/share/sysbench/oltp_read_write.lua "${SYSBENCH_COMMON[@]}" prepare
log "✅ Tables prepared / Bảng đã chuẩn bị xong"

# Step 2: Run read/write benchmark / Bước 2: Chạy đánh giá đọc/ghi
log ""
log "=== Running OLTP Read/Write Benchmark / Chạy Đánh Giá Đọc/Ghi OLTP ==="
sysbench /usr/share/sysbench/oltp_read_write.lua "${SYSBENCH_COMMON[@]}" run | tee /tmp/bench_rw.txt

log ""
log "=== Running Read-Only Benchmark / Chạy Đánh Giá Chỉ Đọc ==="
sysbench /usr/share/sysbench/oltp_read_only.lua "${SYSBENCH_COMMON[@]}" run | tee /tmp/bench_ro.txt

log ""
log "=== Running Write-Only Benchmark / Chạy Đánh Giá Chỉ Ghi ==="
sysbench /usr/share/sysbench/oltp_write_only.lua "${SYSBENCH_COMMON[@]}" run | tee /tmp/bench_wo.txt

# Step 3: Extract key metrics / Bước 3: Trích xuất số liệu chính
log ""
log "================ RESULTS SUMMARY / TÓM TẮT KẾT QUẢ ================"
for bench in rw ro wo; do
    label=$(case $bench in rw) echo "Read/Write";; ro) echo "Read Only";; wo) echo "Write Only";; esac)
    tps=$(grep "transactions:" /tmp/bench_${bench}.txt | awk '{print $3}' | tr -d '(' || echo "0")
    qps=$(grep "queries:"      /tmp/bench_${bench}.txt | awk '{print $3}' | tr -d '(' || echo "0")
    p95=$(grep "95th percentile" /tmp/bench_${bench}.txt | awk '{print $NF}' || echo "0")
    log "$label: TPS=$tps | QPS=$qps | p95_latency=${p95}ms"
done

# Step 4: Cleanup / Bước 4: Dọn dẹp
log ""
log "Cleaning up test tables / Dọn bảng test..."
sysbench /usr/share/sysbench/oltp_read_write.lua "${SYSBENCH_COMMON[@]}" cleanup

log "=== Benchmark complete / Đánh giá hoàn tất ==="

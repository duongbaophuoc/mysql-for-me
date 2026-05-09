# Lab 02 — Replication Lag Analysis / Phân Tích Độ Trễ Sao Chép

## Objective / Mục Tiêu

Reproduce high replication lag, diagnose the root cause, and apply mitigation strategies.
_Tái tạo độ trễ replication cao, chẩn đoán nguyên nhân gốc và áp dụng chiến lược giảm thiểu._

**Duration / Thời lượng**: ~60 minutes  
**Prerequisites / Điều kiện**: Docker replication stack running

---

## Setup / Thiết Lập

```bash
# Start the replication stack (primary + 2 replicas)
# Khởi động stack replication (primary + 2 replica)
docker compose -f docker/docker-compose.replication.yml up -d

# Wait for all containers to be healthy / Chờ tất cả container healthy
docker ps | grep mysql

# Initialize replication on replica1 / Khởi tạo replication trên replica1
docker exec mysql-replica1 mysql -u root -psecret -e "
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='primary',
    SOURCE_PORT=3306,
    SOURCE_USER='replicator',
    SOURCE_PASSWORD='repl_secret',
    SOURCE_AUTO_POSITION=1;
START REPLICA;
"

# Verify replication is running / Xác minh replication đang chạy
docker exec mysql-replica1 mysql -u root -psecret -e "
SHOW REPLICA STATUS\G
" | grep -E "Running|Seconds_Behind|Last_Error"
```

---

## Step 1: Baseline Measurement / Đo Lường Cơ Sở

```sql
-- On replica / Trên replica
SHOW REPLICA STATUS\G
-- Note: Seconds_Behind_Source = 0 (caught up / đã cập nhật)

-- Monitor continuously / Giám sát liên tục
-- Run this in a loop every 2 seconds / Chạy vòng lặp mỗi 2 giây
SELECT
    NOW() AS ts,
    VARIABLE_VALUE AS lag_seconds
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Seconds_Behind_Master';
```

---

## Step 2: Simulate Heavy Write Load / Mô Phỏng Tải Ghi Nặng

```bash
# Generate write load on primary using sysbench
# Tạo tải ghi trên primary dùng sysbench
docker exec mysql-primary sysbench \
    /usr/share/sysbench/oltp_write_only.lua \
    --mysql-host=127.0.0.1 \
    --mysql-user=root \
    --mysql-password=secret \
    --mysql-db=shop_db \
    --tables=4 \
    --table-size=100000 \
    --threads=16 \
    --time=120 \
    prepare

docker exec mysql-primary sysbench \
    /usr/share/sysbench/oltp_write_only.lua \
    --mysql-host=127.0.0.1 \
    --mysql-user=root \
    --mysql-password=secret \
    --mysql-db=shop_db \
    --tables=4 \
    --table-size=100000 \
    --threads=16 \
    --time=120 \
    run
```

---

## Step 3: Observe and Diagnose Lag / Quan Sát và Chẩn Đoán Trễ

```sql
-- On replica, watch lag grow / Trên replica, theo dõi trễ tăng lên
SHOW REPLICA STATUS\G
-- Seconds_Behind_Source: 45... 60... 120...

-- Identify what the SQL thread is applying / Xác định SQL thread đang áp dụng
SELECT
    THREAD_ID,
    NAME,
    PROCESSLIST_STATE AS state,
    PROCESSLIST_INFO  AS current_query
FROM performance_schema.threads
WHERE name LIKE '%replica_sql%' OR name LIKE '%replica_worker%';

-- Check parallel worker utilization / Kiểm tra sử dụng worker song song
SELECT
    WORKER_ID,
    APPLYING_TRANSACTION,
    APPLYING_TRANSACTION_RETRIES_COUNT,
    LAST_APPLIED_TRANSACTION
FROM performance_schema.replication_applier_status_by_worker;
```

---

## Step 4: Mitigation — Enable Parallel Replication
_Giảm Thiểu — Bật Replication Song Song_

```sql
-- On replica / Trên replica
STOP REPLICA SQL_THREAD;

-- Increase parallel workers / Tăng số worker song song
SET GLOBAL replica_parallel_workers = 8;
SET GLOBAL replica_parallel_type = 'LOGICAL_CLOCK';
SET GLOBAL replica_preserve_commit_order = ON;

START REPLICA SQL_THREAD;

-- Watch lag decrease / Theo dõi trễ giảm
SHOW REPLICA STATUS\G
```

---

## Step 5: Further Investigation / Điều Tra Thêm

```sql
-- Check if a long transaction on primary is causing lag
-- Kiểm tra giao dịch dài trên primary gây trễ
SELECT
    trx_id,
    TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS running_seconds,
    trx_query,
    trx_rows_locked,
    trx_rows_modified
FROM information_schema.INNODB_TRX
WHERE TIMESTAMPDIFF(SECOND, trx_started, NOW()) > 10
ORDER BY trx_started ASC;

-- Check replica delay statistics / Kiểm tra thống kê trễ replica
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    COUNT_TRANSACTIONS_BEHIND_SOURCE,
    COUNT_TRANSACTIONS_IN_QUEUE,
    COUNT_TRANSACTIONS_DONE
FROM performance_schema.replication_applier_status;
```

---

## Expected Outcomes / Kết Quả Mong Đợi

- ✅ Replicated lag with 16-thread write load
- ✅ Diagnosed lag using Performance Schema
- ✅ Reduced lag by enabling parallel replication
- ✅ Understood the role of `LOGICAL_CLOCK` parallel type

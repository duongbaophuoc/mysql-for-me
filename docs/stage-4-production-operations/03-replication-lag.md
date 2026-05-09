# Replication Lag / Độ Trễ Sao Chép

## Overview / Tổng Quan

Replication lag is the delay between when a change is committed on the **primary** and when it's applied on the **replica**.
_Độ trễ sao chép là độ trễ giữa khi thay đổi được commit trên **primary** và khi nó được áp dụng trên **replica**._

---

## Causes of Lag / Nguyên Nhân Trễ

| Cause | Description | Fix |
|-------|-------------|-----|
| Single-threaded replication | Replica SQL thread applies serially | Enable parallel replication |
| Long-running transactions on primary | Holds replica back | Kill long transactions |
| Large transactions (bulk INSERT/UPDATE) | One huge binlog event | Batch in smaller chunks |
| Network bottleneck | Slow binlog shipping | Increase bandwidth |
| CPU-bound replica | Replica applying complex queries | Upgrade hardware |

---

## Measuring Lag / Đo Độ Trễ

```sql
-- Basic measurement / Đo cơ bản
SHOW REPLICA STATUS\G
-- Seconds_Behind_Source: 45   ← seconds of lag

-- More accurate: Heartbeat method / Chính xác hơn: Phương pháp Heartbeat
-- Debezium and gh-ost both maintain heartbeat tables
-- Debezium và gh-ost đều duy trì bảng heartbeat

-- GTID-based lag / Trễ dựa trên GTID
SELECT
    GTID_SUBTRACT(
        (SELECT @@GLOBAL.gtid_executed FROM primary_linked_server),
        @@GLOBAL.gtid_executed
    ) AS missing_gtids;
```

---

## Enabling Parallel Replication / Bật Sao Chép Song Song

```sql
-- On replica / Trên replica
STOP REPLICA SQL_THREAD;

-- Enable multi-threaded replication / Bật replication đa luồng
SET GLOBAL replica_parallel_workers = 8;
SET GLOBAL replica_parallel_type = 'LOGICAL_CLOCK';    -- best for most workloads
SET GLOBAL replica_preserve_commit_order = ON;          -- maintain order

-- LOGICAL_CLOCK: applies transactions committed at same time in parallel
-- Uses binlog timestamps for parallelism detection
-- Áp dụng song song các giao dịch commit cùng thời điểm

START REPLICA SQL_THREAD;
SHOW REPLICA STATUS\G
-- Seconds_Behind_Source should decrease
```

---

## Reducing Lag from Application / Giảm Trễ Từ Ứng Dụng

```sql
-- Break large transactions into smaller batches / Chia giao dịch lớn thành từng khối nhỏ
-- BAD / Tệ: (one huge transaction — one huge binlog event)
START TRANSACTION;
UPDATE orders SET status = 'archived' WHERE created_at < '2023-01-01';
-- 5 million rows! / 5 triệu hàng!
COMMIT;

-- GOOD / Tốt: (batch updates)
SET @done = 0;
REPEAT
    UPDATE orders SET status = 'archived'
    WHERE created_at < '2023-01-01'
      AND status != 'archived'
    LIMIT 1000;
    SET @done = (ROW_COUNT() = 0);
    DO SLEEP(0.05);   -- small pause between batches / tạm dừng nhỏ
UNTIL @done END REPEAT;
```

---

## Monitoring Replication Lag in Prometheus / Giám Sát Trong Prometheus

```yaml
# mysql-alerts.yml (already created)
- alert: MySQLReplicationLagWarning
  expr: mysql_slave_status_seconds_behind_master > 30
  for: 2m
  annotations:
    summary: "Replication lag > 30s on {{ $labels.instance }}"
```

---

## Handling Lag in Application / Xử Lý Trễ Trong Ứng Dụng

```python
# Option 1: Read from primary after writes / Đọc từ primary sau khi ghi
def confirm_order(order_id):
    write_db.execute("UPDATE orders SET status='confirmed' WHERE id=?", order_id)
    # Read from primary to ensure no stale data / Đọc từ primary để tránh dữ liệu cũ
    return primary_db.query("SELECT * FROM orders WHERE id=?", order_id)

# Option 2: Sticky session to primary / Phiên gắn với primary
# Route user to primary reads for 60s after any write
# Định tuyến người dùng đến primary trong 60s sau khi ghi

# Option 3: Accept eventual consistency / Chấp nhận nhất quán cuối cùng
# "Your changes are being saved..." (show optimistic result)
```

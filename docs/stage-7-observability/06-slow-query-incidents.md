# Slow Query Incident Response / Ứng Phó Sự Cố Truy Vấn Chậm

## Overview / Tổng Quan

A slow query incident means queries that normally complete in < 100ms are now taking 5–30+ seconds. This playbook walks through identification and resolution.
_Sự cố truy vấn chậm nghĩa là truy vấn bình thường hoàn thành trong < 100ms nay mất 5–30+ giây._

---

## Step 1: Identify the Slow Queries / Xác Định Truy Vấn Chậm

```sql
-- Real-time: what's running NOW? / Thời gian thực: đang chạy GÌ?
SHOW PROCESSLIST;
-- Or more detail: / Hoặc chi tiết hơn:
SELECT ID, USER, HOST, DB, COMMAND, TIME, STATE, LEFT(INFO, 200) AS query
FROM information_schema.PROCESSLIST
WHERE COMMAND != 'Sleep'
  AND TIME > 5
ORDER BY TIME DESC;

-- From Performance Schema (last hour) / Từ Performance Schema (giờ qua)
SELECT
    SCHEMA_NAME,
    DIGEST_TEXT,
    COUNT_STAR AS calls,
    ROUND(AVG_TIMER_WAIT / 1e9, 2) AS avg_ms,
    ROUND(MAX_TIMER_WAIT / 1e9, 2) AS max_ms
FROM performance_schema.events_statements_summary_by_digest
WHERE AVG_TIMER_WAIT > 1e9  -- > 1 second / > 1 giây
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 10;
```

---

## Step 2: EXPLAIN the Problem Query / Phân Tích Truy Vấn Có Vấn Đề

```sql
-- Run EXPLAIN ANALYZE on the slow query / Chạy EXPLAIN ANALYZE trên truy vấn chậm
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE customer_id = 5
  AND status = 'pending'
ORDER BY created_at DESC\G

-- Look for (in order of badness) / Tìm (theo thứ tự tệ nhất):
-- type: ALL          → full table scan → add index! / quét toàn bảng → thêm index!
-- Using filesort     → no index for ORDER BY / không có index cho ORDER BY
-- Using temporary    → GROUP BY without index / GROUP BY không có index
-- rows: large number → too many rows examined / quét quá nhiều hàng
```

---

## Step 3: Find Missing Indexes / Tìm Index Thiếu

```sql
-- Identify tables with full scans / Xác định bảng bị quét toàn bộ
SELECT OBJECT_SCHEMA, OBJECT_NAME, COUNT_FULL_SCANS
FROM performance_schema.table_io_waits_summary_by_table
WHERE COUNT_FULL_SCANS > 100
ORDER BY COUNT_FULL_SCANS DESC;

-- Check if query can use an index / Kiểm tra xem truy vấn có thể dùng index
SHOW INDEX FROM orders;
-- If no suitable index: add one!
```

---

## Step 4: Kill Blocking Queries / Kill Truy Vấn Chặn

```sql
-- Find queries running too long / Tìm truy vấn chạy quá lâu
SELECT ID, USER, TIME, LEFT(INFO, 100) AS query
FROM information_schema.PROCESSLIST
WHERE TIME > 30 AND COMMAND != 'Sleep';

-- Kill specific query / Kill truy vấn cụ thể
KILL QUERY 12345;    -- kills only the query, keeps connection / kill truy vấn, giữ kết nối
KILL 12345;          -- kills connection entirely / kill hoàn toàn kết nối
```

---

## Step 5: Apply Fix / Áp Dụng Sửa Lỗi

```sql
-- Add missing index (INPLACE for zero downtime) / Thêm index thiếu
ALTER TABLE orders
    ADD INDEX idx_customer_status_created (customer_id, status, created_at),
    ALGORITHM=INPLACE, LOCK=NONE;

-- Or: use INSTANT for adding purely metadata changes
-- Hoặc: dùng INSTANT cho thay đổi metadata thuần túy
ALTER TABLE orders ALGORITHM=INSTANT,
    ALTER COLUMN source SET DEFAULT 'web';
```

---

## Prevention / Phòng Ngừa

```sql
-- Set slow query log threshold to catch issues early
-- Đặt ngưỡng slow query log để phát hiện sớm
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;       -- log queries > 1s

-- Use query timeout to protect database from runaway queries
-- Dùng query timeout để bảo vệ CSDL khỏi truy vấn không kiểm soát
SET SESSION MAX_EXECUTION_TIME = 5000;  -- 5 second max
-- Or per-query: / Hoặc theo từng truy vấn:
SELECT /*+ MAX_EXECUTION_TIME(5000) */ * FROM orders;
```

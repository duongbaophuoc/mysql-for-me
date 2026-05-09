# Covering & Composite Indexes / Index Bao Phủ & Tổng Hợp

## Overview / Tổng Quan

Index design is one of the highest-leverage skills in MySQL performance engineering.
_Thiết kế index là một trong những kỹ năng tác động cao nhất trong kỹ thuật hiệu năng MySQL._

---

## The Leftmost Prefix Rule / Quy Tắc Tiền Tố Ngoài Cùng Bên Trái

A composite index on `(a, b, c)` can satisfy queries that filter on:
_Index tổng hợp trên `(a, b, c)` có thể thỏa mãn truy vấn lọc trên:_

```
(a)           ✅ uses index
(a, b)        ✅ uses index
(a, b, c)     ✅ uses index — full coverage
(b)           ❌ cannot use index — 'a' skipped
(b, c)        ❌ cannot use index
(a, c)        ✅ partial — uses 'a' prefix only
```

```sql
-- Index: (status, created_at, customer_id)
-- Index: (status, created_at, customer_id)
ALTER TABLE orders ADD INDEX idx_status_created_customer
    (status, created_at, customer_id);

-- ✅ Uses full index / Dùng full index
EXPLAIN SELECT id, customer_id FROM orders
WHERE status = 'pending'
  AND created_at > '2024-01-01'
  AND customer_id = 5;

-- ✅ Uses prefix (status only) / Dùng tiền tố status
EXPLAIN SELECT id FROM orders WHERE status = 'pending';

-- ❌ Cannot use index (skips status) / Không thể dùng index
EXPLAIN SELECT id FROM orders WHERE created_at > '2024-01-01';
```

---

## Covering Index / Index Bao Phủ

A covering index contains ALL columns needed by a query — no table access required.
_Index bao phủ chứa TẤT CẢ cột cần thiết — không cần truy cập bảng._

```sql
-- Query: List pending orders for a customer
-- Truy vấn: Liệt kê đơn hàng chờ của khách hàng
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 5
  AND status = 'pending'
ORDER BY created_at DESC;
```

```sql
-- Without covering index / Không có covering index:
-- MySQL reads index, then fetches each row from table (random IO)
-- MySQL đọc index, sau đó lấy mỗi hàng từ bảng (IO ngẫu nhiên)

-- With covering index / Với covering index:
ALTER TABLE orders ADD INDEX idx_cover_customer_orders
    (customer_id, status, created_at DESC, id, total_amount);
--   ↑ WHERE        ↑ WHERE   ↑ ORDER BY   ↑ SELECT ↑ SELECT

EXPLAIN SELECT id, status, total_amount, created_at FROM orders
WHERE customer_id = 5 AND status = 'pending'
ORDER BY created_at DESC\G
-- Extra: Using index   ← covering index in effect!
```

---

## Index for ORDER BY / Index Cho ORDER BY

```sql
-- Problem: filesort / Vấn đề: sorting in memory
EXPLAIN SELECT * FROM orders
WHERE status = 'delivered'
ORDER BY created_at DESC
LIMIT 20\G
-- Extra: Using filesort  ← bad!

-- Fix: include ORDER BY column in index
-- Sửa: đưa cột ORDER BY vào index
ALTER TABLE orders ADD INDEX idx_status_created_desc
    (status, created_at DESC);

-- Now no filesort / Không có filesort
EXPLAIN SELECT id, total_amount FROM orders
WHERE status = 'delivered'
ORDER BY created_at DESC
LIMIT 20\G
-- Extra: Using index condition  ← good!
```

---

## Index Design for shop_db / Thiết Kế Index Cho shop_db

```sql
-- High-impact indexes for common query patterns
-- Index tác động cao cho các mẫu truy vấn phổ biến

-- 1. Customer's active orders (most common)
-- Đơn hàng active của khách hàng (phổ biến nhất)
ALTER TABLE orders ADD INDEX idx_customer_active_orders
    (customer_id, status, created_at DESC);

-- 2. Recent pending orders for processing
-- Đơn hàng chờ gần đây để xử lý
ALTER TABLE orders ADD INDEX idx_pending_orders
    (status, created_at) 
    COMMENT 'For order processing queue / Hàng đợi xử lý đơn hàng';

-- 3. Payment lookup by order
-- Tra cứu thanh toán theo đơn hàng
ALTER TABLE payments ADD INDEX idx_order_payment_status
    (order_id, status);

-- 4. Active customers by email
-- Khách hàng active theo email
ALTER TABLE customers ADD INDEX idx_active_customer_email
    (deleted_at, email, full_name);
-- NULL first in deleted_at means active comes first
```

---

## Monitoring Index Usage / Theo Dõi Sử Dụng Index

```sql
-- Find unused indexes / Tìm index không dùng
SELECT
    OBJECT_NAME AS table_name,
    INDEX_NAME,
    COUNT_STAR AS usage_count
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = 'shop_db'
  AND INDEX_NAME != 'PRIMARY'
  AND INDEX_NAME IS NOT NULL
  AND COUNT_STAR = 0
ORDER BY OBJECT_NAME;

-- Find indexes with highest read benefit
-- Tìm index mang lại lợi ích đọc cao nhất
SELECT
    OBJECT_NAME,
    INDEX_NAME,
    COUNT_FETCH AS reads_served
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = 'shop_db'
ORDER BY COUNT_FETCH DESC
LIMIT 10;
```

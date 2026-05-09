# Lab 04 — Query Optimization / Tối Ưu Truy Vấn

## Objective / Mục Tiêu

Identify slow queries, analyze execution plans with EXPLAIN ANALYZE, and apply index optimizations.
_Xác định truy vấn chậm, phân tích kế hoạch thực thi với EXPLAIN ANALYZE và áp dụng tối ưu index._

**Duration / Thời lượng**: ~60 minutes

---

## Setup / Thiết Lập

```bash
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/shop_db/schema.sql
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/shop_db/seed.sql
mysql -h 127.0.0.1 -P 3306 -u root -psecret shop_db \
  < labs/lab-04-query-optimization/slow-queries.sql
```

---

## Exercise 1: Full Table Scan / Quét Toàn Bảng

```sql
-- This query is slow with 1M rows / Truy vấn này chậm với 1M hàng
SELECT *
FROM orders
WHERE YEAR(created_at) = 2024
  AND MONTH(created_at) = 12;
```

**Task / Nhiệm vụ**: 
1. Run `EXPLAIN ANALYZE` and identify the problem
2. Rewrite to use a range condition that allows index usage
3. Verify improvement with `EXPLAIN ANALYZE`

**Expected fix / Sửa mong đợi**:
```sql
SELECT *
FROM orders
WHERE created_at >= '2024-12-01'
  AND created_at <  '2025-01-01';
```

---

## Exercise 2: Missing Index on JOIN / Thiếu Index Trên JOIN

```sql
-- This generates a full scan on order_items / Sinh quét toàn bảng order_items
SELECT
    p.name,
    SUM(oi.quantity) AS total_sold,
    SUM(oi.line_total) AS total_revenue
FROM order_items oi
JOIN products p ON p.id = oi.product_id
GROUP BY p.id, p.name
ORDER BY total_revenue DESC
LIMIT 10;
```

**Task / Nhiệm vụ**:
1. Run `EXPLAIN ANALYZE` — which access type is used?
2. What index would help? Add it and re-run.

---

## Exercise 3: SELECT * Anti-Pattern / Chống Mẫu SELECT *

```sql
-- Fetches 50 columns when we need 3 / Lấy 50 cột khi chỉ cần 3
SELECT * FROM customers
WHERE status = 'active'
  AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 20;
```

**Task / Nhiệm vụ**:
1. Identify which columns are actually needed
2. Rewrite with specific column selection
3. Create a covering index for the query

**Covering index solution / Giải pháp index bao phủ**:
```sql
ALTER TABLE customers
    ADD INDEX idx_cover_active_customers
    (status, deleted_at, created_at DESC, id, email, full_name);
```

---

## Exercise 4: Inefficient Pagination / Phân Trang Không Hiệu Quả

```sql
-- OFFSET pagination is slow on page 5000
-- Phân trang OFFSET chậm ở trang 5000
SELECT id, uuid, status, total_amount, created_at
FROM orders
ORDER BY created_at DESC
LIMIT 20 OFFSET 100000;   -- Must scan 100,020 rows! / Phải quét 100,020 hàng!
```

**Task / Nhiệm vụ**: Convert to keyset pagination.

**Solution / Giải pháp**:
```sql
-- Fix: keyset cursor pagination / Phân trang con trỏ
SELECT id, uuid, status, total_amount, created_at
FROM orders
WHERE created_at < :last_seen_created_at
   OR (created_at = :last_seen_created_at AND id < :last_seen_id)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

---

## Verification Checklist / Danh Sách Kiểm Tra

```sql
-- After optimizations, check all queries use indexes
-- Sau tối ưu, xác nhận mọi truy vấn dùng index
-- Every EXPLAIN should NOT show: type=ALL

-- Check index usage stats / Kiểm tra thống kê sử dụng index
SELECT
    INDEX_NAME,
    COUNT_FETCH,
    COUNT_INSERT,
    COUNT_UPDATE,
    COUNT_DELETE
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = 'shop_db'
  AND OBJECT_NAME = 'orders'
ORDER BY COUNT_FETCH DESC;
```

# EXPLAIN ANALYZE / Phân Tích EXPLAIN

## Overview / Tổng Quan

`EXPLAIN` shows **how** MySQL plans to execute a query. `EXPLAIN ANALYZE` actually runs it and shows **real timing**.
_`EXPLAIN` hiển thị **cách** MySQL lên kế hoạch thực thi truy vấn. `EXPLAIN ANALYZE` thực sự chạy nó và hiển thị **thời gian thực**._

This is the most important diagnostic tool for query optimization.
_Đây là công cụ chẩn đoán quan trọng nhất để tối ưu truy vấn._

---

## Basic EXPLAIN / EXPLAIN Cơ Bản

```sql
EXPLAIN
SELECT o.id, c.email, o.total_amount
FROM orders o
INNER JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'pending'
ORDER BY o.created_at DESC
LIMIT 10;
```

### Key Columns / Cột Quan Trọng

| Column | Meaning / Ý Nghĩa |
|--------|------------------|
| `type` | Join type — quality indicator |
| `key` | Index used / Chỉ mục được dùng |
| `rows` | Estimated rows examined / Hàng ước tính được duyệt |
| `Extra` | Additional info (Using index, Using filesort) |
| `filtered` | % rows remaining after WHERE |

---

## Access Type Hierarchy / Phân Cấp Kiểu Truy Cập

From best to worst / Từ tốt nhất đến tệ nhất:

```
system   → Single row (system table) / Hàng đơn
const    → Single row via PK or unique / Hàng đơn qua PK hoặc unique
eq_ref   → One row per JOIN via unique index / Một hàng mỗi JOIN qua unique index
ref      → Multiple rows via non-unique index / Nhiều hàng qua index không unique
range    → Index scan for range condition / Quét index cho điều kiện phạm vi
index    → Full index scan / Quét index đầy đủ
ALL      → Full table scan → PROBLEM! / Quét toàn bảng → VẤN ĐỀ!
```

```sql
-- See type column / Xem cột type
EXPLAIN SELECT * FROM orders WHERE id = 100\G
-- type: const  ← perfect, PK lookup / hoàn hảo, tra cứu PK

EXPLAIN SELECT * FROM orders WHERE status = 'pending'\G
-- type: ref    ← good, uses idx_orders_status / tốt, dùng index

EXPLAIN SELECT * FROM orders WHERE YEAR(created_at) = 2024\G
-- type: ALL    ← bad! function prevents index use / tệ! hàm ngăn dùng index
```

---

## EXPLAIN ANALYZE — Real Execution Timing
## EXPLAIN ANALYZE — Thời Gian Thực Thi Thực Tế

```sql
EXPLAIN ANALYZE
SELECT o.id, c.email, o.total_amount
FROM orders o
INNER JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'pending'
ORDER BY o.created_at DESC
LIMIT 10;
```

### Reading the Output / Đọc Kết Quả

```
-> Limit: 10 row(s)  (actual time=2.31..2.32 rows=10 loops=1)
    -> Sort: o.created_at DESC  (actual time=2.30..2.31 rows=10 loops=1)
        -> Nested loop inner join  (actual time=0.18..2.27 rows=47 loops=1)
            -> Filter: (o.status = 'pending')  (actual time=0.12..1.89 rows=47 loops=1)
                -> Index scan on o using idx_orders_status  ← uses index / dùng index
                   (actual time=0.08..1.71 rows=47 loops=1)
            -> Single-row index lookup on c using PRIMARY (id=o.customer_id)
               (actual time=0.007..0.008 rows=1 loops=47)  ← eq_ref on PK / eq_ref trên PK

Format: actual time=first_row_ms..last_row_ms rows=actual_rows loops=iterations
```

---

## Common Problems and Fixes / Vấn Đề Phổ Biến và Cách Sửa

### Problem 1: Full Table Scan / Quét Toàn Bảng

```sql
-- BEFORE / TRƯỚC:
EXPLAIN SELECT * FROM orders WHERE YEAR(created_at) = 2024\G
-- type: ALL, rows: 500000 ← scanning 500K rows!

-- FIX: Avoid functions on indexed columns / Tránh hàm trên cột đã index
-- AFTER / SAU:
EXPLAIN SELECT * FROM orders
WHERE created_at >= '2024-01-01'
  AND created_at <  '2025-01-01'\G
-- type: range, rows: 85000 ← much better! / tốt hơn nhiều!
```

### Problem 2: Filesort / Sắp Xếp File

```sql
-- Extra: "Using filesort" means MySQL sorts in memory or disk
-- Extra: "Using filesort" nghĩa MySQL sắp xếp trong memory hoặc đĩa

-- FIX: Create index that supports ORDER BY
-- Tạo index hỗ trợ ORDER BY
ALTER TABLE orders ADD INDEX idx_status_created (status, created_at DESC);

EXPLAIN SELECT * FROM orders
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 10\G
-- Extra: Using index condition ← no more filesort / không còn filesort
```

### Problem 3: Using temporary / Dùng Bảng Tạm

```sql
-- Extra: "Using temporary" often with GROUP BY without proper index
-- Extra: "Using temporary" thường với GROUP BY không có index phù hợp

EXPLAIN
SELECT status, COUNT(*) FROM orders GROUP BY status\G
-- If "Using temporary; Using filesort" → add index on status
-- Nếu "Using temporary; Using filesort" → thêm index vào status
```

---

## Covering Index Check / Kiểm Tra Index Bao Phủ

```sql
-- "Using index" in Extra means covering index (no table access)
-- "Using index" trong Extra nghĩa index bao phủ (không truy cập bảng)

EXPLAIN SELECT id, status, created_at FROM orders
WHERE status = 'delivered'
  AND customer_id = 5\G
-- Extra: Using index ← all data from index, very fast!
-- Extra: Using index ← mọi dữ liệu từ index, rất nhanh!
```

---

## Quick Reference / Tham Chiếu Nhanh

| Extra value | Meaning | Action |
|-------------|---------|--------|
| `Using index` | Covering index ✅ | — |
| `Using where` | Filter after index | Check selectivity |
| `Using filesort` | In-memory sort | Add index with ORDER BY |
| `Using temporary` | Temp table for GROUP BY | Add composite index |
| `Using index condition` | ICP pushdown ✅ | — |
| (empty) | Table lookup | Check if index needed |

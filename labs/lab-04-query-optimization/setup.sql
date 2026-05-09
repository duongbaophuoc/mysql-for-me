-- =============================================================================
-- Lab 04: Query Optimization — Setup & Exercises
-- Lab 04: Tối Ưu Hóa Truy Vấn — Thiết Lập & Bài Tập
-- =============================================================================

USE shop_db;

-- =============================================================================
-- EXERCISE 1: Identify full table scans / Xác định quét toàn bảng
-- =============================================================================

-- Reset statistics / Đặt lại thống kê
FLUSH STATUS;

-- BAD query — forces full table scan / Truy vấn TỆ — buộc quét toàn bảng
EXPLAIN ANALYZE
SELECT id, customer_id, total_amount
FROM orders
WHERE YEAR(created_at) = 2024       -- function on indexed column = no index use!
  AND status = 'pending';           -- hàm trên cột đã index = không dùng index!

-- GOOD query — uses index range scan / Truy vấn TỐT — dùng index range scan
EXPLAIN ANALYZE
SELECT id, customer_id, total_amount
FROM orders
WHERE created_at >= '2024-01-01'
  AND created_at <  '2025-01-01'
  AND status = 'pending';

-- =============================================================================
-- EXERCISE 2: Missing index detection / Phát hiện index thiếu
-- =============================================================================

-- Check indexes on orders / Kiểm tra index trên orders
SHOW INDEX FROM orders;

-- Query without a proper index / Truy vấn không có index phù hợp
EXPLAIN
SELECT id, total_amount, created_at
FROM orders
WHERE customer_id = 5
  AND status = 'delivered'
ORDER BY created_at DESC
LIMIT 10;
-- Look for: type=ALL or type=ref without covering index
-- Tìm: type=ALL hoặc type=ref không có covering index

-- Add optimal covering index / Thêm covering index tối ưu
ALTER TABLE orders
    ADD INDEX idx_lab04_customer_status_created
        (customer_id, status, created_at DESC, id, total_amount),
    ALGORITHM=INPLACE, LOCK=NONE;

-- Re-run with new index / Chạy lại với index mới
EXPLAIN
SELECT id, total_amount, created_at
FROM orders
WHERE customer_id = 5
  AND status = 'delivered'
ORDER BY created_at DESC
LIMIT 10;
-- Now: Using index, no filesort! / Bây giờ: Dùng index, không filesort!

-- =============================================================================
-- EXERCISE 3: N+1 Query Pattern Detection
-- =============================================================================

-- Simulate N+1: get 10 orders, then 10 separate customer lookups
-- Mô phỏng N+1: lấy 10 đơn hàng, sau đó 10 tra cứu khách hàng riêng

-- N+1 BAD: (do this in application — shown here for illustration)
-- N+1 TỆ: (thực hiện trong ứng dụng — hiển thị ở đây để minh họa)
SELECT id, customer_id FROM orders WHERE status = 'pending' LIMIT 10;
-- Then for each row: / Sau đó cho mỗi hàng:
SELECT full_name, email FROM customers WHERE id = 1;
SELECT full_name, email FROM customers WHERE id = 2;
-- ... 10 queries total! / 10 truy vấn tổng cộng!

-- OPTIMAL: JOIN resolves in 1 query / JOIN giải quyết trong 1 truy vấn
EXPLAIN ANALYZE
SELECT o.id, o.total_amount, c.full_name, c.email
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'pending'
ORDER BY o.created_at DESC
LIMIT 10;

-- =============================================================================
-- EXERCISE 4: Sort optimization — eliminate filesort
-- Tối ưu sắp xếp — loại bỏ filesort
-- =============================================================================

EXPLAIN
SELECT id, total_amount
FROM orders
WHERE status = 'pending'
ORDER BY total_amount DESC    -- no index for this sort / không có index cho sắp xếp này
LIMIT 20;
-- Extra: Using filesort  ← problem! / vấn đề!

-- Add index that covers both filter AND sort / Thêm index bao gồm cả lọc VÀ sắp xếp
ALTER TABLE orders
    ADD INDEX idx_lab04_status_total (status, total_amount DESC),
    ALGORITHM=INPLACE, LOCK=NONE;

EXPLAIN
SELECT id, total_amount
FROM orders
WHERE status = 'pending'
ORDER BY total_amount DESC
LIMIT 20;
-- Extra: Using index  ← filesort eliminated! / filesort đã loại bỏ!

-- =============================================================================
-- CLEANUP / DỌN DẸP
-- =============================================================================
-- ALTER TABLE orders DROP INDEX idx_lab04_customer_status_created;
-- ALTER TABLE orders DROP INDEX idx_lab04_status_total;

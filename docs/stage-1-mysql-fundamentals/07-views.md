# Views / Khung Nhìn

## Overview / Tổng Quan

A **View** is a stored SQL query that acts like a virtual table.
_**View** là truy vấn SQL được lưu trữ hoạt động như một bảng ảo._

---

## Creating Views / Tạo View

```sql
-- View: active customers with address / View: khách hàng active với địa chỉ
CREATE VIEW v_active_customers AS
SELECT
    c.id,
    c.uuid,
    c.email,
    c.full_name,
    c.status,
    a.city,
    a.country,
    c.created_at
FROM customers c
LEFT JOIN customer_addresses a
    ON a.customer_id = c.id AND a.is_default = 1
WHERE c.deleted_at IS NULL;

-- Usage / Sử dụng (works like a table)
SELECT * FROM v_active_customers WHERE city = 'Hà Nội';
```

```sql
-- View: order summary with customer / View: tóm tắt đơn hàng với khách hàng
CREATE VIEW v_order_summary AS
SELECT
    o.id                AS order_id,
    o.uuid              AS order_uuid,
    o.status,
    o.total_amount,
    o.created_at,
    c.email             AS customer_email,
    c.full_name         AS customer_name,
    COUNT(oi.id)        AS item_count,
    p.status            AS payment_status,
    p.method            AS payment_method
FROM orders o
JOIN customers   c  ON c.id = o.customer_id
JOIN order_items oi ON oi.order_id = o.id
LEFT JOIN payments p ON p.order_id = o.id
GROUP BY o.id, o.uuid, o.status, o.total_amount, o.created_at,
         c.email, c.full_name, p.status, p.method;
```

---

## Use Cases / Trường Hợp Sử Dụng

| Use Case | Example |
|----------|---------|
| Security — hide sensitive columns | View without password_hash, credit_card |
| Simplification | Hide complex JOINs from app code |
| API layer | Expose v_order_summary to REST API |
| Legacy compatibility | Rename columns without changing app |

---

## Updatable Views / View Có Thể Cập Nhật

Simple views (no GROUP BY, DISTINCT, JOINs) can be updated:
_View đơn giản (không có GROUP BY, DISTINCT, JOIN) có thể được cập nhật:_

```sql
CREATE VIEW v_simple_customers AS
SELECT id, email, full_name, status FROM customers WHERE deleted_at IS NULL;

-- Can UPDATE through the view / Có thể UPDATE qua view
UPDATE v_simple_customers SET status = 'inactive' WHERE id = 5;
-- Equivalent: UPDATE customers SET status='inactive' WHERE id=5 AND deleted_at IS NULL

-- WITH CHECK OPTION: prevent updates that hide the row from the view
-- WITH CHECK OPTION: ngăn update tạo ra hàng không hiển thị trong view
CREATE VIEW v_active_only AS
    SELECT id, email, status FROM customers WHERE status = 'active'
    WITH CHECK OPTION;
```

---

## Performance Considerations / Cân Nhắc Hiệu Năng

```sql
-- Views are not cached — query executes each time
-- View không được cache — truy vấn thực thi mỗi lần

-- Check if view uses an index / Kiểm tra view có dùng index
EXPLAIN SELECT * FROM v_active_customers WHERE city = 'Hà Nội'\G

-- Materialized View workaround: use a physical table + scheduled refresh
-- Giải pháp view vật thể hóa: dùng bảng vật lý + làm mới theo lịch
CREATE TABLE mv_order_summary AS SELECT * FROM v_order_summary;
ALTER TABLE mv_order_summary ADD PRIMARY KEY (order_id);
-- Refresh nightly / Làm mới hàng đêm
TRUNCATE mv_order_summary;
INSERT INTO mv_order_summary SELECT * FROM v_order_summary;
```

---

## Managing Views / Quản Lý View

```sql
-- List all views / Liệt kê tất cả view
SELECT TABLE_NAME AS view_name, VIEW_DEFINITION
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'shop_db';

-- Update a view / Cập nhật view
CREATE OR REPLACE VIEW v_active_customers AS ...;

-- Drop a view / Xóa view
DROP VIEW IF EXISTS v_active_customers;
```

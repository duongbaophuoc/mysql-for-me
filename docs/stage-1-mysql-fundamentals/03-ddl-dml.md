# DDL & DML — SQL Fundamentals / Nền Tảng SQL

## Overview / Tổng Quan

- **DDL** (Data Definition Language): Defines structure — `CREATE`, `ALTER`, `DROP`
- **DML** (Data Manipulation Language): Manages data — `INSERT`, `SELECT`, `UPDATE`, `DELETE`

---

## DDL — CREATE TABLE

```sql
-- Production-quality table creation / Tạo bảng chất lượng production
CREATE TABLE products (
    id          BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    sku         VARCHAR(100)     NOT NULL,
    name        VARCHAR(500)     NOT NULL,
    price       DECIMAL(12,2)    NOT NULL,
    status      ENUM('active','inactive','archived') NOT NULL DEFAULT 'active',
    attributes  JSON             NULL,
    created_at  DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at  DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
                ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uq_products_sku (sku),
    KEY idx_products_status   (status)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Product catalog / Danh mục sản phẩm';
```

## DDL — ALTER TABLE

```sql
-- Add column / Thêm cột (INSTANT in MySQL 8.0 for most operations)
ALTER TABLE products
    ADD COLUMN weight_kg DECIMAL(8,3) NULL AFTER price,
    ALGORITHM=INSTANT;

-- Add index / Thêm chỉ mục (INPLACE, no table copy)
ALTER TABLE products
    ADD INDEX idx_products_name (name),
    ALGORITHM=INPLACE, LOCK=NONE;

-- Rename column / Đổi tên cột
ALTER TABLE products RENAME COLUMN attributes TO metadata;

-- Change column type / Đổi kiểu cột (requires table rebuild!)
-- Thay đổi kiểu cột (cần rebuild bảng!)
ALTER TABLE products MODIFY COLUMN weight_kg FLOAT;
```

## DDL — DROP

```sql
-- Safe drop with IF EXISTS / Xóa an toàn với IF EXISTS
DROP TABLE IF EXISTS temp_migration_table;

-- Rename before drop (safer) / Đổi tên trước khi xóa (an toàn hơn)
RENAME TABLE products TO _products_backup_20241215;
-- Wait 24h, then: / Chờ 24 giờ, sau đó:
DROP TABLE _products_backup_20241215;
```

---

## DML — INSERT

```sql
-- Single row / Hàng đơn
INSERT INTO customers (uuid, email, full_name) VALUES (UUID(), 'a@b.com', 'Test User');

-- Multiple rows (batch insert) / Nhiều hàng (chèn hàng loạt)
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (1, 10, 2, 29990000),
    (1, 11, 1, 13990000),
    (1, 12, 3,  1290000);

-- INSERT ... ON DUPLICATE KEY UPDATE (upsert)
INSERT INTO inventory (product_id, warehouse_code, quantity_available)
VALUES (5, 'WH-HN-01', 100)
ON DUPLICATE KEY UPDATE
    quantity_available = quantity_available + VALUES(quantity_available);

-- INSERT ... SELECT (copy data)
INSERT INTO order_archive SELECT * FROM orders WHERE created_at < '2023-01-01';
```

## DML — UPDATE

```sql
-- Safe update: always include WHERE with PK / Luôn có mệnh đề WHERE với PK
UPDATE orders
SET status = 'confirmed',
    updated_at = CURRENT_TIMESTAMP(3)
WHERE id = 12345;

-- Update multiple rows / Cập nhật nhiều hàng
UPDATE inventory
SET quantity_available = quantity_available - 1
WHERE product_id = 5
  AND warehouse_code = 'WH-HN-01'
  AND quantity_available > 0;   -- optimistic locking / khóa lạc quan
```

## DML — DELETE

```sql
-- Hard delete (use sparingly) / Xóa cứng (dùng thận trọng)
DELETE FROM order_items WHERE order_id = 999;

-- Soft delete (preferred) / Xóa mềm (ưu tiên)
UPDATE customers
SET deleted_at = CURRENT_TIMESTAMP(3)
WHERE id = 42;

-- Batch delete (avoid locking too many rows) / Xóa hàng loạt (tránh lock quá nhiều)
DELETE FROM audit_log
WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY)
LIMIT 10000;   -- delete in chunks / xóa theo từng khối
```

## DML — SELECT Best Practices

```sql
-- Specify columns (not SELECT *) / Chỉ định cột (không SELECT *)
SELECT id, email, full_name, status
FROM customers
WHERE status = 'active'
  AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 20;

-- Avoid functions on indexed columns / Tránh hàm trên cột đã index
-- BAD / Tệ:
SELECT * FROM orders WHERE YEAR(created_at) = 2024;    -- full scan!

-- GOOD / Tốt:
SELECT * FROM orders
WHERE created_at >= '2024-01-01'
  AND created_at <  '2025-01-01';                      -- uses index!
```

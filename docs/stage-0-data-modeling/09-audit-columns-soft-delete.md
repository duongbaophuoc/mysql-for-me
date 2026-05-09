# Audit Columns & Soft Delete Patterns
# Cột Kiểm Toán & Mẫu Xóa Mềm

## Overview / Tổng Quan

Every production database needs a strategy for tracking **when data changed** and **how to "delete" data without losing it**.
_Mọi CSDL production cần chiến lược theo dõi **khi nào dữ liệu thay đổi** và **cách "xóa" dữ liệu mà không mất nó**._

---

## Standard Audit Columns / Cột Kiểm Toán Chuẩn

Add these to every important table:
_Thêm những cột này vào mọi bảng quan trọng:_

```sql
CREATE TABLE orders (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    -- ... other columns ...
    
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
                ON UPDATE CURRENT_TIMESTAMP(3),
    deleted_at DATETIME(3) NULL,              -- NULL = not deleted / NULL = chưa xóa
    created_by BIGINT UNSIGNED NULL,          -- FK to users table
    updated_by BIGINT UNSIGNED NULL,
    
    PRIMARY KEY (id),
    KEY idx_orders_deleted_at (deleted_at),   -- Filter active records / Lọc bản ghi active
    KEY idx_orders_created_at (created_at)    -- Time-range queries / Truy vấn theo thời gian
) ENGINE=InnoDB;
```

### Why DATETIME(3)? / Tại sao DATETIME(3)?

```sql
-- DATETIME(3) stores millisecond precision / DATETIME(3) lưu độ chính xác millisecond
-- This matters for event ordering in distributed systems
-- Quan trọng để sắp xếp sự kiện trong hệ thống phân tán

INSERT INTO orders (created_at) VALUES (CURRENT_TIMESTAMP(3));
-- Result / Kết quả: '2024-12-15 09:23:45.123'
```

---

## Soft Delete Pattern / Mẫu Xóa Mềm

### Why Soft Delete? / Tại Sao Xóa Mềm?

- **Compliance**: GDPR, SOX, financial regulations require audit trails / Luật GDPR, SOX yêu cầu lịch sử kiểm toán
- **Recovery**: Accidental deletes can be reversed / Xóa nhầm có thể khôi phục
- **Foreign keys**: Hard deletes break referential integrity chains / Xóa cứng phá vỡ chuỗi toàn vẹn tham chiếu
- **Analytics**: Historical data needed for reports / Dữ liệu lịch sử cần cho báo cáo

### Implementation / Triển Khai

```sql
-- Soft delete: set deleted_at instead of DELETE / Xóa mềm: đặt deleted_at thay vì DELETE
UPDATE customers
SET deleted_at = CURRENT_TIMESTAMP(3),
    updated_by = :current_user_id
WHERE id = :customer_id
  AND deleted_at IS NULL;    -- Idempotent / Mãn đẳng tính

-- Hard delete equivalent / Tương đương xóa cứng:
-- DELETE FROM customers WHERE id = :customer_id;  ← DON'T do this in production!
```

### Querying with Soft Deletes / Truy Vấn Với Xóa Mềm

```sql
-- Active records only / Chỉ bản ghi active
SELECT * FROM customers
WHERE deleted_at IS NULL;

-- Include deleted records / Bao gồm bản ghi đã xóa
SELECT *,
       CASE WHEN deleted_at IS NOT NULL
            THEN 'deleted' ELSE 'active' END AS record_status
FROM customers;

-- Restore a soft-deleted record / Khôi phục bản ghi xóa mềm
UPDATE customers
SET deleted_at = NULL
WHERE id = :customer_id;
```

### Index Strategy for Soft Deletes / Chiến Lược Chỉ Mục

```sql
-- Partial index trick: null sentinel in composite index
-- Thủ thuật chỉ mục: sentinel null trong chỉ mục tổng hợp

-- Useful for queries like "active customers by email"
-- Hữu ích cho truy vấn như "khách hàng active theo email"
ALTER TABLE customers
    ADD KEY idx_active_email (email, deleted_at);

-- This query will use the composite index efficiently:
-- Truy vấn này sẽ dùng chỉ mục tổng hợp hiệu quả:
SELECT id, email, full_name
FROM customers
WHERE email = 'user@example.com'
  AND deleted_at IS NULL;
```

---

## Full Audit Log Pattern / Mẫu Nhật Ký Kiểm Toán Đầy Đủ

For compliance-heavy applications:
_Cho ứng dụng nặng về tuân thủ:_

```sql
CREATE TABLE audit_log (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    table_name  VARCHAR(100)    NOT NULL,
    record_id   BIGINT UNSIGNED NOT NULL,
    action      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    changed_by  BIGINT UNSIGNED NULL,
    ip_address  VARCHAR(45)     NULL,
    -- Store full row snapshots as JSON / Lưu snapshot hàng đầy đủ dạng JSON
    old_values  JSON            NULL,   -- NULL for INSERT
    new_values  JSON            NULL,   -- NULL for DELETE
    changed_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_audit_table_record (table_name, record_id),
    KEY idx_audit_changed_at   (changed_at),
    KEY idx_audit_changed_by   (changed_by)
) ENGINE=InnoDB;

-- Populate via application layer (not triggers for production)
-- Điền qua tầng ứng dụng (không dùng trigger trong production)
-- Triggers cause deadlock risks and hidden performance costs
-- Trigger gây rủi ro deadlock và chi phí hiệu năng ẩn
```

---

## Trigger-Based Audit (Use With Caution) / Kiểm Toán Qua Trigger (Cẩn Thận)

```sql
DELIMITER $$
CREATE TRIGGER trg_customers_after_update
AFTER UPDATE ON customers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, record_id, action, old_values, new_values)
    VALUES (
        'customers',
        NEW.id,
        'UPDATE',
        JSON_OBJECT('email', OLD.email, 'full_name', OLD.full_name),
        JSON_OBJECT('email', NEW.email, 'full_name', NEW.full_name)
    );
END$$
DELIMITER ;

-- ⚠️ Warning / Cảnh báo: Triggers run within the transaction
-- They can increase lock contention and slow down writes
-- Trigger chạy trong transaction — tăng tranh chấp lock và làm chậm ghi
```

---

## Summary / Tóm Tắt

| Pattern | Use Case |
|---------|----------|
| `created_at` + `updated_at` | All tables / Mọi bảng |
| `deleted_at` (soft delete) | Business entities (customers, products) |
| `deleted_at` is NULL queries | Default filter in all app queries |
| `audit_log` table | Financial, compliance, regulated data |
| Application-layer audit | Preferred over triggers / Ưu tiên hơn trigger |

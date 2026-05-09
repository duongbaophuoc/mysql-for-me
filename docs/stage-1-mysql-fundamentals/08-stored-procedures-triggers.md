# Stored Procedures & Triggers / Stored Procedure & Trigger

## Overview / Tổng Quan

- **Stored Procedures**: Reusable server-side SQL logic / Logic SQL phía server có thể tái sử dụng
- **Triggers**: Automated reactions to table events / Phản ứng tự động với sự kiện bảng

> **Production advice**: Prefer application-layer logic over stored procedures and triggers for most use cases. They make debugging harder and create hidden dependencies.
> _**Lời khuyên production**: Ưu tiên logic tầng ứng dụng hơn SP và trigger trong hầu hết trường hợp._

---

## Stored Procedures / Stored Procedure

```sql
DELIMITER $$

-- Procedure: process an order / Xử lý đơn hàng
CREATE PROCEDURE sp_confirm_order(
    IN  p_order_id   BIGINT UNSIGNED,
    IN  p_user_id    BIGINT UNSIGNED,
    OUT p_status     VARCHAR(50)
)
BEGIN
    DECLARE v_current_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = 'ERROR';
    END;

    START TRANSACTION;

    -- Get current status / Lấy trạng thái hiện tại
    SELECT status INTO v_current_status
    FROM orders WHERE id = p_order_id FOR UPDATE;

    -- Validate transition / Xác nhận chuyển trạng thái
    IF v_current_status != 'pending' THEN
        ROLLBACK;
        SET p_status = CONCAT('INVALID_STATUS:', v_current_status);
        LEAVE;
    END IF;

    -- Update order / Cập nhật đơn hàng
    UPDATE orders
    SET status     = 'confirmed',
        updated_at = CURRENT_TIMESTAMP(3)
    WHERE id = p_order_id;

    -- Log to audit / Ghi vào kiểm toán
    INSERT INTO audit_log (table_name, record_id, action, changed_by)
    VALUES ('orders', p_order_id, 'UPDATE', p_user_id);

    COMMIT;
    SET p_status = 'OK';
END$$

DELIMITER ;

-- Call the procedure / Gọi procedure
CALL sp_confirm_order(123, 5, @result);
SELECT @result;   -- 'OK' or error message
```

---

## Stored Functions / Stored Function

```sql
DELIMITER $$

-- Function: calculate order discount / Tính chiết khấu đơn hàng
CREATE FUNCTION fn_get_discount_rate(p_total DECIMAL(14,2))
RETURNS DECIMAL(5,4)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_rate DECIMAL(5,4);
    CASE
        WHEN p_total >= 50000000  THEN SET v_rate = 0.15;  -- 15%
        WHEN p_total >= 20000000  THEN SET v_rate = 0.10;  -- 10%
        WHEN p_total >= 5000000   THEN SET v_rate = 0.05;  -- 5%
        ELSE                           SET v_rate = 0.00;
    END CASE;
    RETURN v_rate;
END$$

DELIMITER ;

-- Usage in query / Sử dụng trong truy vấn
SELECT id, total_amount,
       fn_get_discount_rate(total_amount) AS discount_rate,
       total_amount * fn_get_discount_rate(total_amount) AS discount_amount
FROM orders WHERE status = 'pending';
```

---

## Triggers / Trigger

```sql
DELIMITER $$

-- Trigger: update inventory on order_item insert
-- Trigger: cập nhật tồn kho khi order_item được chèn
CREATE TRIGGER trg_order_items_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    -- Reduce available inventory / Giảm tồn kho khả dụng
    UPDATE inventory
    SET quantity_reserved = quantity_reserved + NEW.quantity
    WHERE product_id = NEW.product_id;

    -- Warning if stock is low / Cảnh báo nếu tồn kho thấp
    -- (in production, use application events instead of triggers)
END$$

DELIMITER ;

-- Trigger: audit on customer update / Kiểm toán khi khách hàng cập nhật
CREATE TRIGGER trg_customers_after_update
AFTER UPDATE ON customers
FOR EACH ROW
BEGIN
    IF OLD.email != NEW.email OR OLD.status != NEW.status THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values, new_values)
        VALUES (
            'customers', NEW.id, 'UPDATE',
            JSON_OBJECT('email', OLD.email, 'status', OLD.status),
            JSON_OBJECT('email', NEW.email, 'status', NEW.status)
        );
    END IF;
END$$
```

---

## Managing Procedures & Triggers / Quản Lý

```sql
-- List stored procedures / Liệt kê stored procedure
SHOW PROCEDURE STATUS WHERE Db = 'shop_db';

-- View procedure code / Xem code procedure
SHOW CREATE PROCEDURE sp_confirm_order\G

-- Drop / Xóa
DROP PROCEDURE IF EXISTS sp_confirm_order;
DROP FUNCTION  IF EXISTS fn_get_discount_rate;
DROP TRIGGER   IF EXISTS trg_order_items_after_insert;

-- List triggers / Liệt kê trigger
SHOW TRIGGERS FROM shop_db\G
```

---

## When to Use vs Avoid / Khi Nào Dùng vs Tránh

| Use Case | SP/Trigger | Application |
|----------|-----------|-------------|
| Complex multi-step transaction | ✅ SP | ✅ |
| Audit logging | ⚠️ Trigger (hidden cost) | ✅ Preferred |
| Business logic | ❌ Hard to version-control | ✅ |
| Database migration | ✅ One-time procedure | — |
| Derived calculations | ⚠️ Consider Generated Columns | ✅ |

# Slowly Changing Dimensions (SCD) / Chiều Thay Đổi Chậm

## Overview / Tổng Quan

In data warehouses, dimension data changes over time (customer moves city, product changes price). **SCD** defines strategies for handling these changes.
_Trong kho dữ liệu, dữ liệu chiều thay đổi theo thời gian. **SCD** định nghĩa chiến lược xử lý những thay đổi này._

---

## SCD Type 1 — Overwrite / Ghi Đè

Simply overwrite the old value. **No history preserved.**
_Đơn giản ghi đè giá trị cũ. **Không lưu lịch sử.**_

```sql
-- Customer moves city / Khách hàng chuyển thành phố
UPDATE dim_customer
SET city = 'Đà Nẵng'
WHERE customer_nk = 5 AND is_current = 1;

-- USE WHEN / DÙNG KHI: errors/corrections, non-analytical attributes
-- Chỉ dùng khi sửa lỗi hoặc thuộc tính không phân tích
```

---

## SCD Type 2 — Add New Row / Thêm Hàng Mới

Add a new row for each change, expire the old row. **Full history preserved.**
_Thêm hàng mới cho mỗi thay đổi, hết hạn hàng cũ. **Lưu đầy đủ lịch sử.**_

```sql
-- Customer changes city / Khách hàng thay đổi thành phố
-- Step 1: Expire existing record / Bước 1: Hết hạn bản ghi hiện tại
UPDATE dim_customer
SET effective_to = CURRENT_DATE() - INTERVAL 1 DAY,
    is_current   = 0
WHERE customer_nk = 5 AND is_current = 1;

-- Step 2: Insert new current record / Bước 2: Chèn bản ghi mới
INSERT INTO dim_customer
    (customer_nk, email, full_name, city, effective_from, effective_to, is_current)
VALUES
    (5, 'old@email.com', 'Nguyễn Văn A', 'Đà Nẵng', CURRENT_DATE(), NULL, 1);

-- Query current state / Truy vấn trạng thái hiện tại
SELECT * FROM dim_customer WHERE customer_nk = 5 AND is_current = 1;

-- Query historical state / Truy vấn trạng thái lịch sử
SELECT * FROM dim_customer
WHERE customer_nk = 5
  AND '2024-06-15' BETWEEN effective_from AND IFNULL(effective_to, '9999-12-31');
```

---

## SCD Type 3 — Add New Column / Thêm Cột Mới

Add a column for the previous value. **Only one previous value stored.**
_Thêm cột cho giá trị trước đó. **Chỉ lưu một giá trị trước đó.**_

```sql
ALTER TABLE dim_customer
    ADD COLUMN prev_city     VARCHAR(100) NULL,
    ADD COLUMN city_changed  DATE         NULL;

-- On change / Khi thay đổi:
UPDATE dim_customer
SET prev_city    = city,         -- save current as previous
    city         = 'Đà Nẵng',   -- set new value
    city_changed = CURRENT_DATE()
WHERE customer_nk = 5 AND is_current = 1;
-- USE WHEN / DÙNG KHI: only "before vs after" comparison needed
```

---

## Comparison / So Sánh

| Type | History | Storage | Complexity | Use Case |
|------|---------|---------|------------|----------|
| **Type 1** | None | Low | Low | Corrections, non-analytics |
| **Type 2** | Full | High | Medium | Most analytics scenarios |
| **Type 3** | One version | Medium | Low | "Before/after" comparison |

**MySQL recommendation**: Use **SCD Type 2** with `effective_from`, `effective_to`, `is_current`.
_**Khuyến nghị MySQL**: Dùng **SCD Type 2** với `effective_from`, `effective_to`, `is_current`._

This is already implemented in `analytics_dw.dim_customer` and `dim_product`.
_Đã triển khai trong `analytics_dw.dim_customer` và `dim_product`._

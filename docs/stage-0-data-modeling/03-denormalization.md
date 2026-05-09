# Denormalization / Phi Chuẩn Hóa

## Overview / Tổng Quan

Denormalization is the intentional introduction of redundancy to improve **read performance**.
_Phi chuẩn hóa là việc cố ý đưa vào dư thừa để cải thiện **hiệu năng đọc**._

> **Rule**: Normalize first, then denormalize only where profiling shows it's necessary.
> _**Quy tắc**: Chuẩn hóa trước, chỉ phi chuẩn hóa khi profiling cho thấy cần thiết._

---

## When to Denormalize / Khi Nào Phi Chuẩn Hóa

| Signal | Action |
|--------|--------|
| Query requires 5+ JOINs | Consider flattening / Cân nhắc làm phẳng |
| Same JOIN repeated millions of times/day | Pre-join the data |
| Aggregate recomputed on every request | Materialize the aggregate |
| Read : Write ratio > 100:1 | Denormalization pays off |

---

## Pattern 1: Snapshot Denormalization / Phi Chuẩn Hóa Snapshot

Store a snapshot of data at the time of a transaction (even if the source changes later):
_Lưu snapshot dữ liệu tại thời điểm giao dịch:_

```sql
-- order_items stores product_name at time of purchase
-- order_items lưu product_name tại thời điểm mua
CREATE TABLE order_items (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id     BIGINT UNSIGNED NOT NULL,
    product_id   BIGINT UNSIGNED NOT NULL,
    product_name VARCHAR(500)    NOT NULL,   -- ← snapshot, not FK lookup
    product_sku  VARCHAR(100)    NOT NULL,   -- ← snapshot
    unit_price   DECIMAL(12,2)   NOT NULL,   -- ← snapshot
    quantity     INT             NOT NULL,
    PRIMARY KEY (id)
);
-- Even if products.name changes later, order history is preserved
-- Dù products.name đổi sau, lịch sử đơn hàng vẫn chính xác
```

---

## Pattern 2: Redundant Column / Cột Dư Thừa

Duplicate a column to avoid a JOIN:
_Sao chép cột để tránh JOIN:_

```sql
-- NORMALIZED (2 tables) / Chuẩn hóa (2 bảng)
SELECT o.id, c.email
FROM orders o JOIN customers c ON c.id = o.customer_id;

-- DENORMALIZED (1 table lookup) / Phi chuẩn hóa (tra cứu 1 bảng)
ALTER TABLE orders ADD COLUMN customer_email VARCHAR(255);
-- Now queries for "email of order owner" need no JOIN
-- UPDATE orders SET customer_email = ... on customer email change via trigger/app
```

### Trade-off / Đánh Đổi

```
Benefits / Lợi ích:
  ✅ Faster reads, fewer JOINs
  ✅ Simpler queries

Costs / Chi phí:
  ❌ Data can get out of sync (email changes)
  ❌ Extra storage
  ❌ Must update redundant column on source change
```

---

## Pattern 3: Pre-aggregated Counters / Bộ Đếm Tổng Hợp Trước

```sql
-- Without counter / Không có bộ đếm:
SELECT COUNT(*) FROM orders WHERE customer_id = 5; -- scans orders table

-- With counter / Có bộ đếm:
ALTER TABLE customers ADD COLUMN total_orders INT UNSIGNED DEFAULT 0;

-- Update on each order / Cập nhật mỗi đơn hàng:
UPDATE customers SET total_orders = total_orders + 1 WHERE id = :customer_id;

-- Now COUNT query becomes a point lookup / COUNT trở thành tra cứu điểm:
SELECT total_orders FROM customers WHERE id = 5;
```

---

## Denormalization in OLAP / Phi Chuẩn Hóa Trong OLAP

In analytics warehouses, denormalization is the **default** design:
_Trong kho dữ liệu phân tích, phi chuẩn hóa là thiết kế **mặc định**:_

```sql
-- fact_sales stores customer_name directly / fact_sales lưu trực tiếp customer_name
-- No JOIN needed in analytical queries / Không cần JOIN trong truy vấn phân tích
SELECT
    customer_name,         -- denormalized from dim_customer
    product_category,      -- denormalized from dim_product
    SUM(gross_revenue)
FROM fact_sales
WHERE year = 2024
GROUP BY customer_name, product_category;
```

---

## Summary / Tóm Tắt

| Technique | Use When | Risk |
|-----------|----------|------|
| Snapshot columns | Historical accuracy needed | Low |
| Redundant columns | Hot read paths, rarely updated | Medium |
| Pre-aggregated counters | COUNT queries at high volume | Medium |
| Star schema (OLAP) | Analytics workloads | Design decision |

# OLTP vs OLAP Modeling / Mô Hình OLTP vs OLAP

## Overview / Tổng Quan

One of the most important architectural decisions in database engineering is understanding when you're designing for a **transactional** workload vs an **analytical** workload.
_Một trong những quyết định kiến trúc quan trọng nhất là hiểu khi nào thiết kế cho tải **giao dịch** vs tải **phân tích**._

---

## Comparison / So Sánh

| Characteristic | OLTP | OLAP |
|----------------|------|------|
| **Full Name** | Online Transaction Processing | Online Analytical Processing |
| **Purpose** | Record business transactions | Answer business questions |
| **Query Type** | INSERT/UPDATE/DELETE + simple SELECTs | Complex SELECTs, GROUP BY |
| **Data Volume** | Thousands of rows | Millions to billions of rows |
| **Normalization** | High (3NF) | Low (denormalized) |
| **Schema** | Normalized: many tables, many JOINs | Star/snowflake: few fat tables |
| **Latency** | Milliseconds | Seconds to minutes |
| **Concurrency** | Thousands of concurrent users | Tens of analysts |
| **Example** | `shop_db` | `analytics_dw` |

---

## OLTP Design Principles / Nguyên Tắc Thiết Kế OLTP

### 1. Normalize aggressively / Chuẩn hóa mạnh mẽ

```sql
-- OLTP: normalized, write-optimized
-- OLTP: chuẩn hóa, tối ưu ghi
orders (id, customer_id, status, total)
order_items (order_id, product_id, quantity, price)
products (id, name, sku, price)
customers (id, email, name)
```

### 2. Index for point lookups / Chỉ mục cho tra cứu điểm

```sql
-- Fast single-row lookups / Tra cứu hàng đơn nhanh
SELECT * FROM orders WHERE id = 12345;           -- PK lookup
SELECT * FROM customers WHERE email = 'x@y.com'; -- unique index
```

### 3. Short ACID transactions / Giao dịch ACID ngắn

```sql
START TRANSACTION;
  UPDATE inventory SET quantity_available = quantity_available - 1
  WHERE product_id = 5 AND quantity_available > 0;
  
  INSERT INTO order_items (order_id, product_id, quantity, unit_price)
  VALUES (999, 5, 1, 29990000);
COMMIT;
-- Transaction should complete in <10ms / Giao dịch phải hoàn thành trong <10ms
```

---

## OLAP Design Principles / Nguyên Tắc Thiết Kế OLAP

### 1. Denormalize for read performance / Phi chuẩn hóa cho hiệu năng đọc

```sql
-- OLAP: denormalized, read-optimized
-- OLAP: phi chuẩn hóa, tối ưu đọc
fact_sales (
    date_key, customer_sk, product_sk,
    gross_revenue, net_revenue, quantity,  -- measures
    customer_name, customer_segment,       -- denormalized dimensions
    product_name, category_name            -- no JOIN needed!
)
```

### 2. Pre-aggregate for common queries / Tổng hợp trước cho truy vấn phổ biến

```sql
-- Materialized aggregate: refresh nightly / Tổng hợp vật thể hóa: làm mới hàng đêm
CREATE TABLE agg_daily_sales (
    date_key     INT,
    product_sk   BIGINT,
    units_sold   INT,
    gross_revenue DECIMAL(16,2),
    PRIMARY KEY (date_key, product_sk)
);
```

### 3. Partition large fact tables / Phân vùng bảng thực tế lớn

```sql
-- Range partition by date for efficient pruning / Phân vùng phạm vi theo ngày
CREATE TABLE fact_sales (...)
PARTITION BY RANGE (date_key) (
    PARTITION p2023 VALUES LESS THAN (20240101),
    PARTITION p2024 VALUES LESS THAN (20250101),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Query only hits p2024 partition / Truy vấn chỉ quét phân vùng p2024
SELECT SUM(gross_revenue)
FROM fact_sales
WHERE date_key BETWEEN 20240101 AND 20241231;
```

---

## Hybrid Architecture / Kiến Trúc Lai

In practice, most organizations run both:
_Trong thực tế, hầu hết tổ chức chạy cả hai:_

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                             │
│                 Tầng Ứng Dụng                                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
            ┌────────────┴────────────┐
            │                         │
    ┌───────▼────────┐       ┌────────▼────────┐
    │  shop_db       │       │  analytics_dw   │
    │  (OLTP)        │  ETL  │  (OLAP)         │
    │  MySQL 8.0     ├──────►│  MySQL / OLAP   │
    │                │  CDC  │  Warehouse      │
    └────────────────┘       └─────────────────┘
   Writes, transactions      Reports, dashboards
   Ghi, giao dịch            Báo cáo, bảng điều khiển
```

---

## Decision Guide / Hướng Dẫn Quyết Định

Use **OLTP** when:
- Storing application transactions / Lưu giao dịch ứng dụng
- Need row-level ACID guarantees / Cần đảm bảo ACID cấp hàng
- Concurrent users modifying data / Người dùng đồng thời sửa đổi dữ liệu

Use **OLAP** when:
- Answering business intelligence questions / Trả lời câu hỏi BI
- Aggregating millions of historical records / Tổng hợp hàng triệu bản ghi lịch sử
- Dataset is mostly read-only / Tập dữ liệu chủ yếu chỉ đọc

# Data Warehouse Modeling / Mô Hình Hóa Kho Dữ Liệu

## Overview / Tổng Quan

Data warehouse modeling is the process of designing a schema optimized for **analytical queries** (GROUP BY, aggregations, historical analysis) rather than transactions.
_Mô hình hóa kho dữ liệu là thiết kế schema tối ưu cho **truy vấn phân tích** thay vì giao dịch._

---

## Kimball vs Inmon / Kimball vs Inmon

| Aspect | Kimball (Bottom-Up) | Inmon (Top-Down) |
|--------|--------------------|-----------------| 
| Approach | Build data marts first | Build enterprise DW first |
| Schema | Star schema | 3NF normalized |
| Speed to value | Fast | Slow |
| Integration | Per-mart | Enterprise-wide |
| Best for | Agile teams | Large enterprises |

**MySQL analytics_dw uses Kimball's Star Schema approach.**
_**analytics_dw dùng Star Schema theo phương pháp Kimball.**_

---

## Fact Table Design / Thiết Kế Bảng Thực Tế

```sql
-- Additive facts: can be summed across any dimension / Có thể tổng hợp theo mọi chiều
gross_revenue    DECIMAL(14,2),   -- additive
net_revenue      DECIMAL(14,2),   -- additive
quantity         INT,             -- additive

-- Semi-additive: can be summed across some dimensions / Tổng hợp một số chiều
account_balance  DECIMAL(14,2),   -- makes sense for customer, not for time sum

-- Non-additive: ratios, percentages / Không thể tổng hợp: tỷ lệ, phần trăm
discount_pct     DECIMAL(5,2),    -- don't SUM percentages!
-- Instead: compute from additive facts / Thay vào đó: tính từ các fact có thể tổng hợp
SELECT SUM(discount_amount) / SUM(gross_revenue) AS effective_discount_rate
```

---

## Fact Table Types / Loại Bảng Thực Tế

```sql
-- 1. Transaction grain: one row per business event / Một hàng mỗi sự kiện
fact_sales (date_key, customer_sk, product_sk, quantity, revenue)

-- 2. Periodic snapshot: one row per period per subject / Một hàng mỗi kỳ mỗi chủ thể
fact_inventory_daily (date_key, product_sk, warehouse_sk, quantity_on_hand)

-- 3. Accumulating snapshot: tracks stages of a business process
-- Theo dõi các giai đoạn của quy trình nghiệp vụ
fact_order_fulfillment (
    order_nk,
    order_date_key,
    shipped_date_key,   -- NULL until shipped / NULL đến khi vận chuyển
    delivered_date_key, -- NULL until delivered / NULL đến khi giao
    days_to_ship,
    days_to_deliver
)
```

---

## Dimension Design / Thiết Kế Chiều

```sql
-- Conformed dimension: reused across multiple fact tables
-- Chiều hợp nhất: tái sử dụng qua nhiều bảng thực tế
dim_date     → used by fact_sales, fact_inventory, fact_orders
dim_customer → used by fact_sales, fact_support_tickets

-- Junk dimension: low-cardinality flags combined into one table
-- Chiều rác: cờ cardinality thấp gộp vào một bảng
dim_order_flags (
    flag_sk,
    is_first_order,     BOOLEAN
    is_corporate,       BOOLEAN
    is_weekend_order,   BOOLEAN
    payment_type        ENUM('card','cod','bank')
)
```

---

## Analytics_DW vs Shop_DB Schema Comparison

| Aspect | shop_db (OLTP) | analytics_dw (OLAP) |
|--------|---------------|---------------------|
| Tables | 10+ normalized | 5 facts + 8 dimensions |
| JOINs needed | Many | Few (pre-denormalized) |
| Row count focus | Thousands | Millions |
| Partition | None | By date_key |
| Index strategy | Many secondary | Few, fact-focused |
| Updates | Constant | Nightly batch |

# Star Schema & Snowflake Schema / Star Schema & Snowflake Schema

## Overview / Tổng Quan

Star and Snowflake schemas are the two primary modeling patterns for analytical (OLAP) databases.
_Star và Snowflake schema là hai mẫu mô hình hóa chính cho CSDL phân tích (OLAP)._

---

## Star Schema / Star Schema

A **fact table** at the center, surrounded by **dimension tables** — like a star.
_**Bảng thực tế** ở trung tâm, bao quanh bởi **bảng chiều** — như ngôi sao._

```
             dim_date
                │
dim_customer ──►│◄── dim_product
                │
           fact_sales
                │
dim_payment_method  dim_geography
```

### Fact Table / Bảng Thực Tế

Contains **measurable events** and foreign keys to dimensions:
_Chứa **sự kiện đo lường được** và khóa ngoại đến chiều:_

```sql
CREATE TABLE fact_sales (
    sale_sk          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    -- Foreign keys to dimensions / Khóa ngoại đến chiều
    date_key         INT UNSIGNED    NOT NULL,   -- → dim_date
    customer_sk      BIGINT UNSIGNED NOT NULL,   -- → dim_customer
    product_sk       BIGINT UNSIGNED NOT NULL,   -- → dim_product
    -- Measures / Số liệu đo lường
    quantity         INT UNSIGNED    NOT NULL,
    gross_revenue    DECIMAL(14,2)   NOT NULL,
    net_revenue      DECIMAL(14,2)   NOT NULL,
    PRIMARY KEY (sale_sk)
) PARTITION BY RANGE (date_key) (...);
```

### Dimension Table / Bảng Chiều

Contains **descriptive attributes** for filtering and grouping:
_Chứa **thuộc tính mô tả** để lọc và nhóm:_

```sql
CREATE TABLE dim_product (
    product_sk    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_nk    BIGINT UNSIGNED NOT NULL,   -- Natural key from OLTP
    sku           VARCHAR(100)    NOT NULL,
    product_name  VARCHAR(500)    NOT NULL,
    category_name VARCHAR(255),
    brand         VARCHAR(100),
    unit_price    DECIMAL(12,2),
    PRIMARY KEY (product_sk)
);
```

---

## Snowflake Schema / Snowflake Schema

Snowflake normalizes dimension tables into sub-dimensions:
_Snowflake chuẩn hóa bảng chiều thành các chiều con:_

```
fact_sales → dim_product → dim_category → dim_category_group
                        → dim_brand
           → dim_customer → dim_geography → dim_country → dim_region
```

### Star vs Snowflake Comparison / So Sánh Star vs Snowflake

| Aspect | Star Schema | Snowflake Schema |
|--------|-------------|-----------------|
| Normalization | Denormalized | Normalized dimensions |
| Query complexity | Simple (few JOINs) | Complex (many JOINs) |
| Storage | More | Less |
| Query speed | Faster | Slower |
| Maintenance | Harder (redundancy) | Easier |
| Best for | MySQL OLAP | Large cloud DWs |

**For MySQL**: Star schema is almost always better — fewer JOINs = faster queries.
_**Cho MySQL**: Star schema hầu như luôn tốt hơn — ít JOIN = truy vấn nhanh hơn._

---

## Date Dimension — The Most Important Dimension
## Chiều Ngày — Chiều Quan Trọng Nhất

Pre-populate `dim_date` to enable fast date-based analytics without date functions:
_Điền trước `dim_date` để phân tích theo ngày nhanh không cần hàm ngày:_

```sql
-- Fast grouping by month — no MONTH() function / Nhóm nhanh theo tháng
SELECT d.month_name_vi, SUM(fs.gross_revenue)
FROM fact_sales fs
JOIN dim_date d ON d.date_key = fs.date_key
WHERE d.year = 2024
GROUP BY d.month, d.month_name_vi
ORDER BY d.month;

-- vs slow approach with function / so với cách chậm với hàm
SELECT MONTH(sale_date), SUM(gross_revenue)     -- ← prevents index use on partition key
FROM fact_sales_bad
WHERE YEAR(sale_date) = 2024
GROUP BY MONTH(sale_date);
```

---

## Grain — The Most Important Decision / Grain — Quyết Định Quan Trọng Nhất

The **grain** defines what one row in the fact table represents:
_**Grain** định nghĩa một hàng trong bảng thực tế đại diện cho điều gì:_

```
Grain options for fact_sales / Tùy chọn grain cho fact_sales:
  - One row per order          → aggregate grain (simpler)
  - One row per order_item     → transaction grain (more flexible) ← chosen
  - One row per daily product  → periodic snapshot grain
```

**Rule**: Choose the finest grain that answers your business questions.
_**Quy tắc**: Chọn grain nhỏ nhất trả lời được câu hỏi kinh doanh._

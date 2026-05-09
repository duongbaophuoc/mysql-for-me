# analytics_dw — Star Schema Data Warehouse
# analytics_dw — Kho Dữ Liệu Star Schema

## Overview / Tổng Quan

`analytics_dw` is a data warehouse built on MySQL using the **Star Schema** pattern.
_`analytics_dw` là kho dữ liệu được xây dựng trên MySQL sử dụng mẫu **Star Schema**._

It is designed to serve as the analytical layer that receives data via ETL/CDC from `shop_db`.
_Nó được thiết kế làm tầng phân tích nhận dữ liệu qua ETL/CDC từ `shop_db`._

## Architecture / Kiến Trúc

```
                     ┌─────────────┐
                     │  dim_date   │
                     └──────┬──────┘
                            │
┌──────────────┐    ┌───────▼────────┐    ┌──────────────────────┐
│ dim_customer ├────►   fact_sales   ◄────┤      dim_product      │
└──────────────┘    └───────┬────────┘    └──────────────────────┘
                            │
              ┌─────────────┼──────────────┐
              │             │              │
   ┌──────────▼──────┐ ┌────▼─────┐ ┌────▼────────────────┐
   │ dim_payment_    │ │dim_geo-  │ │  agg_daily_sales     │
   │ method          │ │graphy    │ │  (materialized agg)  │
   └─────────────────┘ └──────────┘ └──────────────────────┘
```

## Tables / Các Bảng

| Table                 | Type         | Description                                    |
| --------------------- | ------------ | ---------------------------------------------- |
| `dim_date`            | Dimension    | Pre-populated date dimension 2020–2030         |
| `dim_customer`        | SCD Type 2   | Customer history with effective dates          |
| `dim_product`         | SCD Type 2   | Product history with effective dates           |
| `dim_payment_method`  | Dimension    | Payment method lookup                          |
| `dim_geography`       | Dimension    | Geographic hierarchy                           |
| `fact_sales`          | Fact         | One row per order line, partitioned by year    |
| `fact_payments`       | Fact         | One row per payment event                      |
| `agg_daily_sales`     | Aggregate    | Pre-computed daily summaries                   |

## Key Design Decisions / Quyết Định Thiết Kế Quan Trọng

### SCD Type 2 / Slowly Changing Dimensions Loại 2

Customer and product dimensions track changes over time using `effective_from`, `effective_to`, and `is_current`:
_Dimension khách hàng và sản phẩm theo dõi thay đổi theo thời gian:_

```sql
-- Get current product record / Lấy bản ghi sản phẩm hiện tại
SELECT * FROM dim_product WHERE product_nk = 1 AND is_current = 1;

-- Get what the product looked like on a specific date
-- Xem sản phẩm trông như thế nào vào một ngày cụ thể
SELECT * FROM dim_product
WHERE product_nk = 1
  AND effective_from <= '2024-06-01'
  AND (effective_to IS NULL OR effective_to > '2024-06-01');
```

### Partitioned Fact Table / Bảng Thực Tế Phân Vùng

`fact_sales` is range-partitioned by `date_key` (YYYYMMDD), enabling:
_`fact_sales` được phân vùng theo `date_key` (YYYYMMDD), cho phép:_

- Partition pruning for date range queries / Cắt tỉa phân vùng cho truy vấn theo khoảng thời gian
- Easy archival (drop old partitions) / Lưu trữ dễ dàng (xóa phân vùng cũ)
- Parallel loading / Nạp song song

## Quick Start / Khởi Động Nhanh

```bash
# Load schema / Nạp schema
mysql -h 127.0.0.1 -P 3306 -u root -psecret < schema.sql

# Populate date dimension (use etl/ scripts) / Điền dimension ngày
mysql -h 127.0.0.1 -P 3306 -u root -psecret analytics_dw < ../../etl/dbt/models/staging/stg_orders.sql
```

## Sample Analytical Queries / Truy Vấn Phân Tích Mẫu

```sql
-- Monthly Revenue by Product Category / Doanh thu hàng tháng theo danh mục sản phẩm
SELECT
    d.year,
    d.month_name,
    p.category_name,
    SUM(fs.gross_revenue)    AS gross_revenue,
    SUM(fs.net_revenue)      AS net_revenue,
    SUM(fs.quantity)         AS units_sold
FROM fact_sales fs
JOIN dim_date    d  ON d.date_key    = fs.date_key
JOIN dim_product p  ON p.product_sk  = fs.product_sk AND p.is_current = 1
WHERE d.year = 2024
GROUP BY d.year, d.month, d.month_name, p.category_name
ORDER BY d.month, gross_revenue DESC;

-- Customer Cohort Revenue / Doanh thu theo nhóm khách hàng
SELECT
    c.segment,
    COUNT(DISTINCT fs.customer_sk)          AS customers,
    SUM(fs.net_revenue)                      AS total_revenue,
    AVG(fs.net_revenue)                      AS avg_revenue_per_order
FROM fact_sales fs
JOIN dim_customer c ON c.customer_sk = fs.customer_sk AND c.is_current = 1
GROUP BY c.segment
ORDER BY total_revenue DESC;
```

# Lab 08 — Warehouse ETL Pipeline / Pipeline ETL Kho Dữ Liệu

## Objective / Mục Tiêu

Build a complete ETL pipeline from `shop_db` to `analytics_dw` using SQL.
_Xây dựng pipeline ETL hoàn chỉnh từ `shop_db` sang `analytics_dw` sử dụng SQL._

**Duration / Thời lượng**: ~60 minutes

---

## Setup / Thiết Lập

```bash
# Load both databases / Nạp cả hai CSDL
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/shop_db/schema.sql
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/shop_db/seed.sql
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/analytics_dw/schema.sql

# Run ETL pipeline / Chạy pipeline ETL
mysql -h 127.0.0.1 -P 3306 -u root -psecret < labs/lab-08-warehouse-etl/etl-pipeline.sql
```

---

## Step 1: Populate dim_date / Điền dim_date

```sql
-- Generate date dimension for 2020-2026 / Tạo dimension ngày cho 2020-2026
USE analytics_dw;

CREATE TEMPORARY TABLE date_sequence AS (
    SELECT DATE_ADD('2020-01-01', INTERVAL seq DAY) AS full_date
    FROM (
        SELECT @row := @row + 1 AS seq
        FROM information_schema.columns,
             (SELECT @row := -1) init
        LIMIT 2557  -- 7 years / 7 năm
    ) nums
);

INSERT INTO dim_date (
    date_key, full_date, year, quarter, quarter_name,
    month, month_name, month_name_vi, month_short,
    week_of_year, day_of_week, day_name, day_name_vi,
    day_of_month, day_of_year,
    is_weekend, fiscal_year, fiscal_quarter
)
SELECT
    DATE_FORMAT(full_date, '%Y%m%d')                           AS date_key,
    full_date,
    YEAR(full_date),
    QUARTER(full_date),
    CONCAT('Q', QUARTER(full_date)),
    MONTH(full_date),
    MONTHNAME(full_date),
    ELT(MONTH(full_date), 'Tháng 1','Tháng 2','Tháng 3','Tháng 4',
        'Tháng 5','Tháng 6','Tháng 7','Tháng 8','Tháng 9',
        'Tháng 10','Tháng 11','Tháng 12'),
    LEFT(MONTHNAME(full_date), 3),
    WEEKOFYEAR(full_date),
    DAYOFWEEK(full_date),
    DAYNAME(full_date),
    ELT(DAYOFWEEK(full_date), 'Chủ nhật','Thứ 2','Thứ 3','Thứ 4',
        'Thứ 5','Thứ 6','Thứ 7'),
    DAY(full_date),
    DAYOFYEAR(full_date),
    DAYOFWEEK(full_date) IN (1, 7),   -- Sunday=1, Saturday=7
    YEAR(full_date),
    QUARTER(full_date)
FROM date_sequence;

SELECT COUNT(*) AS dates_loaded FROM dim_date;
```

---

## Step 2: Load dim_customer from shop_db / Nạp dim_customer từ shop_db

```sql
-- SCD Type 1 load (simple, overwrite)
-- Nạp SCD Loại 1 (đơn giản, ghi đè)
INSERT INTO analytics_dw.dim_customer (
    customer_nk, customer_uuid, email, full_name,
    effective_from, is_current
)
SELECT
    id,
    uuid,
    email,
    full_name,
    DATE(created_at),
    1
FROM shop_db.customers
WHERE deleted_at IS NULL
ON DUPLICATE KEY UPDATE
    email       = VALUES(email),
    full_name   = VALUES(full_name),
    is_current  = 1;

SELECT COUNT(*) AS customers_loaded FROM analytics_dw.dim_customer;
```

---

## Step 3: Load fact_sales / Nạp fact_sales

```sql
-- Load order items as fact rows / Nạp chi tiết đơn hàng làm hàng thực tế
INSERT INTO analytics_dw.fact_sales (
    date_key, customer_sk, product_sk,
    order_nk, order_uuid, order_item_nk,
    quantity, unit_price, discount_amount,
    subtotal_amount, gross_revenue, net_revenue,
    order_source, dw_inserted_at
)
SELECT
    DATE_FORMAT(o.created_at, '%Y%m%d')     AS date_key,
    dc.customer_sk,
    1                                        AS product_sk,
    o.id                                     AS order_nk,
    o.uuid                                   AS order_uuid,
    oi.id                                    AS order_item_nk,
    oi.quantity,
    oi.unit_price,
    oi.discount,
    oi.line_total,
    oi.line_total                            AS gross_revenue,
    oi.line_total - oi.discount             AS net_revenue,
    o.source                                 AS order_source,
    NOW()
FROM shop_db.order_items oi
JOIN shop_db.orders    o  ON o.id = oi.order_id
JOIN analytics_dw.dim_customer dc
     ON dc.customer_nk = o.customer_id AND dc.is_current = 1
WHERE o.status = 'delivered'
ON DUPLICATE KEY UPDATE
    net_revenue    = VALUES(net_revenue),
    dw_inserted_at = NOW();

SELECT COUNT(*) AS fact_rows_loaded FROM analytics_dw.fact_sales;
```

---

## Step 4: Run Analytical Queries / Chạy Truy Vấn Phân Tích

```sql
-- Monthly revenue by customer / Doanh thu hàng tháng theo khách hàng
SELECT
    d.year,
    d.month_name_vi                          AS thang,
    c.full_name                              AS khach_hang,
    SUM(fs.gross_revenue)                    AS doanh_thu_gop,
    SUM(fs.net_revenue)                      AS doanh_thu_thuan,
    SUM(fs.quantity)                         AS so_luong
FROM analytics_dw.fact_sales fs
JOIN analytics_dw.dim_date     d ON d.date_key    = fs.date_key
JOIN analytics_dw.dim_customer c ON c.customer_sk = fs.customer_sk
GROUP BY d.year, d.month, d.month_name_vi, c.full_name
ORDER BY d.year, d.month, doanh_thu_gop DESC;
```

---

## Expected Outcomes / Kết Quả Mong Đợi

- ✅ dim_date populated for 7 years
- ✅ dim_customer loaded from shop_db with SCD logic
- ✅ fact_sales populated from order_items
- ✅ Analytical queries return meaningful results

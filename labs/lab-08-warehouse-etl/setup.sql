-- =============================================================================
-- Lab 08: Warehouse ETL — Setup & Queries
-- Lab 08: ETL Kho Dữ Liệu — Thiết Lập & Truy Vấn
-- =============================================================================

-- =============================================================================
-- STEP 1: Verify analytics_dw schema / Xác minh schema analytics_dw
-- =============================================================================

USE analytics_dw;
SHOW TABLES;
-- Expected: fact_sales, dim_date, dim_customer, dim_product, dim_payment_method, ...
-- Nếu chưa có: mysql -u root -psecret analytics_dw < /app/sample-db/analytics_dw/schema.sql

-- =============================================================================
-- STEP 2: Populate dim_date (required first!)
-- Điền dim_date (bắt buộc trước!)
-- =============================================================================

DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS populate_dim_date(
    p_start_date DATE,
    p_end_date   DATE
)
BEGIN
    DECLARE v_date DATE DEFAULT p_start_date;
    WHILE v_date <= p_end_date DO
        INSERT IGNORE INTO dim_date (
            date_key, full_date, year, quarter, month,
            month_name, month_name_vi, week, day_of_week,
            day_name, day_name_vi, is_weekend, is_holiday
        ) VALUES (
            DATE_FORMAT(v_date, '%Y%m%d'),
            v_date,
            YEAR(v_date),
            QUARTER(v_date),
            MONTH(v_date),
            DATE_FORMAT(v_date, '%M'),
            ELT(MONTH(v_date),
                'Tháng 1','Tháng 2','Tháng 3','Tháng 4',
                'Tháng 5','Tháng 6','Tháng 7','Tháng 8',
                'Tháng 9','Tháng 10','Tháng 11','Tháng 12'),
            WEEK(v_date, 1),
            DAYOFWEEK(v_date),
            DAYNAME(v_date),
            ELT(DAYOFWEEK(v_date),
                'Chủ Nhật','Thứ Hai','Thứ Ba','Thứ Tư',
                'Thứ Năm','Thứ Sáu','Thứ Bảy'),
            IF(DAYOFWEEK(v_date) IN (1,7), 1, 0),
            0   -- is_holiday: update manually / cập nhật thủ công
        );
        SET v_date = DATE_ADD(v_date, INTERVAL 1 DAY);
    END WHILE;
END$$
DELIMITER ;

-- Populate 3 years of dates / Điền 3 năm ngày
CALL populate_dim_date('2022-01-01', '2025-12-31');
SELECT COUNT(*) AS days_loaded FROM dim_date;

-- =============================================================================
-- STEP 3: Populate dimensions from shop_db
-- Điền chiều từ shop_db
-- =============================================================================

-- Load customers dimension (current state only)
-- Nạp chiều khách hàng (chỉ trạng thái hiện tại)
INSERT INTO dim_customer (
    customer_nk, email, full_name, phone,
    city, country,
    effective_from, effective_to, is_current
)
SELECT
    c.id,
    c.email,
    c.full_name,
    c.phone,
    COALESCE(a.city, 'N/A'),
    COALESCE(a.country, 'VN'),
    c.created_at,
    NULL,   -- is_current = 1, no end date
    1
FROM shop_db.customers c
LEFT JOIN shop_db.customer_addresses a
    ON a.customer_id = c.id AND a.is_default = 1
WHERE c.deleted_at IS NULL
ON DUPLICATE KEY UPDATE
    email      = VALUES(email),
    full_name  = VALUES(full_name),
    is_current = 1;

-- Load products dimension / Nạp chiều sản phẩm
INSERT INTO dim_product (
    product_nk, sku, product_name, category_name, unit_price,
    effective_from, effective_to, is_current
)
SELECT
    p.id,
    p.sku,
    p.name,
    COALESCE(c.name, 'Uncategorized'),
    p.price,
    p.created_at,
    NULL,
    1
FROM shop_db.products p
LEFT JOIN shop_db.categories c ON c.id = p.category_id
ON DUPLICATE KEY UPDATE
    product_name  = VALUES(product_name),
    unit_price    = VALUES(unit_price),
    is_current    = 1;

-- =============================================================================
-- STEP 4: Load fact_sales from orders + order_items
-- Nạp fact_sales từ orders + order_items
-- =============================================================================

INSERT INTO fact_sales (
    date_key, customer_sk, product_sk,
    order_nk, order_item_nk,
    quantity_sold, unit_price,
    gross_revenue, net_revenue
)
SELECT
    DATE_FORMAT(o.created_at, '%Y%m%d')  AS date_key,
    dc.customer_sk,
    dp.product_sk,
    o.id                                 AS order_nk,
    oi.id                                AS order_item_nk,
    oi.quantity,
    oi.unit_price,
    oi.line_total                        AS gross_revenue,
    oi.line_total * (1 - oi.discount_pct/100) AS net_revenue
FROM shop_db.orders o
JOIN shop_db.order_items  oi ON oi.order_id  = o.id
JOIN dim_customer         dc ON dc.customer_nk = o.customer_id AND dc.is_current = 1
JOIN dim_product          dp ON dp.product_nk  = oi.product_id AND dp.is_current = 1
WHERE o.status = 'delivered'
ON DUPLICATE KEY UPDATE
    gross_revenue = VALUES(gross_revenue),
    net_revenue   = VALUES(net_revenue);

SELECT COUNT(*) AS fact_rows_loaded FROM fact_sales;

-- =============================================================================
-- STEP 5: Analytical queries on the warehouse
-- Truy vấn phân tích trên kho
-- =============================================================================

-- Monthly revenue / Doanh thu hàng tháng
SELECT
    d.year,
    d.month,
    d.month_name_vi,
    SUM(fs.gross_revenue)          AS gross_revenue,
    SUM(fs.net_revenue)            AS net_revenue,
    COUNT(DISTINCT fs.order_nk)    AS orders,
    COUNT(DISTINCT fs.customer_sk) AS unique_customers
FROM fact_sales fs
JOIN dim_date d ON d.date_key = fs.date_key
GROUP BY d.year, d.month, d.month_name_vi
ORDER BY d.year, d.month;

-- Top 5 products / Top 5 sản phẩm
SELECT
    dp.product_name,
    dp.category_name,
    SUM(fs.quantity_sold)  AS units_sold,
    SUM(fs.gross_revenue)  AS revenue
FROM fact_sales fs
JOIN dim_product dp ON dp.product_sk = fs.product_sk
GROUP BY dp.product_sk, dp.product_name, dp.category_name
ORDER BY revenue DESC
LIMIT 5;

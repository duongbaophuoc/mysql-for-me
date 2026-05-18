-- =============================================================================
-- analytics_dw — Star Schema Data Warehouse
-- Kho dữ liệu theo mô hình Star Schema cho phân tích
-- =============================================================================

CREATE DATABASE IF NOT EXISTS analytics_dw
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE analytics_dw;

-- =============================================================================
-- dim_date — Dimension thời gian (Date dimension)
-- Pre-populated with years 2020-2030 for fast date-based analytics
-- Được điền trước cho các năm 2020-2030 để phân tích theo ngày nhanh
-- =============================================================================
CREATE TABLE dim_date (
    date_key        INT UNSIGNED    NOT NULL,               -- YYYYMMDD format, e.g. 20240115
    full_date       DATE            NOT NULL,
    -- Year / Năm
    year            SMALLINT        NOT NULL,
    year_half       TINYINT         NOT NULL,               -- 1 or 2
    quarter         TINYINT         NOT NULL,               -- 1-4
    quarter_name    VARCHAR(6)      NOT NULL,               -- 'Q1'...'Q4'
    -- Month / Tháng
    month           TINYINT         NOT NULL,
    month_name      VARCHAR(10)     NOT NULL,
    month_name_vi   VARCHAR(20)     NOT NULL,               -- Vietnamese month name
    month_short     CHAR(3)         NOT NULL,               -- 'Jan','Feb',...
    -- Week / Tuần
    week_of_year    TINYINT         NOT NULL,
    day_of_week     TINYINT         NOT NULL,               -- 1=Monday, 7=Sunday
    day_name        VARCHAR(10)     NOT NULL,
    day_name_vi     VARCHAR(15)     NOT NULL,
    -- Day / Ngày
    day_of_month    TINYINT         NOT NULL,
    day_of_year     SMALLINT        NOT NULL,
    -- Flags / Cờ
    is_weekend      TINYINT(1)      NOT NULL DEFAULT 0,
    is_holiday_vn   TINYINT(1)      NOT NULL DEFAULT 0,    -- Vietnamese public holidays
    fiscal_year     SMALLINT        NOT NULL,               -- Fiscal year (April start)
    fiscal_quarter  TINYINT         NOT NULL,
    PRIMARY KEY (date_key),
    UNIQUE KEY uq_dim_date_full_date (full_date),
    KEY idx_dim_date_year_month (year, month),
    KEY idx_dim_date_quarter    (year, quarter)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================================
-- dim_customer — Dimension khách hàng (SCD Type 2)
-- Slowly Changing Dimension Type 2 — tracks historical changes
-- SCD Loại 2 — theo dõi thay đổi lịch sử
-- =============================================================================
CREATE TABLE dim_customer (
    customer_sk         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, -- Surrogate key / Khóa thay thế
    customer_nk         BIGINT UNSIGNED NOT NULL,               -- Natural key from OLTP / Khóa tự nhiên từ OLTP
    customer_uuid       CHAR(36)        NOT NULL,
    email               VARCHAR(255)    NOT NULL,
    full_name           VARCHAR(255)    NOT NULL,
    city                VARCHAR(100)    NULL,
    country             CHAR(2)         NULL,
    segment             VARCHAR(50)     NULL,                   -- 'vip','regular','new'
    -- SCD Type 2 columns / Cột SCD Loại 2
    effective_from      DATE            NOT NULL,
    effective_to        DATE            NULL,                   -- NULL = current record / NULL = bản ghi hiện tại
    is_current          TINYINT(1)      NOT NULL DEFAULT 1,
    -- ETL metadata / Metadata ETL
    dw_inserted_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_sk),
    KEY idx_dim_customer_nk          (customer_nk),
    KEY idx_dim_customer_is_current  (is_current),
    KEY idx_dim_customer_email       (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================================
-- dim_product — Dimension sản phẩm (SCD Type 2)
-- =============================================================================
CREATE TABLE dim_product (
    product_sk          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_nk          BIGINT UNSIGNED NOT NULL,
    sku                 VARCHAR(100)    NOT NULL,
    product_name        VARCHAR(500)    NOT NULL,
    category_name       VARCHAR(255)    NULL,
    category_path       VARCHAR(500)    NULL,               -- 'Electronics > Phones > Android'
    brand               VARCHAR(100)    NULL,
    unit_price          DECIMAL(12,2)   NOT NULL,
    effective_from      DATE            NOT NULL,
    effective_to        DATE            NULL,
    is_current          TINYINT(1)      NOT NULL DEFAULT 1,
    dw_inserted_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_sk),
    KEY idx_dim_product_nk         (product_nk),
    KEY idx_dim_product_sku        (sku),
    KEY idx_dim_product_is_current (is_current)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================================
-- dim_payment_method — Dimension phương thức thanh toán
-- =============================================================================
CREATE TABLE dim_payment_method (
    payment_method_sk   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    method_code         VARCHAR(50)     NOT NULL,
    method_name         VARCHAR(100)    NOT NULL,
    method_name_vi      VARCHAR(100)    NOT NULL,
    gateway             VARCHAR(50)     NULL,
    is_online           TINYINT(1)      NOT NULL DEFAULT 1,
    PRIMARY KEY (payment_method_sk),
    UNIQUE KEY uq_dim_payment_method_code (method_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================================
-- dim_geography — Dimension địa lý
-- =============================================================================
CREATE TABLE dim_geography (
    geography_sk    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    city            VARCHAR(100)    NOT NULL,
    province        VARCHAR(100)    NULL,
    country_code    CHAR(2)         NOT NULL,
    country_name    VARCHAR(100)    NOT NULL,
    region          VARCHAR(50)     NULL,                   -- 'North','Central','South'
    PRIMARY KEY (geography_sk),
    KEY idx_dim_geography_country (country_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================================
-- fact_sales — Bảng thực tế bán hàng (grain: one row per order_item)
-- Grain: one row per order line item / Độ hạt: một hàng mỗi dòng đơn hàng
-- =============================================================================
CREATE TABLE fact_sales (
    sale_sk             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    -- Foreign keys to dimensions / Khóa ngoại tới dimension
    date_key            INT UNSIGNED    NOT NULL,           -- FK to dim_date
    customer_sk         BIGINT UNSIGNED NOT NULL,           -- FK to dim_customer
    product_sk          BIGINT UNSIGNED NOT NULL,           -- FK to dim_product
    payment_method_sk   INT UNSIGNED    NULL,               -- FK to dim_payment_method
    geography_sk        INT UNSIGNED    NULL,               -- FK to dim_geography
    -- Degenerate dimensions / Dimension suy biến
    order_nk            BIGINT UNSIGNED NOT NULL,           -- Order ID from OLTP
    order_uuid          CHAR(36)        NOT NULL,
    order_item_nk       BIGINT UNSIGNED NOT NULL,
    -- Measures / Số liệu đo lường
    quantity            INT UNSIGNED    NOT NULL,
    unit_price          DECIMAL(12,2)   NOT NULL,
    discount_amount     DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    subtotal_amount     DECIMAL(14,2)   NOT NULL,           -- After discount
    tax_amount          DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    shipping_amount     DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    gross_revenue       DECIMAL(14,2)   NOT NULL,
    net_revenue         DECIMAL(14,2)   NOT NULL,           -- After discounts
    -- Source tracking / Theo dõi nguồn
    order_source        VARCHAR(50)     NOT NULL,
    -- ETL tracking
    dw_inserted_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (sale_sk,date_key),
    KEY idx_fact_sales_date_key         (date_key),
    KEY idx_fact_sales_customer_sk      (customer_sk),
    KEY idx_fact_sales_product_sk       (product_sk),
    KEY idx_fact_sales_order_nk         (order_nk),
    KEY idx_fact_sales_date_product     (date_key, product_sk),
    KEY idx_fact_sales_date_customer    (date_key, customer_sk)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
PARTITION BY RANGE (date_key) (
    PARTITION p2020 VALUES LESS THAN (20210101),
    PARTITION p2021 VALUES LESS THAN (20220101),
    PARTITION p2022 VALUES LESS THAN (20230101),
    PARTITION p2023 VALUES LESS THAN (20240101),
    PARTITION p2024 VALUES LESS THAN (20250101),
    PARTITION p2025 VALUES LESS THAN (20260101),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- =============================================================================
-- fact_payments — Bảng thực tế thanh toán (grain: one row per payment)
-- =============================================================================
CREATE TABLE fact_payments (
    payment_sk          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    date_key            INT UNSIGNED    NOT NULL,
    customer_sk         BIGINT UNSIGNED NOT NULL,
    payment_method_sk   INT UNSIGNED    NULL,
    geography_sk        INT UNSIGNED    NULL,
    -- Degenerate dimensions
    payment_nk          BIGINT UNSIGNED NOT NULL,
    order_nk            BIGINT UNSIGNED NOT NULL,
    -- Measures
    payment_amount      DECIMAL(14,2)   NOT NULL,
    is_successful       TINYINT(1)      NOT NULL,
    processing_time_ms  INT             NULL,
    -- ETL tracking
    dw_inserted_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (payment_sk),
    KEY idx_fact_payments_date_key     (date_key),
    KEY idx_fact_payments_customer_sk  (customer_sk),
    KEY idx_fact_payments_method_sk    (payment_method_sk)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================================================
-- agg_daily_sales — Pre-aggregated daily sales (materialized aggregate)
-- Tổng hợp bán hàng hàng ngày đã được vật thể hóa
-- =============================================================================
CREATE TABLE agg_daily_sales (
    date_key            INT UNSIGNED    NOT NULL,
    product_sk          BIGINT UNSIGNED NOT NULL,
    orders_count        INT UNSIGNED    NOT NULL DEFAULT 0,
    units_sold          INT UNSIGNED    NOT NULL DEFAULT 0,
    gross_revenue       DECIMAL(16,2)   NOT NULL DEFAULT 0.00,
    net_revenue         DECIMAL(16,2)   NOT NULL DEFAULT 0.00,
    avg_order_value     DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    refreshed_at        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (date_key, product_sk)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

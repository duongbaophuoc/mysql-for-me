-- =============================================================================
-- dbt Mart Model: Daily Sales Fact
-- Mô Hình Mart: Thực Tế Bán Hàng Hàng Ngày
--
-- Grain: one row per order_item per day
-- Materialized: incremental (append new days)
-- =============================================================================

{{ config(
    materialized = 'incremental',
    unique_key   = 'order_item_nk',
    on_schema_change = 'append_new_columns',
    tags = ['daily', 'sales', 'mart']
) }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
    {% if is_incremental() %}
    -- Only process new/updated records / Chỉ xử lý bản ghi mới/cập nhật
    WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
    {% endif %}
),

items AS (
    SELECT
        oi.id               AS order_item_nk,
        oi.order_id,
        oi.product_id       AS product_nk,
        oi.quantity,
        oi.unit_price,
        oi.line_total       AS gross_revenue,
        oi.discount_pct,
        oi.line_total * (1 - oi.discount_pct / 100.0) AS net_revenue
    FROM {{ source('shop_db', 'order_items') }} oi
),

customers AS (
    SELECT customer_nk, customer_sk
    FROM {{ ref('dim_customer') }}
    WHERE is_current = 1
),

products AS (
    SELECT product_nk, product_sk
    FROM {{ ref('dim_product') }}
    WHERE is_current = 1
),

dates AS (
    SELECT date_key, full_date FROM {{ ref('dim_date') }}
)

SELECT
    -- Keys / Khóa
    i.order_item_nk,
    d.date_key,
    c.customer_sk,
    p.product_sk,
    o.order_nk,

    -- Measures / Số liệu
    i.quantity                              AS quantity_sold,
    i.unit_price,
    i.gross_revenue,
    i.discount_pct,
    i.net_revenue,
    i.gross_revenue - i.net_revenue         AS discount_amount,

    -- Metadata / Siêu dữ liệu
    o.order_status,
    o.payment_method,
    NOW()                                   AS dw_inserted_at

FROM orders o
JOIN items     i ON i.order_id     = o.order_nk
JOIN customers c ON c.customer_nk  = o.customer_nk
JOIN products  p ON p.product_nk   = i.product_nk
JOIN dates     d ON d.full_date    = DATE(o.created_at)

WHERE o.order_status = 'delivered'  -- only count fulfilled orders

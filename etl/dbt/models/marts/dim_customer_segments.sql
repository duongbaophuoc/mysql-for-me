-- =============================================================================
-- dbt Mart Model: Customer Segments
-- Mô Hình Mart: Phân Khúc Khách Hàng (RFM Analysis)
--
-- RFM = Recency, Frequency, Monetary
-- Grain: one row per customer
-- Materialized: table (rebuilt daily)
-- =============================================================================

{{ config(
    materialized = 'table',
    tags = ['daily', 'customers', 'segmentation']
) }}

WITH customer_orders AS (
    SELECT
        customer_sk,
        COUNT(DISTINCT order_nk)                AS frequency,
        SUM(gross_revenue)                      AS monetary,
        MAX(d.full_date)                        AS last_order_date,
        MIN(d.full_date)                        AS first_order_date,
        DATEDIFF(CURRENT_DATE(), MAX(d.full_date)) AS recency_days
    FROM {{ ref('fct_daily_sales') }} fs
    JOIN {{ ref('dim_date') }} d ON d.date_key = fs.date_key
    GROUP BY customer_sk
),

rfm_scores AS (
    SELECT
        customer_sk,
        frequency,
        monetary,
        last_order_date,
        first_order_date,
        recency_days,
        -- Recency score: lower days = higher score / Ít ngày hơn = điểm cao hơn
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        -- Frequency score: higher orders = higher score
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        -- Monetary score: higher spend = higher score
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM customer_orders
),

segmented AS (
    SELECT
        *,
        CONCAT(r_score, f_score, m_score) AS rfm_cell,
        r_score + f_score + m_score       AS rfm_total,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN 'Champions'                         -- Nhà Vô Địch
            WHEN r_score >= 3 AND f_score >= 3
                THEN 'Loyal Customers'                   -- Khách Hàng Trung Thành
            WHEN r_score >= 4 AND f_score <= 2
                THEN 'Recent Customers'                  -- Khách Hàng Mới
            WHEN r_score <= 2 AND f_score >= 3
                THEN 'At Risk'                           -- Có Nguy Cơ
            WHEN r_score = 1
                THEN 'Lost'                              -- Đã Mất
            ELSE 'Potential'                             -- Tiềm Năng
        END AS segment,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN 'Nhà Vô Địch'
            WHEN r_score >= 3 AND f_score >= 3
                THEN 'Khách Hàng Trung Thành'
            WHEN r_score >= 4 AND f_score <= 2
                THEN 'Khách Hàng Mới'
            WHEN r_score <= 2 AND f_score >= 3
                THEN 'Có Nguy Cơ'
            WHEN r_score = 1
                THEN 'Đã Mất'
            ELSE 'Tiềm Năng'
        END AS segment_vi
    FROM rfm_scores
)

SELECT
    s.*,
    dc.full_name,
    dc.email,
    dc.city,
    NOW() AS dw_inserted_at
FROM segmented s
JOIN {{ ref('dim_customer') }} dc ON dc.customer_sk = s.customer_sk AND dc.is_current = 1

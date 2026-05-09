-- =============================================================================
-- dbt Staging Model: Customers
-- Mô Hình Staging: Khách Hàng
--
-- Source: shop_db.customers
-- Output: analytics_dw staging
-- Schedule: Daily / Hàng ngày
-- =============================================================================

WITH source AS (
    -- Raw customers from OLTP / Khách hàng thô từ OLTP
    SELECT
        id              AS customer_nk,
        uuid            AS customer_uuid,
        email,
        full_name,
        phone,
        date_of_birth,
        status,
        created_at,
        updated_at,
        deleted_at
    FROM {{ source('shop_db', 'customers') }}
    WHERE deleted_at IS NULL   -- active customers only / chỉ khách hàng active
),

with_address AS (
    -- Join default address / Nối địa chỉ mặc định
    SELECT
        c.*,
        a.address_line  AS address,
        a.city,
        a.province,
        a.country       AS country_code
    FROM source c
    LEFT JOIN {{ source('shop_db', 'customer_addresses') }} a
        ON  a.customer_id = c.customer_nk
        AND a.is_default  = 1
)

SELECT
    customer_nk,
    customer_uuid,
    LOWER(TRIM(email))                              AS email,
    TRIM(full_name)                                 AS full_name,
    phone,
    date_of_birth,
    DATEDIFF(CURRENT_DATE(), date_of_birth) / 365   AS age_years,
    status,
    city,
    COALESCE(country_code, 'VN')                    AS country_code,
    created_at,
    updated_at,
    -- Derived flags / Cờ dẫn xuất
    CASE WHEN status = 'active' THEN 1 ELSE 0 END  AS is_active,
    CASE WHEN DATEDIFF(NOW(), created_at) <= 30
         THEN 1 ELSE 0 END                          AS is_new_customer

FROM with_address

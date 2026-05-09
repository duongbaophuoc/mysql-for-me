-- =============================================================================
-- dbt Staging Model: Products
-- Mô Hình Staging: Sản Phẩm
--
-- Source: shop_db.products + shop_db.categories
-- =============================================================================

WITH source AS (
    SELECT
        p.id            AS product_nk,
        p.uuid          AS product_uuid,
        p.sku,
        p.name          AS product_name,
        p.description,
        p.price         AS unit_price,
        p.cost_price,
        p.status,
        p.stock_quantity,
        p.category_id,
        p.created_at,
        p.updated_at
    FROM {{ source('shop_db', 'products') }} p
    WHERE p.status IN ('active', 'inactive')  -- exclude archived
),

with_category AS (
    SELECT
        s.*,
        c.name          AS category_name,
        c.slug          AS category_slug,
        pc.name         AS parent_category_name
    FROM source s
    LEFT JOIN {{ source('shop_db', 'categories') }} c  ON c.id = s.category_id
    LEFT JOIN {{ source('shop_db', 'categories') }} pc ON pc.id = c.parent_id
)

SELECT
    product_nk,
    product_uuid,
    sku,
    product_name,
    COALESCE(category_name, 'Uncategorized')    AS category_name,
    category_slug,
    COALESCE(parent_category_name, category_name) AS top_category,
    unit_price,
    cost_price,
    CASE
        WHEN cost_price > 0
        THEN ROUND((unit_price - cost_price) / unit_price * 100, 2)
        ELSE NULL
    END                                          AS margin_pct,
    status,
    stock_quantity,
    CASE WHEN stock_quantity = 0       THEN 'out_of_stock'
         WHEN stock_quantity < 10     THEN 'low_stock'
         WHEN stock_quantity < 100    THEN 'adequate'
         ELSE                              'well_stocked'
    END                                          AS stock_status,
    created_at,
    updated_at

FROM with_category

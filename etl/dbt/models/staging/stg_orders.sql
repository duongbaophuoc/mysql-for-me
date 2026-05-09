-- =============================================================================
-- dbt Model: stg_orders
-- Staging model that cleanses and standardizes orders from shop_db
-- Model staging chuẩn hóa đơn hàng từ shop_db
-- =============================================================================

{{
    config(
        materialized='view',
        tags=['staging', 'orders']
    )
}}

with source as (

    -- Pull from shop_db directly / Kéo trực tiếp từ shop_db
    select * from {{ source('shop_db', 'orders') }}

),

renamed as (

    select
        -- Primary identifiers / Định danh chính
        id                                      as order_id,
        uuid                                    as order_uuid,
        customer_id,

        -- Status / Trạng thái
        status                                  as order_status,

        -- Financial amounts / Số tiền tài chính
        subtotal                                as order_subtotal,
        discount_amount,
        tax_amount,
        shipping_amount,
        total_amount                            as order_total,
        currency,

        -- Channel / Kênh bán
        source                                  as order_source,

        -- Dates / Ngày tháng
        created_at                              as order_created_at,
        updated_at                              as order_updated_at,

        -- Derived fields / Trường phái sinh
        DATE(created_at)                        as order_date,
        YEAR(created_at)                        as order_year,
        MONTH(created_at)                       as order_month,
        DAYOFWEEK(created_at)                   as order_day_of_week,

        -- Flags / Cờ
        CASE
            WHEN status IN ('delivered', 'completed') THEN TRUE
            ELSE FALSE
        END                                     as is_completed,

        CASE
            WHEN status = 'cancelled' THEN TRUE
            ELSE FALSE
        END                                     as is_cancelled,

        -- ETL metadata / Metadata ETL
        CURRENT_TIMESTAMP()                     as dbt_loaded_at

    from source
    where
        -- Exclude cancelled orders from reporting unless specifically needed
        -- Loại trừ đơn hàng đã hủy khỏi báo cáo trừ khi cần cụ thể
        status != 'cancelled'

)

select * from renamed

-- Test this model with: dbt test -s stg_orders
-- dbt tests (in schema.yml):
--   - unique: order_id
--   - not_null: order_id
--   - not_null: customer_id
--   - accepted_values: order_status ['pending','confirmed','processing','shipped','delivered']

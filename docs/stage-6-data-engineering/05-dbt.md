# dbt with MySQL / dbt Với MySQL

## Overview / Tổng Quan

**dbt (data build tool)** is the SQL-first transformation framework for analytics engineering. It brings software engineering practices (version control, testing, documentation) to SQL.
_**dbt** là framework transformation SQL-first cho data engineering. Nó đưa thực hành kỹ thuật phần mềm vào SQL._

---

## dbt Concepts / Khái Niệm dbt

```
Source    → Raw tables in MySQL (shop_db.orders, shop_db.customers)
Model     → SQL files that define transformations (SELECT queries)
Test      → Assertions about your data (not null, unique, accepted values)
Snapshot  → SCD Type 2 history tracking
Seed      → CSV files loaded as reference tables
```

---

## Project Structure / Cấu Trúc Dự Án

```
etl/dbt/
├── dbt_project.yml          ← project config (already created)
├── models/
│   ├── staging/             ← 1:1 with sources, light cleaning
│   │   ├── stg_orders.sql   ← already created
│   │   └── schema.yml       ← tests and documentation
│   ├── intermediate/        ← business logic
│   │   └── int_order_items_enriched.sql
│   └── marts/               ← analytics-ready
│       ├── fct_sales.sql
│       └── dim_customer.sql
└── profiles.yml             ← database connections
```

---

## profiles.yml for MySQL / profiles.yml Cho MySQL

```yaml
# ~/.dbt/profiles.yml (outside project, contains secrets)
mysql_roadmap:
  target: dev
  outputs:
    dev:
      type: mysql
      server: 127.0.0.1
      port: 3306
      schema: analytics_dw
      username: root
      password: secret
      ssl_disabled: true
    prod:
      type: mysql
      server: mysql-primary.internal
      port: 3306
      schema: analytics_dw
      username: dbt_user
      password: "{{ env_var('DBT_PASSWORD') }}"
      ssl_disabled: false
```

---

## Key dbt Commands / Lệnh dbt Quan Trọng

```bash
# Install dbt-mysql / Cài đặt dbt-mysql
pip install dbt-mysql

# Test connection / Kiểm tra kết nối
dbt debug

# Run all models / Chạy tất cả model
dbt run

# Run specific model / Chạy model cụ thể
dbt run --select stg_orders

# Run with dependencies / Chạy với phụ thuộc
dbt run --select +fct_sales  # fct_sales and all upstream

# Test data quality / Kiểm tra chất lượng dữ liệu
dbt test

# Generate documentation / Tạo tài liệu
dbt docs generate
dbt docs serve   # opens browser at localhost:8080

# Show DAG of models / Hiển thị DAG model
dbt ls --select +fct_sales
```

---

## Test Configuration / Cấu Hình Test

```yaml
# models/staging/schema.yml
version: 2

models:
  - name: stg_orders
    description: "Cleaned orders from shop_db"
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: order_status
        tests:
          - accepted_values:
              values: ['pending','confirmed','processing','shipped','delivered']
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('stg_customers')
              field: customer_id
```

---

## Incremental Models / Model Gia Tăng

```sql
-- models/marts/fct_sales.sql
{{ config(
    materialized='incremental',
    unique_key='sale_sk',
    on_schema_change='append_new_columns'
) }}

SELECT
    {{ dbt_utils.generate_surrogate_key(['order_id', 'product_id']) }} AS sale_sk,
    date_key,
    customer_sk,
    product_sk,
    gross_revenue,
    net_revenue
FROM {{ ref('stg_orders') }}
JOIN {{ ref('dim_customer') }} USING (customer_nk)

{% if is_incremental() %}
-- Only load new/updated records / Chỉ nạp bản ghi mới/cập nhật
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

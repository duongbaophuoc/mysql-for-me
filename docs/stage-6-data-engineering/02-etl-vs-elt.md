# ETL vs ELT / ETL vs ELT

## Overview / Tổng Quan

Both are data integration patterns that move data from source systems to analytics destinations.
_Cả hai là mẫu tích hợp dữ liệu di chuyển dữ liệu từ hệ thống nguồn đến đích phân tích._

---

## ETL — Extract, Transform, Load

```
Source DB          Transformation Layer      Data Warehouse
(MySQL shop_db)    (Python/Spark/dbt)        (analytics_dw)
     │                     │                      │
  Extract ────────────► Transform ──────────► Load
  raw data                cleaned,                 final
                           enriched                 data
```

**Transform BEFORE loading** — data is cleaned before it reaches the warehouse.
_**Biến đổi TRƯỚC khi nạp** — dữ liệu được làm sạch trước khi đến kho._

```python
# ETL example / Ví dụ ETL
def etl_orders():
    # Extract / Trích xuất
    raw_orders = source_db.query("SELECT * FROM orders WHERE updated_at > ?", last_run)
    
    # Transform / Biến đổi
    cleaned = []
    for order in raw_orders:
        cleaned.append({
            'date_key':   order['created_at'].strftime('%Y%m%d'),
            'net_revenue': order['total_amount'] - order['discount_amount'],
            'is_weekend':  order['created_at'].weekday() >= 5
        })
    
    # Load / Nạp
    warehouse_db.bulk_insert('fact_sales', cleaned)
```

---

## ELT — Extract, Load, Transform

```
Source DB          Data Warehouse        Transformation (SQL)
(MySQL shop_db)    (analytics_dw)
     │                    │                     │
  Extract ──────────► Load raw ──────────► Transform
  raw data               into staging           into final tables
                         schema                  (dbt, SQL)
```

**Load FIRST, transform inside the warehouse using SQL.**
_**Nạp TRƯỚC, biến đổi bên trong kho sử dụng SQL.**_

```sql
-- ELT: raw data arrives in staging / Dữ liệu thô vào staging
-- Then transform using dbt / Sau đó biến đổi bằng dbt
CREATE TABLE stg_orders AS SELECT * FROM raw_orders;

-- Transform in-warehouse / Biến đổi trong kho
INSERT INTO fact_sales
SELECT
    DATE_FORMAT(created_at, '%Y%m%d'),
    customer_sk,
    total_amount - discount_amount
FROM stg_orders
JOIN dim_customer USING (customer_nk);
```

---

## Comparison / So Sánh

| Aspect | ETL | ELT |
|--------|-----|-----|
| Where transform | Outside DB | Inside DB |
| Tools | Python, Spark, Informatica | SQL, dbt |
| Latency | Higher (pre-processing) | Lower (load first) |
| Raw data preserved | ❌ | ✅ (staging) |
| Scalability | Limited by transform layer | Scales with DW |
| Best for | Complex transformations | SQL-friendly DWs |
| MySQL use case | ✅ for small-medium | ✅ dbt on analytics_dw |

---

## dbt makes ELT Easy / dbt Làm ELT Dễ Dàng

```sql
-- models/marts/sales/fct_daily_sales.sql (already in etl/dbt/)
-- dbt transforms data using SQL models
SELECT
    date_key,
    product_sk,
    SUM(gross_revenue)  AS gross_revenue,
    SUM(net_revenue)    AS net_revenue,
    COUNT(*)            AS order_count
FROM {{ ref('stg_orders') }}
GROUP BY date_key, product_sk
```

```bash
dbt run --select fct_daily_sales       # transform / biến đổi
dbt test --select fct_daily_sales      # validate / kiểm tra
dbt docs generate && dbt docs serve    # document / tạo tài liệu
```

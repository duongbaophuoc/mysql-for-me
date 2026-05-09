# 🟤 Stage 6 — Data Engineering & Warehousing
# 🟤 Giai Đoạn 6 — Kỹ Thuật Dữ Liệu & Kho Dữ Liệu

> **"Raw data is not useful. Transformed, modeled, and pipeline-driven data is."**
> _"Dữ liệu thô không hữu ích. Dữ liệu được biến đổi, mô hình hóa và vận hành qua pipeline mới có giá trị."_

## Overview / Tổng Quan

This stage bridges MySQL as an OLTP system with MySQL (and other systems) as an analytical platform. You'll learn ETL, CDC pipelines, data warehouse modeling, dbt, and Airflow.
_Giai đoạn này kết nối MySQL như hệ thống OLTP với nền tảng phân tích._

## Topics / Chủ Đề

| File | Topic | Level |
|------|-------|-------|
| [01-warehouse-modeling.md](01-warehouse-modeling.md) | Star schema, fact & dim tables | Data Platform |
| [02-etl-vs-elt.md](02-etl-vs-elt.md) | ETL vs ELT architectural differences | Data Platform |
| [03-incremental-loading.md](03-incremental-loading.md) | Delta loads, watermarks, CDC-based | Data Platform |
| [04-cdc-pipelines.md](04-cdc-pipelines.md) | Binlog-based pipeline design | Data Platform |
| [05-dbt.md](05-dbt.md) | dbt models, tests, lineage | Data Platform |
| [06-airflow.md](06-airflow.md) | DAGs, operators, scheduling | Data Platform |
| [07-spark-integration.md](07-spark-integration.md) | MySQL ↔ Spark data exchange | Data Platform |
| [08-bi-integration.md](08-bi-integration.md) | Tableau, Power BI, Metabase | Data Platform |

## Learning Outcomes / Kết Quả Học Tập

- ✅ Design star schema data warehouses on MySQL
- ✅ Build incremental ETL pipelines
- ✅ Implement CDC-based real-time data ingestion
- ✅ Write dbt models for warehouse transformations
- ✅ Orchestrate data pipelines with Airflow
- ✅ Connect MySQL to BI tools for reporting

## Data Pipeline Architecture / Kiến Trúc Data Pipeline

```
┌─────────────┐   CDC/ETL   ┌───────────────┐   Transform   ┌──────────────┐
│  shop_db    │ ──────────► │   Staging     │ ────────────► │ analytics_dw │
│  (OLTP)     │             │   Layer       │    (dbt)       │  (Warehouse) │
└─────────────┘             └───────────────┘               └──────┬───────┘
                                                                   │
                                                          ┌────────▼────────┐
                                                          │   BI Tools      │
                                                          │  Tableau/PowerBI│
                                                          └─────────────────┘

Orchestrated by / Điều phối bởi: Apache Airflow DAGs
```

## ETL vs ELT Comparison / So Sánh ETL vs ELT

| Aspect | ETL | ELT |
|--------|-----|-----|
| Transform location | Outside DB / Ngoài DB | Inside warehouse / Trong kho |
| Tool | Python, Spark | dbt, SQL |
| Speed | Slower setup | Faster with modern warehouses |
| Flexibility | High | High |
| Best for | Legacy systems | Cloud DWs (Snowflake, BigQuery) |
| MySQL use | Source | Source + intermediate |

## Next Stage / Giai Đoạn Tiếp Theo

→ [Stage 7 — Observability & SRE](../stage-7-observability/README.md)

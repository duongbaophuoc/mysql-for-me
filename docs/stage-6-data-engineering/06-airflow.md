# Airflow for MySQL ETL / Airflow Cho ETL MySQL

## Overview / Tổng Quan

Apache Airflow is a workflow orchestration platform. For MySQL ETL, it schedules and monitors data pipelines between `shop_db` and `analytics_dw`.
_Apache Airflow là nền tảng điều phối workflow. Cho ETL MySQL, nó lên lịch và giám sát pipeline dữ liệu._

---

## Core Concepts / Khái Niệm Cốt Lõi

```python
DAG (Directed Acyclic Graph) / Đồ thị có hướng phi chu trình:
  - One DAG = One pipeline / Một DAG = Một pipeline
  - Contains tasks in dependency order / Chứa task theo thứ tự phụ thuộc

Task types for MySQL:
  MySqlOperator   → Execute SQL on MySQL
  MySqlSensor     → Wait for condition to be true
  PythonOperator  → Execute Python (read/transform/write)
```

---

## Connection Setup / Thiết Lập Kết Nối

```bash
# In Airflow Admin → Connections / Trong Airflow Admin → Connections
# Add connection: mysql_shop_db
Conn Id:   mysql_shop_db
Conn Type: MySQL
Host:      127.0.0.1
Schema:    shop_db
Login:     root
Password:  secret
Port:      3306

# Add connection: mysql_analytics_dw
Conn Id:   mysql_analytics_dw
Conn Type: MySQL
Host:      127.0.0.1
Schema:    analytics_dw
Login:     root
Password:  secret
Port:      3306
```

---

## DAG Example (Already Created) / DAG Đã Tạo

See `etl/airflow/dags/mysql_to_warehouse.py` for the complete ETL DAG.
_Xem `etl/airflow/dags/mysql_to_warehouse.py` cho DAG ETL đầy đủ._

```python
# DAG structure / Cấu trúc DAG:
check_source >> extract_orders >> load_to_warehouse >> refresh_aggregates

# Schedule: 2:00 AM daily / Lịch: 2 giờ sáng hàng ngày
schedule_interval='0 2 * * *'
```

---

## Running Airflow with Docker / Chạy Airflow Với Docker

```bash
# Quick start / Khởi động nhanh
docker compose -f etl/airflow/docker-compose.yml up -d

# Access UI / Truy cập UI
http://localhost:8080
# Login: airflow / airflow

# Trigger DAG manually / Kích hoạt DAG thủ công
airflow dags trigger mysql_to_warehouse_daily

# Check DAG status / Kiểm tra trạng thái DAG
airflow dags state mysql_to_warehouse_daily $(date +%Y-%m-%d)
```

---

## Monitoring ETL Health / Giám Sát Sức Khỏe ETL

```sql
-- Check if ETL ran successfully / Kiểm tra ETL chạy thành công
SELECT
    MAX(dw_inserted_at)                        AS last_etl_run,
    TIMESTAMPDIFF(HOUR, MAX(dw_inserted_at), NOW()) AS hours_since_last_run,
    COUNT(*)                                   AS total_fact_rows
FROM analytics_dw.fact_sales;
-- If hours_since_last_run > 25 → ETL may have failed!

-- Check for data gaps / Kiểm tra khoảng trống dữ liệu
SELECT date_key, COUNT(*) AS rows_loaded
FROM analytics_dw.fact_sales
WHERE date_key >= DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 7 DAY), '%Y%m%d')
GROUP BY date_key
ORDER BY date_key;
-- All recent dates should have rows / Tất cả ngày gần đây phải có hàng
```

---

## Best Practices / Thực Hành Tốt Nhất

1. **Idempotent tasks**: Re-running should produce same result / Chạy lại cho cùng kết quả  
2. **Use XComs sparingly**: Pass large data via DB, not Airflow metadata  
3. **Set SLAs**: Alert if task doesn't complete within expected time  
4. **Watermarks**: Track last processed timestamp in DB, not Airflow  
5. **Backfill support**: Design DAGs to handle historical date ranges

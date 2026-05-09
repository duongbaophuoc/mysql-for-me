# BI Integration with MySQL / Tích Hợp BI Với MySQL

## Overview / Tổng Quan

Business Intelligence (BI) tools connect to MySQL (usually `analytics_dw`) to provide self-service dashboards and reports to non-technical users.
_Công cụ Phân tích Kinh doanh (BI) kết nối với MySQL để cung cấp dashboard và báo cáo tự phục vụ cho người dùng không kỹ thuật._

---

## Popular BI Tools for MySQL / Công Cụ BI Phổ Biến Cho MySQL

| Tool | Type | MySQL Support | Best For |
|------|------|--------------|----------|
| **Metabase** | Open source | ✅ Native | Self-hosted BI, SQL-friendly teams |
| **Grafana** | Open source | ✅ MySQL datasource | Operations, metrics |
| **Apache Superset** | Open source | ✅ SQLAlchemy | Enterprise, data teams |
| **Tableau** | Commercial | ✅ Connector | Large enterprises |
| **Power BI** | Commercial | ✅ MySQL driver | Microsoft ecosystem |
| **Redash** | Open source | ✅ | SQL-focused teams |
| **Google Looker** | Commercial | ✅ | Google Cloud |

**Recommended for this roadmap**: Metabase or Grafana (both already in docker-compose).
_**Khuyến nghị cho roadmap này**: Metabase hoặc Grafana (cả hai đã có trong docker-compose)._

---

## Connecting Metabase to analytics_dw / Kết Nối Metabase Với analytics_dw

```bash
# Start Metabase / Khởi động Metabase
docker run -d -p 3000:3000 \
  -e MB_DB_TYPE=h2 \
  -e MB_DB_FILE=/metabase-data/metabase.db \
  --name metabase metabase/metabase

# Access / Truy cập: http://localhost:3000
# Setup → Add Database → MySQL
# Host: mysql-primary
# Database: analytics_dw
# Username: report_user
# Password: report_password
```

---

## Read-Only Reporting User / User Báo Cáo Chỉ Đọc

```sql
-- Create dedicated read-only user for BI tools / Tạo user chỉ đọc riêng cho BI
CREATE USER 'bi_user'@'%'
    IDENTIFIED BY 'bi_readonly_password'
    PASSWORD EXPIRE INTERVAL 90 DAY;

GRANT SELECT ON analytics_dw.* TO 'bi_user'@'%';
-- ONLY on analytics_dw — never on shop_db (OLTP)! / CHỈ analytics_dw, không bao giờ shop_db!

-- Optionally: limit query concurrency / Giới hạn đồng thời truy vấn
ALTER USER 'bi_user'@'%'
    WITH MAX_QUERIES_PER_HOUR 1000
         MAX_CONNECTIONS_PER_HOUR 50;
```

---

## Performance Tips for BI Workloads / Mẹo Hiệu Năng Cho Workload BI

```sql
-- 1. Pre-aggregate for common queries / Tổng hợp trước cho truy vấn phổ biến
CREATE TABLE bi_daily_revenue AS
SELECT
    date_key,
    SUM(gross_revenue)  AS gross_revenue,
    SUM(net_revenue)    AS net_revenue,
    COUNT(DISTINCT customer_sk) AS unique_customers
FROM fact_sales
GROUP BY date_key;
-- Refresh nightly / Làm mới hàng đêm

-- 2. Create BI-friendly views / Tạo view thân thiện với BI
CREATE VIEW v_sales_by_category AS
SELECT
    d.date_key,
    CONCAT(d.year, '-', LPAD(d.month, 2, '0')) AS month_label,
    dp.category_name,
    SUM(fs.gross_revenue)                        AS revenue,
    SUM(fs.net_revenue)                          AS net_revenue,
    COUNT(*)                                     AS orders
FROM fact_sales fs
JOIN dim_date    d  ON d.date_key    = fs.date_key
JOIN dim_product dp ON dp.product_sk = fs.product_sk
WHERE dp.is_current = 1
GROUP BY d.date_key, month_label, dp.category_name;

-- 3. Separate BI replica / Replica BI riêng biệt
-- Dedicated MySQL replica for BI to avoid impacting OLTP
-- Replica MySQL riêng cho BI để không ảnh hưởng OLTP
```

---

## Common BI Queries on analytics_dw / Truy Vấn BI Thường Gặp

```sql
-- Monthly revenue trend / Xu hướng doanh thu hàng tháng
SELECT
    d.year,
    d.month,
    d.month_name_vi,
    SUM(fs.gross_revenue) AS revenue
FROM fact_sales fs
JOIN dim_date d ON d.date_key = fs.date_key
WHERE d.year = 2024
GROUP BY d.year, d.month, d.month_name_vi
ORDER BY d.month;

-- Top 10 products by revenue / Top 10 sản phẩm theo doanh thu
SELECT
    dp.product_name,
    dp.category_name,
    SUM(fs.gross_revenue)  AS total_revenue,
    SUM(fs.quantity_sold)  AS units_sold
FROM fact_sales fs
JOIN dim_product dp ON dp.product_sk = fs.product_sk AND dp.is_current = 1
GROUP BY dp.product_sk, dp.product_name, dp.category_name
ORDER BY total_revenue DESC
LIMIT 10;

-- Customer cohort analysis / Phân tích cohort khách hàng
SELECT
    dc.registration_month,
    COUNT(DISTINCT fs.customer_sk) AS active_customers,
    SUM(fs.gross_revenue)          AS cohort_revenue
FROM fact_sales fs
JOIN dim_customer dc ON dc.customer_sk = fs.customer_sk AND dc.is_current = 1
GROUP BY dc.registration_month
ORDER BY dc.registration_month;
```

---

## Grafana MySQL Data Source / Nguồn Dữ Liệu MySQL Grafana

```yaml
# monitoring/grafana/datasources/analytics.yaml
apiVersion: 1
datasources:
  - name: analytics_dw
    type: mysql
    url: mysql-primary:3306
    database: analytics_dw
    user: bi_user
    secureJsonData:
      password: bi_readonly_password
    jsonData:
      maxOpenConns: 5
      maxIdleConns: 2
      connMaxLifetime: 14400
```

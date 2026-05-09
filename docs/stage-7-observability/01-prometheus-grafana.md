# Prometheus & Grafana for MySQL / Prometheus & Grafana Cho MySQL

## Overview / Tổng Quan

Prometheus scrapes metrics from MySQL, Grafana visualizes them. Together they provide the observability needed to run MySQL in production.
_Prometheus thu thập metric từ MySQL, Grafana trực quan hóa. Cùng nhau cung cấp khả năng quan sát cần thiết để vận hành MySQL production._

---

## Architecture / Kiến Trúc

```
MySQL ──────► mysqld_exporter ──► Prometheus ──► Grafana
             (port 9104)          (port 9090)     (port 3000)
             Translates MySQL     Stores metrics  Visualizes
             status to /metrics   time-series     dashboards
```

---

## mysqld_exporter Configuration / Cấu Hình mysqld_exporter

```bash
# Connection string file (don't put password in CLI args!)
# File chuỗi kết nối (đừng đặt mật khẩu trong CLI!)
cat > /etc/mysql-exporter.cnf << EOF
[client]
user     = exporter
password = exporter_password
host     = mysql-primary
port     = 3306
EOF

# Start exporter / Khởi động exporter
mysqld_exporter \
  --config.my-cnf=/etc/mysql-exporter.cnf \
  --collect.global_status \
  --collect.global_variables \
  --collect.slave_status \
  --collect.innodb_metrics \
  --collect.info_schema.tables \
  --collect.perf_schema.eventsstatements \
  --web.listen-address=:9104
```

---

## Key MySQL Metrics / Metric MySQL Quan Trọng

```promql
# Connection usage / Sử dụng kết nối
mysql_global_status_threads_connected
  / mysql_global_variables_max_connections * 100

# Buffer pool hit rate / Tỷ lệ hit buffer pool
(1 - rate(mysql_global_status_innodb_buffer_pool_reads[5m])
   / rate(mysql_global_status_innodb_buffer_pool_read_requests[5m])) * 100

# QPS by type / QPS theo loại truy vấn
rate(mysql_global_status_commands_total{command="select"}[1m])
rate(mysql_global_status_commands_total{command="insert"}[1m])
rate(mysql_global_status_commands_total{command="update"}[1m])
rate(mysql_global_status_commands_total{command="delete"}[1m])

# Replication lag / Độ trễ sao chép
mysql_slave_status_seconds_behind_master{instance="mysql-replica1"}

# Slow queries rate / Tỷ lệ truy vấn chậm
rate(mysql_global_status_slow_queries[5m])

# Lock waits / Chờ lock
mysql_global_status_innodb_row_lock_waits
mysql_global_status_innodb_row_lock_time_avg
```

---

## Grafana Dashboard Setup / Cài Đặt Dashboard Grafana

```bash
# Access Grafana / Truy cập Grafana
http://localhost:3000
# Default login: admin / admin

# Import MySQL dashboard / Import dashboard MySQL
# Dashboard ID: 7362 (MySQL Overview by Percona)
# or / hoặc: 14057 (MySQL Exporter Quickstart)

# Add Prometheus data source / Thêm nguồn dữ liệu Prometheus
# Settings → Data Sources → Add → Prometheus
# URL: http://prometheus:9090
```

---

## Key Dashboard Panels / Panel Dashboard Quan Trọng

```
Row 1: Overview / Tổng Quan
  - QPS (Queries Per Second)
  - Connections used %
  - Buffer pool hit rate %
  - Replication lag

Row 2: InnoDB Performance / Hiệu Năng InnoDB
  - Row operations (reads/inserts/updates/deletes)
  - Buffer pool pages (dirty/free/data)
  - Redo log writes/sec

Row 3: Slow Queries / Truy Vấn Chậm
  - Slow query count rate
  - Sort operations
  - Table scans (full table scans = red flag)

Row 4: Replication / Sao Chép (for replicas)
  - Seconds behind source
  - Relay log position
  - IO thread / SQL thread status
```

---

## Alerting via Grafana / Cảnh Báo Qua Grafana

```yaml
# Already defined in monitoring/alerts/mysql-alerts.yml
# Route alerts to: Slack, PagerDuty, Email
# See Alertmanager configuration
```

The monitoring stack is defined in `docker/docker-compose.monitoring.yml`.
_Stack giám sát được định nghĩa trong `docker/docker-compose.monitoring.yml`._

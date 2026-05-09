# MySQL Exporters / Exporter MySQL

## Overview / Tổng Quan

MySQL exporters translate MySQL internal metrics into Prometheus format for collection and alerting.
_Exporter MySQL dịch metric nội bộ MySQL sang định dạng Prometheus để thu thập và cảnh báo._

---

## mysqld_exporter — Primary Exporter

The official Prometheus exporter for MySQL.
_Exporter Prometheus chính thức cho MySQL._

### Create Monitoring User / Tạo User Giám Sát

```sql
-- Minimal privileges for monitoring / Quyền tối thiểu cho giám sát
CREATE USER 'exporter'@'localhost'
    IDENTIFIED BY 'exporter_password' WITH MAX_QUERIES_PER_HOUR 100;

GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';
GRANT SELECT ON performance_schema.* TO 'exporter'@'localhost';

FLUSH PRIVILEGES;
```

### Key Metric Collections / Thu Thập Metric Chính

```
--collect.global_status      → threads, queries, bytes in/out
--collect.global_variables   → buffer pool size, max connections
--collect.slave_status       → replication lag, IO/SQL thread
--collect.innodb_metrics     → buffer pool, row locks, checkpoints
--collect.perf_schema.*      → table IO, wait events, statement stats
--collect.info_schema.tables → table sizes, row counts
```

---

## Important Metrics Reference / Tham Chiếu Metric Quan Trọng

```promql
# === Queries Per Second / Truy Vấn Mỗi Giây ===
rate(mysql_global_status_questions[1m])

# === SELECT / INSERT / UPDATE rates / Tốc độ ===
rate(mysql_global_status_commands_total{command="select"}[1m])
rate(mysql_global_status_commands_total{command="insert"}[1m])

# === Connection utilization % / Sử dụng kết nối % ===
100 * mysql_global_status_threads_connected
    / mysql_global_variables_max_connections

# === Buffer pool hit rate / Tỷ lệ hit buffer pool ===
100 * (1 - rate(mysql_global_status_innodb_buffer_pool_reads[5m])
           / rate(mysql_global_status_innodb_buffer_pool_read_requests[5m]))

# === Replication lag seconds / Độ trễ sao chép giây ===
mysql_slave_status_seconds_behind_master

# === Disk bytes written / Byte ghi đĩa ===
rate(mysql_global_status_innodb_os_log_written[1m])

# === InnoDB row lock waits / Chờ row lock InnoDB ===
rate(mysql_global_status_innodb_row_lock_waits[1m])

# === Slow queries / Truy vấn chậm ===
rate(mysql_global_status_slow_queries[5m])

# === Temp tables created on disk (problem!) / Bảng tạm trên đĩa ===
rate(mysql_global_status_created_tmp_disk_tables[5m])
```

---

## Docker Setup in Monitoring Stack / Thiết Lập Docker Trong Stack Giám Sát

The monitoring stack is already configured in `docker/docker-compose.monitoring.yml`:
_Stack giám sát đã được cấu hình trong `docker/docker-compose.monitoring.yml`:_

```yaml
mysql-exporter:
  image: prom/mysqld-exporter:latest
  environment:
    DATA_SOURCE_NAME: "exporter:password@(mysql-primary:3306)/"
  ports:
    - "9104:9104"
  command:
    - --collect.global_status
    - --collect.slave_status
    - --collect.innodb_metrics
    - --collect.perf_schema.eventsstatements
```

---

## Useful PromQL Queries for Dashboard / Truy Vấn PromQL Cho Dashboard

```promql
# Active queries right now / Truy vấn đang chạy hiện tại
mysql_global_status_threads_running

# Buffer pool pages breakdown / Phân tích trang buffer pool
mysql_global_status_innodb_buffer_pool_pages_data   # data pages
mysql_global_status_innodb_buffer_pool_pages_dirty  # dirty (unflushed)
mysql_global_status_innodb_buffer_pool_pages_free   # available

# Total errors accumulated / Tổng lỗi tích lũy
increase(mysql_global_status_connection_errors_total[1h])
```

# Slow Query Log / Nhật Ký Truy Vấn Chậm

## Overview / Tổng Quan

The **slow query log** records queries that take longer than a configurable threshold. It's the starting point for all query optimization work.
_**Slow query log** ghi lại truy vấn lâu hơn ngưỡng có thể cấu hình. Đây là điểm khởi đầu cho tất cả công việc tối ưu truy vấn._

---

## Configuration / Cấu Hình

```ini
[mysqld]
slow_query_log        = ON
slow_query_log_file   = /var/log/mysql/slow.log
long_query_time       = 1       # Log queries > 1 second / Log truy vấn > 1 giây
log_queries_not_using_indexes = ON  # Also log full scans / Cũng log quét toàn bảng
min_examined_row_limit = 100    # Only log if > 100 rows examined
```

```sql
-- Enable at runtime without restart / Bật khi đang chạy:
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;
SET GLOBAL log_queries_not_using_indexes = ON;

-- Verify / Xác minh
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';
```

---

## Reading Slow Query Log / Đọc Slow Query Log

```
# Sample entry / Mẫu mục nhập
# Time: 2024-12-13T14:23:45.123456Z
# User@Host: app_user[app_user] @ [10.0.0.5]
# Query_time: 3.512345  Lock_time: 0.000234  Rows_sent: 1  Rows_examined: 1500000
# SET timestamp=1734098625;
SELECT * FROM orders WHERE YEAR(created_at) = 2024 AND status = 'pending';

Fields / Trường:
  Query_time:      total query execution time / tổng thời gian thực thi
  Lock_time:       time waiting for locks / thời gian chờ lock
  Rows_sent:       rows returned to client / hàng trả về client
  Rows_examined:   rows scanned (HIGH = full scan!) / hàng được quét
```

---

## mysqldumpslow — Aggregate Slow Queries

```bash
# Top 10 slowest queries by total time / Top 10 truy vấn chậm nhất theo tổng thời gian
mysqldumpslow -s t -t 10 /var/log/mysql/slow.log

# Top 10 by count (frequently slow) / Top 10 theo số lần (thường xuyên chậm)
mysqldumpslow -s c -t 10 /var/log/mysql/slow.log

# Top 10 by rows examined / Top 10 theo hàng được quét
mysqldumpslow -s r -t 10 /var/log/mysql/slow.log
```

---

## pt-query-digest — Better Analysis

```bash
# Install Percona Toolkit / Cài đặt Percona Toolkit
apt-get install percona-toolkit

# Analyze slow query log / Phân tích slow query log
pt-query-digest /var/log/mysql/slow.log > /tmp/slow_analysis.txt

# Sample output / Mẫu kết quả:
# Profile
# Rank Query ID           Response time  Calls  R/Call  V/M
# ==== ================== ============== ====== ======= ====
# 1    0xAB12CD34EF56AB    15.2218 55.2%     47  0.3239  0.04 SELECT orders

# Each query shows: / Mỗi truy vấn hiển thị:
#   Total/avg/max execution time
#   Number of calls, rows examined, rows sent
#   The query pattern with placeholders
```

---

## Performance Schema Alternative / Thay Thế Performance Schema

```sql
-- No log file needed — query from database / Không cần file log — truy vấn từ CSDL
SELECT
    SCHEMA_NAME,
    DIGEST_TEXT                                     AS query_pattern,
    COUNT_STAR                                      AS executions,
    ROUND(AVG_TIMER_WAIT / 1e9, 2)                 AS avg_ms,
    ROUND(MAX_TIMER_WAIT / 1e9, 2)                 AS max_ms,
    ROUND(SUM_TIMER_WAIT / 1e9, 2)                 AS total_ms,
    SUM_ROWS_EXAMINED                               AS total_rows_examined,
    ROUND(SUM_ROWS_EXAMINED / COUNT_STAR)           AS avg_rows_examined
FROM performance_schema.events_statements_summary_by_digest
WHERE SCHEMA_NAME = 'shop_db'
  AND COUNT_STAR > 10
ORDER BY avg_ms DESC
LIMIT 20;
```

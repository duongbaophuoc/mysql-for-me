# Capacity Planning / Lập Kế Hoạch Năng Lực

## Overview / Tổng Quan

Capacity planning prevents surprises: running out of disk, memory, or connections at 2 AM.
_Lập kế hoạch năng lực ngăn chặn những bất ngờ: hết đĩa, bộ nhớ hoặc kết nối lúc 2 giờ sáng._

---

## Key Resources to Monitor / Tài Nguyên Cần Giám Sát

### Storage / Lưu Trữ

```sql
-- Current database sizes / Kích thước CSDL hiện tại
SELECT
    table_schema                              AS db_name,
    ROUND(SUM(data_length)/1024/1024/1024, 2) AS data_gb,
    ROUND(SUM(index_length)/1024/1024/1024, 2) AS index_gb,
    ROUND(SUM(data_length + index_length)/1024/1024/1024, 2) AS total_gb,
    COUNT(*)                                  AS table_count
FROM information_schema.TABLES
GROUP BY table_schema
ORDER BY total_gb DESC;

-- Growth rate: run weekly and compare / Tỷ lệ tăng trưởng: chạy hàng tuần và so sánh
-- Store in a capacity_snapshots table for trending
-- Lưu vào bảng capacity_snapshots để theo dõi xu hướng
```

```bash
# OS-level disk check / Kiểm tra đĩa cấp OS
df -h /var/lib/mysql

# Disk IO utilization / Sử dụng IO đĩa
iostat -xm 5 /dev/sdb   # -x extended, -m MB/s, every 5s
```

### Memory / Bộ Nhớ

```sql
-- Buffer pool efficiency / Hiệu quả buffer pool
SELECT
    ROUND(@@innodb_buffer_pool_size / 1024 / 1024 / 1024, 1) AS buffer_pool_gb,
    ROUND(
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status
         WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_total') * 16 / 1024, 0
    ) AS total_pages_mb,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') AS read_requests,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') AS disk_reads;

-- If buffer pool full (free pages < 5%):
-- → Increase innodb_buffer_pool_size
-- → Or reduce working set (archive old data)
```

---

## Growth Projection / Dự Báo Tăng Trưởng

```sql
-- Monthly data growth trend / Xu hướng tăng trưởng dữ liệu hàng tháng
SELECT
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    COUNT(*)                          AS new_orders,
    SUM(COUNT(*)) OVER (ORDER BY DATE_FORMAT(created_at, '%Y-%m'))
                                      AS cumulative_orders
FROM orders
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY month;

-- Estimate disk space in 12 months / Ước tính dung lượng đĩa trong 12 tháng
-- Avg row size * monthly_growth * 12 = estimated storage needed
-- Kích thước hàng trung bình * tăng trưởng tháng * 12 = lưu trữ ước tính
SELECT
    AVG_ROW_LENGTH,
    TABLE_ROWS,
    ROUND(TABLE_ROWS * AVG_ROW_LENGTH * 12 / 1024 / 1024, 0) AS est_growth_12m_mb
FROM information_schema.TABLES
WHERE TABLE_NAME = 'orders'
  AND TABLE_SCHEMA = 'shop_db';
```

---

## Connection Capacity / Năng Lực Kết Nối

```sql
-- Check current vs max connections / Kiểm tra kết nối hiện tại vs tối đa
SELECT
    @@max_connections                                   AS max_connections,
    VARIABLE_VALUE AS current_connections,
    ROUND(VARIABLE_VALUE / @@max_connections * 100, 1) AS usage_pct
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Threads_connected';

-- Peak connections (since last restart) / Kết nối đỉnh (từ lần khởi động cuối)
SELECT VARIABLE_VALUE AS peak_connections
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Max_used_connections';

-- Rule / Quy tắc:
-- Peak > 80% of max_connections → increase max_connections or add ProxySQL
```

---

## Archival Strategy / Chiến Lược Lưu Trữ

```sql
-- Archive data older than 2 years / Lưu trữ dữ liệu cũ hơn 2 năm
-- Reduces table size and speeds up queries on recent data
-- Giảm kích thước bảng và tăng tốc truy vấn dữ liệu gần đây

-- Step 1: Create archive table / Bước 1: Tạo bảng lưu trữ
CREATE TABLE orders_archive LIKE orders;

-- Step 2: Move old data in batches / Bước 2: Di chuyển dữ liệu cũ theo lô
INSERT INTO orders_archive
SELECT * FROM orders
WHERE created_at < DATE_SUB(NOW(), INTERVAL 2 YEAR)
LIMIT 10000;

-- Step 3: Delete after confirming archive / Bước 3: Xóa sau khi xác nhận
DELETE FROM orders
WHERE created_at < DATE_SUB(NOW(), INTERVAL 2 YEAR)
  AND id IN (SELECT id FROM orders_archive)
LIMIT 10000;
```

---

## Capacity Dashboard / Dashboard Năng Lực

```
Metric           | Current  | 90-day trend | Time to critical
─────────────────┼──────────┼──────────────┼─────────────────
Disk /var/lib    | 340 GB   | +12 GB/month | 7 months
Buffer pool free | 15%      | stable       | OK
Max connections  | 72%      | increasing   | 3 months
orders table     | 8M rows  | +350k/month  | 12 months
```

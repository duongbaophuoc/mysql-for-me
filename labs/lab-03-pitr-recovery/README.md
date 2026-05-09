# Lab 03 — PITR Recovery / Phục Hồi Theo Thời Điểm

## Objective / Mục Tiêu

Simulate an accidental `DROP TABLE`, then perform Point-in-Time Recovery using binary logs.
_Mô phỏng `DROP TABLE` nhầm, sau đó thực hiện Phục Hồi Theo Thời Điểm sử dụng binary log._

**Duration / Thời lượng**: ~60 minutes  
**Prerequisites**: Docker running, binary logging enabled

---

## Setup / Thiết Lập

```bash
# Ensure binary logging is active / Đảm bảo binary logging đang hoạt động
mysql -h 127.0.0.1 -P 3306 -u root -psecret -e "SHOW VARIABLES LIKE 'log_bin';"
# Value: ON

# Take a logical backup to simulate a nightly backup
# Tạo backup logic để mô phỏng backup hàng đêm
mysqldump \
  --single-transaction \
  --master-data=2 \
  --flush-logs \
  -h 127.0.0.1 -P 3306 -u root -psecret \
  shop_db \
  > /tmp/shop_db_backup.sql

# Note the binlog position from the dump header
# Ghi chú vị trí binlog từ header của dump
grep "MASTER_LOG" /tmp/shop_db_backup.sql
```

---

## Step 1: Simulate Normal Activity / Mô Phỏng Hoạt Động Bình Thường

```sql
-- Insert some "business-critical" orders after backup
-- Chèn một số đơn hàng "quan trọng" sau backup
USE shop_db;

INSERT INTO orders (uuid, customer_id, address_id, status, total_amount, source)
VALUES
  (UUID(), 1, 1, 'confirmed', 5500000, 'web'),
  (UUID(), 2, 3, 'confirmed', 8200000, 'app'),
  (UUID(), 3, 4, 'pending',   3100000, 'web');

-- Note the time! / Ghi lại thời gian!
SELECT NOW() AS safe_restore_point;
-- '2024-12-13 14:22:45'

-- Wait 30 seconds / Chờ 30 giây
SELECT SLEEP(2);
```

---

## Step 2: Simulate the Disaster / Mô Phỏng Thảm Họa

```sql
-- THE ACCIDENT! / TAI NẠN!
-- A developer runs this in production / Một developer chạy lệnh này trong production
DROP TABLE order_items;

-- Or accidentally deletes all orders / Hoặc xóa nhầm tất cả đơn hàng
-- DELETE FROM orders;   -- uncomment to test this scenario too
```

---

## Step 3: Assess the Damage / Đánh Giá Thiệt Hại

```sql
-- Verify the table is gone / Xác nhận bảng đã biến mất
SHOW TABLES;
-- order_items is missing! / order_items bị mất!

SELECT COUNT(*) FROM order_items;
-- ERROR 1146: Table 'shop_db.order_items' doesn't exist
```

---

## Step 4: Perform PITR / Thực Hiện PITR

```bash
# Run the recovery script / Chạy script phục hồi
bash labs/lab-03-pitr-recovery/recovery-steps.sh "2024-12-13 14:22:45"
```

**Manual steps / Bước thủ công**:

```bash
# 1. Restore from backup / Khôi phục từ backup
mysql -h 127.0.0.1 -P 3306 -u root -psecret shop_db < /tmp/shop_db_backup.sql

# 2. Find the DROP TABLE in binlog / Tìm DROP TABLE trong binlog
docker exec mysql-primary mysqlbinlog \
    --start-datetime="2024-12-13 14:00:00" \
    /var/lib/mysql/mysql-bin.000002 2>/dev/null | grep -n "DROP TABLE"

# 3. Apply binlogs up to just before DROP TABLE
# Áp dụng binlog đến ngay trước DROP TABLE
docker exec mysql-primary mysqlbinlog \
    --start-datetime="2024-12-13 14:00:00" \
    --stop-datetime="2024-12-13 14:22:59" \
    /var/lib/mysql/mysql-bin.000002 \
    | mysql -h 127.0.0.1 -P 3306 -u root -psecret shop_db
```

---

## Step 5: Verify Recovery / Xác Minh Phục Hồi

```sql
-- Table should be back / Bảng phải trở lại
SHOW TABLES;  -- order_items should appear

-- Check data / Kiểm tra dữ liệu
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM orders;   -- Should include the 3 new orders!

-- Verify orders added after backup are present
-- Xác nhận đơn hàng thêm sau backup có mặt
SELECT * FROM orders ORDER BY id DESC LIMIT 5;
```

---

## Expected Outcomes / Kết Quả Mong Đợi

- ✅ Identified the exact DROP TABLE event in binary log
- ✅ Restored the table AND all subsequent legitimate data
- ✅ Understood the trade-off: PITR stops at the DROP, so post-DROP data is also lost
- ✅ Know how to use `--stop-position` for byte-precise recovery

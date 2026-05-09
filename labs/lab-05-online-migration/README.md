# Lab 05 — Online Schema Migration / Di Cư Schema Không Gián Đoạn

## Objective / Mục Tiêu

Perform a zero-downtime schema change on a large table using `gh-ost`.
_Thực hiện thay đổi schema không gián đoạn trên bảng lớn sử dụng `gh-ost`._

**Duration / Thời lượng**: ~60 minutes  
**Tool / Công cụ**: gh-ost (GitHub's Online Schema Change tool)

---

## The Problem / Vấn Đề

```sql
-- Standard ALTER TABLE LOCKS the table!
-- ALTER TABLE chuẩn KHÓA bảng!
ALTER TABLE orders ADD COLUMN promo_code VARCHAR(50) NULL;
-- On a table with 10M rows → table locked for ~30 minutes!
-- Trên bảng với 10 triệu hàng → bảng bị khóa khoảng 30 phút!
-- During this time: all writes are blocked / Trong thời gian này: mọi ghi bị chặn
```

### Solutions / Giải Pháp

| Tool | Approach | Production Safe |
|------|----------|----------------|
| `ALTER TABLE` (MySQL 8) | INPLACE/INSTANT | ✅ for some ops |
| `pt-online-schema-change` | Triggers | ✅ |
| `gh-ost` | Binary log replication | ✅✅ (preferred) |

---

## Setup / Thiết Lập

```bash
# Install gh-ost / Cài đặt gh-ost
# https://github.com/github/gh-ost/releases
wget https://github.com/github/gh-ost/releases/download/v1.1.6/gh-ost-binary-linux-20231207154232.tar.gz
tar xzf gh-ost-binary-linux-*.tar.gz
chmod +x gh-ost

# Load sample data / Nạp dữ liệu mẫu
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/shop_db/schema.sql
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/shop_db/seed.sql
```

---

## Step 1: Verify MySQL Online DDL First / Kiểm Tra MySQL Online DDL Trước

```sql
-- For small, reversible changes — MySQL INSTANT/INPLACE is fine
-- Cho thay đổi nhỏ, có thể đảo ngược — MySQL INSTANT/INPLACE ổn

-- Check algorithm availability / Kiểm tra thuật toán có sẵn
ALTER TABLE customers
    ADD COLUMN loyalty_tier VARCHAR(20) NULL,
    ALGORITHM=INSTANT;    -- Try INSTANT first / Thử INSTANT trước

-- If INSTANT fails, try INPLACE (no table copy)
-- Nếu INSTANT thất bại, thử INPLACE (không sao chép bảng)
ALTER TABLE customers
    ADD INDEX idx_customers_city (city),
    ALGORITHM=INPLACE,
    LOCK=NONE;
```

---

## Step 2: Run gh-ost Migration / Chạy Di Cư gh-ost

```bash
# Scenario: Add promo_code column to orders table
# Kịch bản: Thêm cột promo_code vào bảng orders

bash labs/lab-05-online-migration/migration.sh
```

**Manual run / Chạy thủ công**:

```bash
gh-ost \
  --mysql-host=127.0.0.1 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=secret \
  --database=shop_db \
  --table=orders \
  --alter="ADD COLUMN promo_code VARCHAR(50) NULL AFTER discount_amount,
           ADD INDEX idx_orders_promo_code (promo_code)" \
  --allow-on-master \
  --execute \
  --verbose \
  --exact-rowcount \
  --concurrent-rowcount \
  --default-retries=120 \
  --chunk-size=1000 \
  --throttle-control-replicas="127.0.0.1:3307" \  # Watch replica lag
  --max-lag-millis=1500
```

---

## Step 3: Monitor Progress / Theo Dõi Tiến Trình

```bash
# gh-ost creates a socket for status / gh-ost tạo socket để lấy trạng thái
echo "status" | nc -U /tmp/gh-ost.shop_db.orders.sock

# Output / Kết quả:
# Migrating `shop_db`.`orders`; Ghost table is `shop_db`.`_orders_gho`
# Migrated 45000/100000 rows; 45.00% done; ETA: 00:02:30
# Running for 127.00s
# Lag: 0.03s
```

---

## Step 4: Verify / Xác Minh

```sql
-- After migration / Sau di cư
SHOW CREATE TABLE orders\G
-- promo_code column should appear / Cột promo_code phải xuất hiện

-- No data loss / Không mất dữ liệu
SELECT COUNT(*) FROM orders;
-- Same as before / Giống như trước

-- New index is present / Index mới có mặt
SHOW INDEX FROM orders WHERE Key_name = 'idx_orders_promo_code';
```

---

## Key gh-ost Flags / Các Cờ Quan Trọng

| Flag | Description |
|------|-------------|
| `--execute` | Actually run (without: dry-run mode) |
| `--allow-on-master` | Direct on primary without replica |
| `--max-lag-millis` | Pause if replica lag exceeds this |
| `--chunk-size` | Rows copied per iteration |
| `--postpone-cut-over-flag-file` | Pause before final cut-over |
| `--initially-drop-old-table` | Clean up previous runs |

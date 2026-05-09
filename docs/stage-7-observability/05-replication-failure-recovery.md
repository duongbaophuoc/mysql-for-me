# Replication Failure Recovery / Khôi Phục Sự Cố Sao Chép

## Overview / Tổng Quan

Replication failures stop replicas from applying updates, causing them to fall behind and eventually become unusable. This playbook covers the most common failure types.
_Sự cố sao chép ngăn replica áp dụng cập nhật. Runbook này bao gồm các loại sự cố phổ biến nhất._

---

## Step 1: Check Replication Status / Kiểm Tra Trạng Thái Sao Chép

```sql
-- On the replica / Trên replica:
SHOW REPLICA STATUS\G

-- Key fields to check / Trường cần kiểm tra:
-- Replica_IO_Running:  Yes ← IO thread running / IO thread đang chạy
-- Replica_SQL_Running: Yes ← SQL thread running / SQL thread đang chạy
-- Last_Error:          (blank = OK) / (trống = OK)
-- Seconds_Behind_Source: 0  ← no lag / không trễ
-- Last_IO_Error:       (blank)
-- Last_SQL_Error:      (blank)
```

---

## Case 1: IO Thread Stopped / IO Thread Dừng

```sql
-- Error: "Connecting to master..." (network/auth issue)
-- Lỗi: "Đang kết nối đến master..." (vấn đề mạng/xác thực)

-- Diagnose / Chẩn đoán
SHOW REPLICA STATUS\G
-- Last_IO_Error: "error connecting to master..."

-- Fix: check credentials and network / Sửa: kiểm tra thông tin đăng nhập và mạng
STOP REPLICA IO_THREAD;
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'mysql-primary',
    SOURCE_USER = 'replicator',
    SOURCE_PASSWORD = 'correct_password',
    SOURCE_AUTO_POSITION = 1;
START REPLICA IO_THREAD;
```

---

## Case 2: SQL Thread Stopped — Duplicate Key / SQL Thread Dừng — Khóa Trùng

```sql
-- Error: "Could not execute Write_rows event on table..."
-- Lỗi: "Không thể thực thi Write_rows event..."
-- Last_SQL_Error: Duplicate entry '123' for key 'PRIMARY'

-- Option A: Skip the error / Bỏ qua lỗi (use only when safe!)
-- Tùy chọn A: Bỏ qua lỗi (chỉ dùng khi an toàn!)
SET GLOBAL SQL_REPLICA_SKIP_COUNTER = 1;
START REPLICA;

-- Option B: Use error filters (MySQL 8.0+)
-- Tùy chọn B: Dùng bộ lọc lỗi
CHANGE REPLICATION FILTER REPLICATE_IGNORE_TABLE = (shop_db.temp_table);
```

---

## Case 3: GTID Gap — Missing Transactions / Khoảng Trống GTID

```sql
-- Error: GTIDs applied on replica don't match source
-- Last_SQL_Error: Got fatal error from source when executing a GTID

-- Check GTID difference / Kiểm tra sự khác biệt GTID
SELECT GTID_SUBTRACT(
    '3E11FA47-71CA-11E1-9E33-C80AA9429562:1-50',   -- source gtid_executed
    @@GLOBAL.gtid_executed                           -- replica gtid_executed
) AS missing_gtids;

-- Fix: inject empty transaction for missing GTID / Chèn giao dịch trống
SET GTID_NEXT = '3E11FA47-71CA-11E1-9E33-C80AA9429562:45';  -- missing GTID
BEGIN; COMMIT;   -- empty transaction
SET GTID_NEXT = 'AUTOMATIC';
START REPLICA;
```

---

## Case 4: Complete Re-sync Required / Cần Đồng Bộ Lại Hoàn Toàn

```bash
# When replica is too far behind to catch up / Khi replica quá xa
# Re-provision from backup / Cung cấp lại từ backup

# Step 1: Stop replica / Dừng replica
mysql -h REPLICA -e "STOP REPLICA; RESET REPLICA ALL;"

# Step 2: Restore from XtraBackup / Khôi phục từ backup
# (see: 06-mysqldump-xtrabackup.md)

# Step 3: Get GTID from backup / Lấy GTID từ backup
cat /backups/xb_20241215/xtrabackup_binlog_info
# mysql-bin.000023   123456789   primary-uuid:1-50234

# Step 4: Configure replica / Cấu hình replica
mysql -h REPLICA -e "
  RESET MASTER;
  SET GLOBAL gtid_purged = 'primary-uuid:1-50234';
  CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'mysql-primary',
    SOURCE_AUTO_POSITION = 1;
  START REPLICA;"
```

---

## Prevention / Phòng Ngừa

```ini
# Replicas should be read-only to prevent accidental writes
# Replica phải read_only để ngăn ghi vô tình
[mysqld]
read_only        = ON
super_read_only  = ON
```

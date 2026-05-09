# Point-in-Time Recovery (PITR) / Phục Hồi Theo Thời Điểm

## Overview / Tổng Quan

PITR lets you restore a MySQL database to any specific moment in time — not just the last backup.
_PITR cho phép bạn khôi phục CSDL MySQL về bất kỳ thời điểm cụ thể nào — không chỉ backup cuối._

**When PITR saves you**: Accidental `DROP TABLE`, corrupted data, logical errors.
_**Khi PITR cứu bạn**: `DROP TABLE` nhầm, dữ liệu bị hỏng, lỗi logic._

**Requirements**: Full backup + continuous binary logs.
_**Yêu cầu**: Backup đầy đủ + binary log liên tục._

---

## PITR Architecture / Kiến Trúc PITR

```
Full Backup           Binary Logs
(XtraBackup/dump)     (binlog)
[Sunday 00:00] ──────►[Mon][Tue][Wed][Thu][Fri 14:23]
                                              ▲
                                       Incident here!
                                       Sự cố xảy ra!
                                       e.g. DROP TABLE

Recovery: / Phục hồi:
Restore full backup → replay binlogs up to 14:22  (1 minute before!)
Khôi phục backup → phát lại binlog đến 14:22 (1 phút trước!)
```

---

## Step 1: Take a Full Backup / Bước 1: Tạo Backup Đầy Đủ

```bash
# With XtraBackup (hot backup, no downtime) / Với XtraBackup (backup nóng, không gián đoạn)
xtrabackup --backup \
  --user=root --password=secret \
  --target-dir=/backups/full-$(date +%F)

# With mysqldump (simpler, slower) / Với mysqldump (đơn giản hơn, chậm hơn)
mysqldump \
  --all-databases \
  --single-transaction \
  --master-data=2 \        # Records binlog position / Ghi lại vị trí binlog
  --flush-logs \
  -u root -psecret \
  > /backups/full-$(date +%F).sql
```

---

## Step 2: Ensure Binary Logs Are Retained / Bước 2: Đảm Bảo Giữ Binary Log

```sql
-- Check binlog retention / Kiểm tra thời gian giữ binlog
SHOW VARIABLES LIKE 'binlog_expire_logs_seconds';
-- Default: 2592000 (30 days) / Mặc định: 30 ngày

-- List available binary logs / Liệt kê binary log có sẵn
SHOW BINARY LOGS;
-- +------------------+-----------+
-- | Log_name         | File_size |
-- | mysql-bin.000001 | 126304742 |
-- | mysql-bin.000002 | 98763251  |

-- Check binlog position at backup time / Kiểm tra vị trí binlog lúc backup
-- (visible in mysqldump output or XtraBackup xtrabackup_binlog_info)
```

---

## Step 3: Perform Recovery / Bước 3: Thực Hiện Phục Hồi

### Scenario: Accidental DROP TABLE at 14:23 on Friday
_Kịch bản: DROP TABLE nhầm lúc 14:23 Thứ Sáu_

```bash
# STOP the production database first! / Dừng CSDL production trước!
# Never perform PITR on a running production DB!

# 1. Restore full backup / Khôi phục backup đầy đủ
xtrabackup --prepare --target-dir=/backups/full-2024-12-13/
xtrabackup --copy-back --target-dir=/backups/full-2024-12-13/
chown -R mysql:mysql /var/lib/mysql/

# Start MySQL temporarily for binlog replay
# Khởi động MySQL tạm thời để phát lại binlog
mysqld_safe --skip-networking &
```

```sql
-- 2. Find the DROP TABLE event / Tìm sự kiện DROP TABLE
-- Check which binlog file contains the incident
-- Kiểm tra file binlog chứa sự cố
```

```bash
# Use mysqlbinlog to inspect binlogs / Dùng mysqlbinlog để kiểm tra
mysqlbinlog \
  --start-datetime="2024-12-13 00:00:00" \
  --stop-datetime="2024-12-13 14:25:00" \
  /var/lib/mysql/mysql-bin.000015 | grep -A 5 "DROP TABLE"

# Output shows the exact position / Kết quả hiển thị vị trí chính xác:
# at 1234567   ← stop BEFORE this position!
```

```bash
# 3. Apply binlogs up to just BEFORE the DROP TABLE
# Áp dụng binlog đến TRƯỚC DROP TABLE
mysqlbinlog \
  --start-position=4 \
  --stop-position=1234566 \     # One byte before DROP TABLE / Một byte trước DROP TABLE
  /var/lib/mysql/mysql-bin.000001 \
  /var/lib/mysql/mysql-bin.000002 \
  ...
  /var/lib/mysql/mysql-bin.000015 \
  | mysql -u root -psecret

# Or use stop-datetime / Hoặc dùng stop-datetime:
mysqlbinlog \
  --start-datetime="2024-12-13 00:00:00" \
  --stop-datetime="2024-12-13 14:22:59" \  # 1 minute before / 1 phút trước
  /var/lib/mysql/mysql-bin.* \
  | mysql -u root -psecret
```

---

## Verification / Xác Minh

```sql
-- After recovery / Sau phục hồi:
-- Verify the dropped table is back / Xác minh bảng bị drop đã trở lại
SHOW TABLES FROM shop_db;

-- Verify data integrity / Xác minh tính toàn vẹn dữ liệu
SELECT COUNT(*) FROM shop_db.orders;
SELECT MAX(created_at) FROM shop_db.orders;  -- Should be 14:22:xx
```

---

## PITR with XtraBackup — Best Practice Workflow
_PITR với XtraBackup — Quy Trình Thực Hành Tốt Nhất_

```bash
# scripts/backup/pitr-recovery.sh
#!/bin/bash
BACKUP_DIR="/backups"
TARGET_TIME="${1:-$(date '+%Y-%m-%d %H:%M:%S')}"

echo "=== PITR Recovery to: $TARGET_TIME ==="
echo "=== PITR Phục hồi đến: $TARGET_TIME ==="

# 1. Find latest full backup before target time
LATEST_BACKUP=$(ls -1t $BACKUP_DIR/full-* | head -1)
echo "Using backup: $LATEST_BACKUP"

# 2. Prepare backup
xtrabackup --prepare --target-dir="$LATEST_BACKUP"

# 3. Restore
xtrabackup --copy-back --target-dir="$LATEST_BACKUP"
chown -R mysql:mysql /var/lib/mysql/

# 4. Apply binlogs
mysqlbinlog \
    --stop-datetime="$TARGET_TIME" \
    $BACKUP_DIR/binlogs/mysql-bin.* \
    | mysql -u root -psecret
    
echo "=== Recovery complete / Phục hồi hoàn tất ==="
```

---

## PITR RPO & RTO / RPO & RTO Của PITR

| Metric | Value | Notes |
|--------|-------|-------|
| **RPO** (data loss) | Seconds | Depends on binlog shipping frequency |
| **RTO** (downtime) | 30min–4hrs | Depends on DB size and network speed |
| **Precision** | 1 second | `--stop-datetime` granularity |

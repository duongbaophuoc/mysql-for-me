# Binary Logs / Nhật Ký Nhị Phân

## Overview / Tổng Quan

The **binary log** (binlog) records all changes made to MySQL data. It serves two purposes:
_**Binary log** (binlog) ghi lại tất cả thay đổi với dữ liệu MySQL. Nó phục vụ hai mục đích:_

1. **Replication**: Replicas read binlog to apply changes / Replica đọc binlog để áp dụng thay đổi
2. **PITR (Point-in-Time Recovery)**: Replay changes after a backup restore / Phát lại thay đổi sau khôi phục backup

---

## Enabling Binary Logging / Bật Binary Logging

```ini
[mysqld]
log-bin              = mysql-bin    # Enable binlog / Bật binlog
binlog-format        = ROW          # ROW format for replication accuracy
server-id            = 1            # Unique per server (required for replication)
sync-binlog          = 1            # Flush to disk on each COMMIT (safe) / Flush mỗi COMMIT
binlog_expire_logs_seconds = 604800 # Keep 7 days of logs / Giữ 7 ngày log
```

---

## Binary Log Formats / Định Dạng Binary Log

| Format | Records | Size | Replication Safety |
|--------|---------|------|-------------------|
| **STATEMENT** | SQL statements | Small | ❌ Non-deterministic functions unsafe |
| **ROW** | Before/after row images | Large | ✅ Most accurate |
| **MIXED** | Auto-chooses | Medium | ✅ OK for most cases |

```sql
-- Check current format / Kiểm tra định dạng hiện tại
SHOW VARIABLES LIKE 'binlog_format';  -- Should be ROW

-- ROW format captures: / ROW format lưu:
-- For UPDATE: old values + new values of each changed row
-- For INSERT: the new row values
-- For DELETE: the deleted row values
```

---

## Viewing Binary Logs / Xem Binary Log

```sql
-- List binary log files / Liệt kê file binary log
SHOW BINARY LOGS;
-- +------------------+-----------+
-- | mysql-bin.000001 | 126304742 |
-- | mysql-bin.000002 | 56732819  |

-- Show current binary log position / Hiển thị vị trí binary log hiện tại
SHOW MASTER STATUS\G
-- File: mysql-bin.000002
-- Position: 56732819
-- Executed_Gtid_Set: uuid:1-5023

-- Show events in a log file / Hiển thị sự kiện trong file log
SHOW BINLOG EVENTS IN 'mysql-bin.000002' LIMIT 20;
```

```bash
# Decode binary log from command line / Giải mã binary log từ dòng lệnh
mysqlbinlog \
    --start-datetime="2024-12-13 14:00:00" \
    --stop-datetime="2024-12-13 15:00:00" \
    --base64-output=DECODE-ROWS \
    --verbose \
    /var/lib/mysql/mysql-bin.000002

# Pipe directly to MySQL for recovery / Đưa trực tiếp vào MySQL để phục hồi
mysqlbinlog /var/lib/mysql/mysql-bin.000002 | mysql -u root -psecret
```

---

## Binary Log Monitoring / Giám Sát Binary Log

```sql
-- Binlog write speed (bytes/second) / Tốc độ ghi binlog
SELECT VARIABLE_VALUE / UPTIME_SECONDS AS binlog_bytes_per_sec
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Binlog_bytes_written';

-- Check binlog disk usage / Kiểm tra sử dụng đĩa binlog
SELECT SUM(LOG_SIZE) / 1024 / 1024 AS total_binlog_mb
FROM information_schema.FILES
WHERE FILE_TYPE = 'UNDO LOG';  -- check binlog files separately
```

---

## Binlog and GTID Relationship / Quan Hệ Binlog và GTID

```sql
-- Each committed transaction gets one GTID in the binlog
-- Mỗi giao dịch được commit có một GTID trong binlog

-- View GTID in binlog:
mysqlbinlog --verbose /var/lib/mysql/mysql-bin.000002 | grep -A2 "GTID"
-- # SET @@SESSION.GTID_NEXT='3E11FA47-71CA-11E1-9E33-C80AA9429562:45'
-- # COMMIT /* xid=12345 */
```

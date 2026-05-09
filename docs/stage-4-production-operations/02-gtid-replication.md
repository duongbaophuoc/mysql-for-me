# GTID Replication / Sao Chép GTID

## Overview / Tổng Quan

**GTID (Global Transaction Identifier)** makes MySQL replication reliable, self-healing, and easier to manage than traditional file-position-based replication.
_**GTID** làm cho MySQL replication đáng tin cậy, tự phục hồi và dễ quản lý hơn replication dựa trên vị trí file truyền thống._

---

## What is a GTID? / GTID Là Gì?

```
GTID format / Định dạng GTID:
source_id:transaction_id

Example / Ví dụ:
3E11FA47-71CA-11E1-9E33-C80AA9429562:23

├── source_id: UUID of the primary server
│   UUID của server primary
└── transaction_id: sequential integer per transaction
    Số nguyên tuần tự mỗi giao dịch
```

Every committed transaction gets a unique GTID. Replicas track which GTIDs they've applied.
_Mọi giao dịch được commit đều có GTID duy nhất. Replica theo dõi những GTID đã áp dụng._

---

## Setup / Thiết Lập

### my.cnf on Primary / my.cnf trên Primary

```ini
[mysqld]
server-id             = 1
log-bin               = mysql-bin
binlog-format         = ROW
gtid-mode             = ON
enforce-gtid-consistency = ON
sync-binlog           = 1
```

### my.cnf on Replica / my.cnf trên Replica

```ini
[mysqld]
server-id             = 2
relay-log             = relay-bin
log-bin               = mysql-bin
read-only             = ON
gtid-mode             = ON
enforce-gtid-consistency = ON
replica-parallel-workers  = 4
replica-parallel-type     = LOGICAL_CLOCK
```

---

## Start Replication / Bắt Đầu Sao Chép

```sql
-- On replica / Trên replica:
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST     = 'primary',
    SOURCE_PORT     = 3306,
    SOURCE_USER     = 'replicator',
    SOURCE_PASSWORD = 'repl_secret',
    SOURCE_AUTO_POSITION = 1;   -- Use GTID auto-positioning / Dùng tự động đặt vị trí GTID

START REPLICA;

-- Verify / Kiểm tra
SHOW REPLICA STATUS\G
-- Look for / Tìm:
-- Replica_IO_Running: Yes
-- Replica_SQL_Running: Yes
-- Seconds_Behind_Source: 0   ← no lag / không trễ
```

---

## Monitoring / Giám Sát

```sql
-- Check GTID status / Kiểm tra trạng thái GTID
SHOW MASTER STATUS\G                    -- On primary / Trên primary
-- Executed_Gtid_Set: uuid:1-1000

SHOW REPLICA STATUS\G                   -- On replica / Trên replica
-- Retrieved_Gtid_Set: uuid:1-1000     -- received / đã nhận
-- Executed_Gtid_Set: uuid:1-998       -- applied / đã áp dụng
-- Seconds_Behind_Source: 2            -- lag / trễ

-- Calculate lag precisely / Tính trễ chính xác
SELECT
    GTID_SUBTRACT(
        @@GLOBAL.gtid_executed,         -- primary GTIDs / GTID của primary
        (SELECT @@GLOBAL.gtid_executed) -- replica GTIDs / GTID của replica
    ) AS pending_gtids;
```

---

## Troubleshooting / Xử Lý Sự Cố

### Skip a problematic GTID / Bỏ qua GTID có vấn đề

```sql
-- ⚠️ Use only when you understand the impact!
-- ⚠️ Chỉ dùng khi hiểu rõ tác động!

STOP REPLICA SQL_THREAD;

-- Inject an empty transaction for the problematic GTID
-- Chèn giao dịch rỗng cho GTID có vấn đề
SET GTID_NEXT = 'source-uuid:problematic-number';
BEGIN; COMMIT;
SET GTID_NEXT = 'AUTOMATIC';

START REPLICA SQL_THREAD;
SHOW REPLICA STATUS\G
```

### Replica IO Thread stopped / IO Thread replica dừng

```sql
SHOW REPLICA STATUS\G
-- Check: Last_IO_Error / Kiểm tra: Last_IO_Error
-- Common: network issue, auth failure, binary log purged
-- Phổ biến: sự cố mạng, lỗi auth, binlog bị dọn

-- Fix: verify network / auth first
-- Fix: kiểm tra mạng / auth trước
START REPLICA IO_THREAD;
```

---

## GTID vs File-Position Replication / GTID vs Sao Chép Theo Vị Trí File

| Feature | File-Position | GTID |
|---------|--------------|------|
| Failover complexity | High | Low |
| Self-healing | ❌ | ✅ |
| Multi-source support | Limited | ✅ |
| Debugging | Hard | Easy |
| Setup | Simple | Slightly complex |
| MySQL 8.0 default | No | Yes (recommended) |

**Always use GTID for new deployments.**
_**Luôn dùng GTID cho triển khai mới.**_

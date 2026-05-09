# Failover Procedure / Quy Trình Chuyển Đổi Dự Phòng

## Overview / Tổng Quan

This runbook describes the manual failover procedure when the MySQL primary becomes unavailable.
_Runbook này mô tả quy trình chuyển đổi dự phòng thủ công khi MySQL primary không khả dụng._

**Target RTO / RTO Mục Tiêu**: < 5 minutes  
**Pre-requisite / Điều Kiện**: GTID replication enabled on all nodes

---

## Decision Tree / Cây Quyết Định

```
Primary unreachable?
Primary không thể tiếp cận?
        │
        ├── YES / CÓ
        │     │
        │     ├── Is it a network blip? / Sự cố mạng thoáng qua?
        │     │     └── Wait 30s, retry / Chờ 30 giây, thử lại
        │     │
        │     └── Primary truly dead? / Primary thực sự chết?
        │           └── Proceed with failover / Tiến hành chuyển đổi
        │
        └── NO / KHÔNG → STOP, investigate / Điều tra
```

---

## Step 1: Stop All Writes to Primary / Dừng Ghi Vào Primary

```bash
# Method A: Via load balancer / Qua load balancer
# Remove primary from write pool / Xóa primary khỏi pool ghi
# (ProxySQL: mark primary OFFLINE in mysql_servers)

# Method B: Via application config / Qua cấu hình ứng dụng
# Set READ_ONLY mode at application level / Đặt READ_ONLY ở cấp ứng dụng

# Method C: If accessible — force read-only / Nếu có thể truy cập
mysql -h PRIMARY -u root -psecret -e "SET GLOBAL read_only = ON;"
```

---

## Step 2: Elect New Primary / Chọn Primary Mới

```sql
-- On each replica — find the most up-to-date one
-- Trên mỗi replica — tìm cái cập nhật nhất
SHOW REPLICA STATUS\G
-- Look for: Executed_Gtid_Set — most GTIDs = most up-to-date
-- Tìm: Executed_Gtid_Set — nhiều GTID nhất = cập nhật nhất

-- Also check / Cũng kiểm tra:
SELECT @@gtid_executed;
```

Choose the replica with the **highest transaction count**.
_Chọn replica với **số giao dịch cao nhất**._

---

## Step 3: Promote Replica to Primary / Thăng Cấp Replica Thành Primary

```sql
-- On the chosen replica / Trên replica được chọn:
STOP REPLICA;
RESET REPLICA ALL;                  -- Detach from old primary / Tách khỏi primary cũ
SET GLOBAL read_only = OFF;         -- Allow writes / Cho phép ghi
SET GLOBAL super_read_only = OFF;
```

---

## Step 4: Point Other Replicas to New Primary
_Chỉ Các Replica Khác Đến Primary Mới_

```sql
-- On remaining replicas / Trên các replica còn lại:
STOP REPLICA;
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'NEW_PRIMARY_HOST',
    SOURCE_AUTO_POSITION = 1;
START REPLICA;

-- Verify / Xác minh
SHOW REPLICA STATUS\G
```

---

## Step 5: Update Application Configuration / Cập Nhật Cấu Hình Ứng Dụng

```bash
# Update ProxySQL to point writes to new primary
# Cập nhật ProxySQL để ghi vào primary mới

mysql -h 127.0.0.1 -P 6032 -u admin -padmin -e "
UPDATE mysql_servers
SET STATUS = 'ONLINE'
WHERE hostname = 'NEW_PRIMARY' AND port = 3306;

UPDATE mysql_servers
SET STATUS = 'OFFLINE_SOFT'
WHERE hostname = 'OLD_PRIMARY' AND port = 3306;

LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
"
```

---

## Step 6: Verify and Document / Xác Minh và Ghi Chép

```sql
-- Verify new primary is accepting writes / Xác minh primary mới nhận ghi
INSERT INTO shop_db.audit_log (table_name, record_id, action, changed_at)
VALUES ('failover_test', 0, 'INSERT', NOW());

-- Check replicas are following new primary / Kiểm tra replica theo primary mới
SHOW REPLICA STATUS\G
```

---

## Post-Failover / Sau Chuyển Đổi

1. **Document** the incident / Ghi lại sự cố
2. **Investigate** root cause of primary failure / Điều tra nguyên nhân gốc
3. **Configure** old primary as replica when recovered / Cấu hình primary cũ thành replica
4. **Run post-mortem** / Phân tích sau sự cố

---

## Automated Failover Tools / Công Cụ Chuyển Đổi Tự Động

For production, consider automated failover:
_Cho production, xem xét chuyển đổi tự động:_

| Tool | Description |
|------|-------------|
| **Orchestrator** | MySQL topology manager with HA |
| **MHA** | Master High Availability Manager |
| **InnoDB Cluster** | MySQL's native HA solution |
| **ProxySQL** | Can do automatic routing failover |

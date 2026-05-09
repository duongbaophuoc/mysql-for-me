# Incident Response Playbooks / Sổ Tay Ứng Phó Sự Cố

## Overview / Tổng Quan

Structured incident response reduces MTTR (Mean Time to Recovery) and prevents panicked decisions.
_Ứng phó sự cố có cấu trúc giảm MTTR và ngăn các quyết định hoảng loạn._

---

## Incident Severity Levels / Cấp Độ Sự Cố

| Level | Definition | Response Time | Example |
|-------|------------|---------------|---------|
| **P1** | Production down, data loss | < 5 min | Primary DB crashed |
| **P2** | Degraded performance | < 30 min | Replication lag > 60s |
| **P3** | Non-critical issue | < 4 hrs | Slow query > 5s |
| **P4** | Maintenance task | Next business day | Disk at 70% |

---

## Playbook 1: Database Unreachable / Không Kết Được CSDL

```bash
# === STEP 1: Verify the problem / Xác minh vấn đề ===
mysqladmin -h PRIMARY_HOST -u root -psecret ping
# Response: "mysqld is alive" OR connection refused

docker logs mysql-primary --tail 100 | grep -E "ERROR|WARNING|Crash"

# === STEP 2: Check system resources / Kiểm tra tài nguyên ===
docker stats mysql-primary
df -h /var/lib/mysql   # Disk full? / Đĩa đầy?
free -m                # OOM? / Hết bộ nhớ?

# === STEP 3: Try to restart / Thử khởi động lại ===
docker restart mysql-primary
sleep 30
mysqladmin -h PRIMARY_HOST -u root -psecret status

# === STEP 4: If primary unrecoverable — check replicas ===
# === Nếu primary không thể khôi phục — kiểm tra replica ===
mysql -h REPLICA1 -u root -psecret -e "SHOW REPLICA STATUS\G"
# If replica is caught up → promote to primary / Nếu replica đã cập nhật → thăng cấp
```

---

## Playbook 2: Replication Lag / Trễ Sao Chép

```sql
-- === STEP 1: Measure lag / Đo độ trễ ===
SHOW REPLICA STATUS\G
-- Seconds_Behind_Source: 450   ← 7.5 minutes lag!

-- === STEP 2: Identify cause / Xác định nguyên nhân ===
-- Check replica SQL thread for blocking queries
SELECT * FROM performance_schema.events_statements_current
WHERE thread_id IN (
    SELECT thread_id FROM performance_schema.threads
    WHERE name LIKE '%replica_sql%'
)\G

-- Check for long-running transactions on primary
SELECT trx_id, TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS age_s, trx_query
FROM information_schema.INNODB_TRX
ORDER BY trx_started ASC\G
```

```bash
# === STEP 3: Mitigation options / Các lựa chọn giảm thiểu ===

# Option A: Enable parallel replication / Bật replication song song
mysql -h REPLICA -u root -psecret -e "
STOP REPLICA SQL_THREAD;
SET GLOBAL replica_parallel_workers = 8;
SET GLOBAL replica_parallel_type = 'LOGICAL_CLOCK';
START REPLICA SQL_THREAD;
"

# Option B: Kill blocking query on replica / Kill truy vấn chặn trên replica
# Find thread ID from SHOW REPLICA STATUS → Replicate_SQL:
mysql -h REPLICA -u root -psecret -e "KILL QUERY <thread_id>;"
```

---

## Playbook 3: Disk Full / Đĩa Đầy

```bash
# === IMMEDIATE ACTIONS / HÀNH ĐỘNG NGAY LẬP TỨC ===

# Check disk usage / Kiểm tra sử dụng đĩa
df -h /var/lib/mysql
du -sh /var/lib/mysql/* | sort -rh | head 10

# 1. Free up old binary logs SAFELY / Dọn binary log cũ AN TOÀN
mysql -u root -psecret -e "
    -- First check what replicas have consumed
    -- Kiểm tra replica đã tiêu thụ đến đâu
    SHOW REPLICA STATUS\G  -- on each replica
    
    -- Then purge safely / Sau đó dọn an toàn
    PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 3 DAY);
"

# 2. Check for large temp files / Kiểm tra file tạm lớn
ls -lh /tmp/mysql* /var/tmp/mysql* 2>/dev/null

# 3. Identify largest tables / Xác định bảng lớn nhất
mysql -u root -psecret -e "
SELECT table_schema, table_name,
       ROUND(data_length/1024/1024/1024, 2) AS data_gb,
       ROUND(index_length/1024/1024/1024, 2) AS index_gb
FROM information_schema.TABLES
ORDER BY data_length + index_length DESC
LIMIT 10;
"
```

---

## Playbook 4: Connection Storm / Bão Kết Nối

```sql
-- === SYMPTOMS / TRIỆU CHỨNG ===
-- ERROR 1040: Too many connections
-- Application: "Unable to acquire connection from pool"

-- === STEP 1: Check connections / Kiểm tra kết nối ===
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Max_used_connections';
SHOW VARIABLES LIKE 'max_connections';

-- Analyze who is connecting / Phân tích ai đang kết nối
SELECT user, host, COUNT(*) AS connections, command
FROM information_schema.PROCESSLIST
GROUP BY user, host, command
ORDER BY connections DESC;

-- === STEP 2: Kill idle connections / Kill kết nối idle ===
-- Find connections sleeping > 60 seconds / Kết nối ngủ > 60 giây
SELECT ID, USER, HOST, COMMAND, TIME, INFO
FROM information_schema.PROCESSLIST
WHERE COMMAND = 'Sleep' AND TIME > 60
ORDER BY TIME DESC;

-- Kill them / Kill chúng:
CALL kill_idle_connections();   -- custom procedure
-- or manually / hoặc thủ công:
-- KILL CONNECTION <id>;

-- === STEP 3: Emergency increase (temporary!) / Tăng khẩn cấp (tạm thời!) ===
SET GLOBAL max_connections = 300;   -- revert after fixing root cause

-- === STEP 4: Root cause / Nguyên nhân gốc ===
-- Connection pool misconfigured? / Pool kết nối sai cấu hình?
-- Missing connection.close() in code? / Thiếu đóng kết nối?
-- Deadlock causing slow transactions? / Deadlock gây giao dịch chậm?
```

---

## Post-Incident Review Template / Mẫu Xem Xét Sau Sự Cố

```markdown
## Incident Post-Mortem / Phân Tích Sau Sự Cố

**Date / Ngày**: 
**Duration / Thời gian**: 
**Severity / Mức độ**: 
**Services Affected / Dịch vụ bị ảnh hưởng**: 

### Timeline / Dòng thời gian
- HH:MM Alert fired / Cảnh báo kích hoạt
- HH:MM Acknowledged / Xác nhận
- HH:MM Root cause identified / Xác định nguyên nhân
- HH:MM Mitigated / Giảm thiểu
- HH:MM Resolved / Giải quyết

### Root Cause / Nguyên Nhân Gốc


### What Went Well / Điều Gì Tốt


### Action Items / Hạng Mục Hành Động
- [ ] Short term / Ngắn hạn:
- [ ] Long term / Dài hạn:
```

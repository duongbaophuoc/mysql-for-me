# Replication / Sao Chép

## Overview / Tổng Quan

This directory contains scripts and configurations for setting up and monitoring MySQL replication.
_Thư mục này chứa các script và cấu hình để thiết lập và giám sát MySQL replication._

---

## Files / Tập Tin

| File | Description |
|------|-------------|
| [`setup-gtid-replication.sh`](setup-gtid-replication.sh) | Automated GTID replication setup |
| [`check-replication-status.sql`](check-replication-status.sql) | Status monitoring queries |
| [`failover-procedure.md`](failover-procedure.md) | Manual failover runbook |

---

## Quick Start / Khởi Động Nhanh

```bash
# 1. Start the replication stack / Khởi động stack replication
docker compose -f ../docker/docker-compose.replication.yml up -d

# 2. Wait for all containers / Chờ tất cả container
sleep 30

# 3. Run replication setup / Chạy thiết lập replication
PRIMARY_HOST=127.0.0.1 PRIMARY_PORT=3306 \
REPLICA_HOST=127.0.0.1 REPLICA_PORT=3307 \
bash setup-gtid-replication.sh

# 4. Verify replication / Xác minh replication
mysql -h 127.0.0.1 -P 3307 -u root -psecret < check-replication-status.sql
```

---

## Architecture / Kiến Trúc

```
Primary (3306) ──binlog──► Replica 1 (3307)
              └──binlog──► Replica 2 (3308)
                    ▲
              ProxySQL (6033) routes:
              - Writes → Primary / Ghi → Primary
              - Reads  → Replicas / Đọc → Replica
```

---

## Monitoring / Giám Sát

```bash
# Check replication health / Kiểm tra sức khỏe replication
bash ../scripts/monitoring/check-replication.sh

# Monitor lag continuously / Giám sát trễ liên tục
watch -n 2 "mysql -h 127.0.0.1 -P 3307 -u root -psecret \
  -e 'SHOW REPLICA STATUS\G' | grep -E 'Seconds_Behind|Running'"
```

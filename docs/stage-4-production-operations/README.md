# 🟣 Stage 4 — Production Operations & Reliability
# 🟣 Giai Đoạn 4 — Vận Hành Production & Độ Tin Cậy

> **"A database engineer who has never handled a replication failure is not a production engineer."**
> _"Một database engineer chưa từng xử lý sự cố replication không phải là kỹ sư production."_

## Overview / Tổng Quan

This stage covers the operational aspects of running MySQL in production: replication, HA, backup/recovery, and security. These are the skills that separate DBAs from developers.
_Giai đoạn này bao gồm các khía cạnh vận hành MySQL trong production: replication, HA, backup/phục hồi và bảo mật._

## Topics / Chủ Đề

| File | Topic | Level |
|------|-------|-------|
| [01-binary-logs.md](01-binary-logs.md) | Binlog internals, formats, management | Production |
| [02-gtid-replication.md](02-gtid-replication.md) | GTID setup, failover, troubleshooting | Production |
| [03-replication-lag.md](03-replication-lag.md) | Diagnosing and reducing lag | Production |
| [04-group-replication-innodb-cluster.md](04-group-replication-innodb-cluster.md) | Native HA clustering | Expert |
| [05-failover-strategies.md](05-failover-strategies.md) | Orchestrator, MHA, manual failover | Expert |
| [06-mysqldump-xtrabackup.md](06-mysqldump-xtrabackup.md) | Logical & physical backups | Production |
| [07-pitr.md](07-pitr.md) | Point-in-time recovery with binlogs | Expert |
| [08-disaster-recovery.md](08-disaster-recovery.md) | Multi-region DR planning | Expert |
| [09-security-users-ssl.md](09-security-users-ssl.md) | RBAC, SSL/TLS, audit logging | Production |

## Learning Outcomes / Kết Quả Học Tập

- ✅ Set up GTID-based replication from scratch
- ✅ Diagnose replication lag and apply mitigation strategies
- ✅ Perform physical hot backups with XtraBackup
- ✅ Execute Point-in-Time Recovery (PITR) to a specific timestamp
- ✅ Implement least-privilege MySQL user accounts
- ✅ Design a multi-region disaster recovery plan

## Replication Architecture / Kiến Trúc Replication

```
┌───────────────────────────────────────────────────────────────┐
│  MySQL Primary (Source)                                       │
│  ┌─────────────────┐                                          │
│  │   Application   │ ← writes                                 │
│  └────────┬────────┘                                          │
│           │  commits                                          │
│  ┌────────▼────────┐                                          │
│  │   Binary Log    │ ← ROW format events                      │
│  │   (binlog)      │                                          │
│  └────────┬────────┘                                          │
└───────────┼───────────────────────────────────────────────────┘
            │ async/semi-sync replication
     ┌──────┴──────┐
     │             │
┌────▼────┐   ┌────▼────┐
│Replica 1│   │Replica 2│  ← Read traffic / Lưu lượng đọc
│(relay   │   │(relay   │
│  log)   │   │  log)   │
└─────────┘   └─────────┘
```

## Critical GTID Commands / Lệnh GTID Quan Trọng

```sql
-- Check GTID status / Kiểm tra trạng thái GTID
SHOW MASTER STATUS\G
SHOW REPLICA STATUS\G

-- Manual GTID skip (use with caution!) / Bỏ qua GTID thủ công (cẩn thận!)
SET GTID_NEXT = 'uuid:transaction-id';
BEGIN; COMMIT;
SET GTID_NEXT = 'AUTOMATIC';

-- Check replication lag / Kiểm tra độ trễ replication
SELECT * FROM performance_schema.replication_applier_status_by_worker\G
```

## Backup Strategy Matrix / Ma Trận Chiến Lược Backup

| Method | RTO | RPO | Hot Backup | Use Case |
|--------|-----|-----|------------|----------|
| `mysqldump` | Hours | Minutes | ✅ | Small DBs, logical restore |
| `mysqlpump` | Hours | Minutes | ✅ | Parallel logical backup |
| XtraBackup | Minutes | Seconds | ✅ | Large production DBs |
| MySQL Enterprise Backup | Minutes | Seconds | ✅ | Enterprise environments |
| PITR via binlog | Minutes | Seconds | N/A | Point-in-time recovery |

## Next Stage / Giai Đoạn Tiếp Theo

→ [Stage 5 — Distributed Systems](../stage-5-distributed-systems/README.md)

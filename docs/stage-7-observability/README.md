# 🔵 Stage 7 — Observability, SRE & Incident Engineering
# 🔵 Giai Đoạn 7 — Quan Sát, SRE & Kỹ Thuật Xử Lý Sự Cố

> **"You cannot fix what you cannot see."**
> _"Bạn không thể sửa điều bạn không thể thấy."_

## Overview / Tổng Quan

This is the expert stage for engineers who run MySQL in production. Observability, SRE practices, and structured incident response separate operational excellence from chaos.
_Đây là giai đoạn chuyên gia cho các kỹ sư vận hành MySQL trong production._

## Topics / Chủ Đề

| File | Topic | Level |
|------|-------|-------|
| [01-prometheus-grafana.md](01-prometheus-grafana.md) | Metrics collection & visualization | Expert |
| [02-mysql-exporters.md](02-mysql-exporters.md) | mysqld_exporter setup & metrics | Expert |
| [03-incident-response-playbooks.md](03-incident-response-playbooks.md) | Structured IR runbooks | Expert |
| [04-deadlock-diagnosis.md](04-deadlock-diagnosis.md) | Deadlock forensics | Expert |
| [05-replication-failure-recovery.md](05-replication-failure-recovery.md) | Replication incident recovery | Expert |
| [06-slow-query-incidents.md](06-slow-query-incidents.md) | Live slow query debugging | Expert |
| [07-capacity-planning.md](07-capacity-planning.md) | Workload forecasting & sizing | Expert |

## Learning Outcomes / Kết Quả Học Tập

- ✅ Set up Prometheus + Grafana for MySQL monitoring
- ✅ Build alerting rules for replication lag, connection storms, disk pressure
- ✅ Follow structured incident response runbooks
- ✅ Diagnose deadlocks from `SHOW ENGINE INNODB STATUS`
- ✅ Recover from replication failures systematically
- ✅ Forecast capacity needs based on growth metrics

## Key MySQL Metrics to Monitor / Số Liệu MySQL Quan Trọng Cần Theo Dõi

```
Performance / Hiệu Năng:
  mysql_global_status_questions            — QPS
  mysql_global_status_slow_queries         — Slow query count
  mysql_global_status_innodb_row_lock_time — Lock wait time

Replication / Sao Chép:
  mysql_slave_status_seconds_behind_master  — Replication lag
  mysql_slave_status_slave_io_running       — IO thread health
  mysql_slave_status_slave_sql_running      — SQL thread health

InnoDB:
  mysql_global_status_innodb_buffer_pool_reads       — Disk reads (cache misses)
  mysql_global_status_innodb_buffer_pool_read_requests — Total requests
  mysql_global_variables_innodb_buffer_pool_size       — Pool size

Connections / Kết Nối:
  mysql_global_status_threads_connected    — Current connections
  mysql_global_variables_max_connections   — Connection limit
  mysql_global_status_connection_errors_*  — Connection errors
```

## Alerting Rules Summary / Tóm Tắt Quy Tắc Cảnh Báo

| Alert | Condition | Severity |
|-------|-----------|----------|
| Replication Lag | `> 30s` | Warning |
| Replication Lag | `> 120s` | Critical |
| Connection Usage | `> 80%` of max | Warning |
| Buffer Pool Hit Rate | `< 99%` | Warning |
| Disk Usage | `> 85%` | Warning |
| Slave IO/SQL Not Running | Any | Critical |
| Long Running Transaction | `> 60s` | Warning |

## Incident Response Flow / Luồng Xử Lý Sự Cố

```
Alert fires / Cảnh báo kích hoạt
    │
    ▼
Acknowledge & assess severity / Xác nhận & đánh giá mức độ
    │
    ├── P1 (Critical): Page on-call immediately
    │
    ├── P2 (High): Respond within 30 minutes
    │
    └── P3 (Low): Respond within 4 hours
         │
         ▼
    Follow runbook / Thực hiện runbook
         │
         ▼
    Mitigate & recover / Giảm thiểu & phục hồi
         │
         ▼
    Post-mortem (blameless) / Phân tích sau sự cố (không đổ lỗi)
```

## See Also / Xem Thêm

- [Labs — Deadlock Analysis](../../labs/lab-01-deadlock-analysis/README.md)
- [Labs — Replication Lag](../../labs/lab-02-replication-lag/README.md)
- [Monitoring configs](../../monitoring/)

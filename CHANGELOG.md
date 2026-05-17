# Changelog / Nhật Ký Thay Đổi

All notable changes to this project will be documented in this file.
_Tất cả thay đổi đáng chú ý của dự án này đều được ghi lại trong file này._

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Planned / Kế Hoạch
- Stage-by-stage progress tracking badges
- Interactive lab solution checker scripts
- Additional Kubernetes operators (Percona XtraDB Cluster Operator)

---

## [1.1.0] — 2026-05-17

### Added / Thêm Mới
- `diagrams/` directory with 6 Mermaid architecture diagrams:
  - `mysql-architecture-overview.md` — Full system topology
  - `innodb-internals.md` — InnoDB memory & disk layout
  - `replication-topology.md` — GTID + InnoDB Cluster + failover flow
  - `distributed-architecture.md` — Vitess sharding + ProxySQL routing
  - `etl-pipeline.md` — CDC + Airflow + Outbox Pattern
  - `monitoring-stack.md` — Prometheus + Grafana + Alertmanager
- `monitoring/grafana/dashboards/mysql-production-overview.json` — Importable Grafana dashboard
- `monitoring/grafana/provisioning/dashboards.yml` — Auto-provisioning config
- `labs/lab-01-deadlock-analysis/solution.md` — Full root cause analysis & fix guide
- `*.txt` pattern added to `.gitignore` to exclude draft source files

### Fixed / Sửa Lỗi
- README.md: Removed duplicate `H1` heading (merged English + Vietnamese titles)
- `docker-compose.monitoring.yml`: Fixed Grafana default dashboard path + added provisioning mount

---

## [1.0.0] — 2026-05-09

### Added / Thêm Mới
- Initial repository structure with 8-stage roadmap
- `docs/` — All 8 stage folders with bilingual documentation
  - Stage 0: Data Modeling (11 topic files)
  - Stage 1–7: MySQL Fundamentals through Observability & SRE
- `labs/` — 8 production hands-on labs
  - Lab 01: Deadlock Analysis
  - Lab 02: Replication Lag
  - Lab 03: PITR Recovery
  - Lab 04: Query Optimization
  - Lab 05: Online Migration (gh-ost)
  - Lab 06: CDC Streaming (Debezium + Kafka)
  - Lab 07: Sharding Simulation (Vitess)
  - Lab 08: Warehouse ETL (Airflow + dbt)
- `sample-db/shop_db/` — Full OLTP schema + seed data
- `sample-db/analytics_dw/` — Star schema warehouse
- `docker/` — Dev, replication, and monitoring compose stacks
- `kubernetes/` — MySQL StatefulSet manifests
- `monitoring/` — Prometheus config + alert rules
- `replication/` — GTID setup scripts + failover procedure
- `scripts/` — Backup, maintenance, and monitoring scripts
- `etl/` — Airflow DAG + dbt models
- `cdc/` — Debezium connector config
- `benchmarks/` — sysbench OLTP workload
- `README.md` — Bilingual EN/VI full roadmap documentation
- `CONTRIBUTING.md`, `LICENSE.md`, `.gitignore`

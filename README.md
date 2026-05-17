# 🐬 MySQL Infrastructure & Database Engineering Roadmap
### Lộ Trình Kỹ Thuật Hạ Tầng MySQL & Cơ Sở Dữ Liệu

**From SQL Fundamentals → Distributed Data Platforms → Production Database Infrastructure**  
_Từ Nền Tảng SQL → Nền Tảng Dữ Liệu Phân Tán → Hạ Tầng Cơ Sở Dữ Liệu Production_

[![CI](https://github.com/duongbaophuoc/mysql-for-me/actions/workflows/ci.yml/badge.svg)](https://github.com/duongbaophuoc/mysql-for-me/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-blue?logo=mysql&logoColor=white)](https://docs.oracle.com/cd/E17952_01/mysql-8.0-en/)
[![Stages](https://img.shields.io/badge/Stages-8-green)](docs/)
[![Labs](https://img.shields.io/badge/Labs-8-orange)](labs/)
[![Diagrams](https://img.shields.io/badge/Diagrams-6-purple)](diagrams/)

> **This is not a CRUD tutorial. This roadmap teaches how MySQL is used in real production systems.**
>
> **Đây không phải hướng dẫn CRUD. Lộ trình này dạy cách MySQL được sử dụng trong các hệ thống production thực tế.**

---

## 🎯 Target Roles / Đối Tượng Mục Tiêu

| Role / Vai Trò                          | Coverage / Phạm Vi |
| --------------------------------------- | ------------------ |
| Backend Engineer                        | ✅                  |
| Senior Backend Engineer                 | ✅                  |
| SQL Infrastructure Engineer             | ✅                  |
| Database Engineer / Kỹ sư CSDL          | ✅                  |
| MySQL DBA                               | ✅                  |
| Site Reliability Engineer               | ✅                  |
| Data Engineer / Kỹ sư Dữ liệu          | ✅                  |
| Data Warehouse Engineer                 | ✅                  |
| Distributed Systems Engineer            | ✅                  |
| Platform Engineer / Kỹ sư Nền tảng     | ✅                  |

---

## 📌 Roadmap Philosophy / Triết Lý Lộ Trình

Most SQL tutorials teach SELECT, INSERT, JOIN, basic indexing.
_Hầu hết hướng dẫn SQL chỉ dạy SELECT, INSERT, JOIN, index cơ bản._

Real database engineering requires understanding:
_Kỹ thuật cơ sở dữ liệu thực tế đòi hỏi hiểu rõ:_

- How storage engines work / Cách storage engine hoạt động
- How distributed systems behave / Hành vi hệ thống phân tán
- How replication fails / Cách replication thất bại
- How locks & MVCC interact / Tương tác giữa lock và MVCC
- How backups are recovered / Quy trình khôi phục backup
- How observability is implemented / Triển khai observability
- How large-scale data systems evolve / Sự tiến hóa của hệ thống dữ liệu lớn
- How analytics pipelines are built / Xây dựng pipeline analytics
- How to operate databases safely under production traffic / Vận hành DB an toàn dưới tải production

---

## 🗺️ Learning Architecture / Kiến Trúc Học Tập

| Stage / Giai Đoạn | Focus / Trọng Tâm                                         | Level / Cấp Độ     |
| ----------------- | --------------------------------------------------------- | ------------------- |
| 🟢 Stage 0        | Relational Modeling & Data Architecture                   | Foundations         |
| 🟢 Stage 1        | SQL & MySQL Fundamentals                                  | Beginner            |
| 🟡 Stage 2        | Backend Integration & Application Data Layer              | Intermediate        |
| 🔴 Stage 3        | InnoDB Internals & Performance Engineering                | Advanced            |
| 🟣 Stage 4        | Production Operations & Reliability                       | Production          |
| ⚫ Stage 5         | Distributed Systems & Scalability                         | Infrastructure      |
| 🟤 Stage 6        | Data Engineering & Warehousing                            | Data Platform       |
| 🔵 Stage 7        | Observability, SRE & Incident Engineering                 | Expert              |

---

## 🟢 Stage 0 — Data Modeling & Database Architecture
## 🟢 Giai Đoạn 0 — Mô Hình Hóa Dữ Liệu & Kiến Trúc CSDL

> Most production problems begin with bad schema design.
> _Hầu hết vấn đề production bắt đầu từ thiết kế schema tệ._

📁 [`docs/stage-0-data-modeling/`](docs/stage-0-data-modeling/README.md)

| Topic / Chủ Đề                 | Description / Mô Tả                                    |
| ------------------------------ | ------------------------------------------------------ |
| ERD Design                     | Entities, relationships, cardinality                   |
| Normalization / Chuẩn hóa      | 1NF → 3NF                                              |
| Denormalization / Phi chuẩn hóa | Read-heavy optimization                               |
| OLTP vs OLAP Modeling          | Transactional vs analytical design                     |
| Fact & Dimension Tables        | Star & snowflake schemas                               |
| Slowly Changing Dimensions     | SCD Type 1/2/3                                         |
| Surrogate vs Natural Keys      | Identifier strategies / Chiến lược định danh           |
| UUID v7 vs AUTO_INCREMENT       | Scalability trade-offs / Đánh đổi về khả năng mở rộng |
| Hierarchical Data              | Trees, nested sets, adjacency lists                    |
| Audit Columns / Cột kiểm toán  | created_at, updated_at                                 |
| Soft Delete Patterns           | deleted_at architecture / Kiến trúc xóa mềm           |
| Multi-tenant Design            | Shared vs isolated schemas                             |

---

## 🟢 Stage 1 — MySQL Fundamentals
## 🟢 Giai Đoạn 1 — Nền Tảng MySQL

📁 [`docs/stage-1-mysql-fundamentals/`](docs/stage-1-mysql-fundamentals/README.md)

| Topic / Chủ Đề                  | Description / Mô Tả                                 |
| ------------------------------- | --------------------------------------------------- |
| Docker Setup                    | Local infrastructure / Hạ tầng cục bộ              |
| Data Types / Kiểu Dữ Liệu      | INT, BIGINT, JSON, DATETIME                         |
| DDL / DML                       | CREATE, ALTER, DROP, CRUD                           |
| JOINs                           | Relational querying / Truy vấn quan hệ              |
| Aggregation                     | GROUP BY, HAVING                                    |
| Window Functions                | Ranking & analytics / Xếp hạng & phân tích         |
| CTEs                            | Recursive queries / Truy vấn đệ quy                |
| Views / Khung nhìn              | Logical abstractions / Trừu tượng hóa logic        |
| Stored Procedures               | Server-side logic / Logic phía server               |
| Triggers                        | Event-driven logic / Logic hướng sự kiện           |
| Storage Engines                 | InnoDB, MyISAM, MEMORY, ARCHIVE                    |

---

## 🟡 Stage 2 — Backend & Application Data Layer
## 🟡 Giai Đoạn 2 — Backend & Tầng Dữ Liệu Ứng Dụng

📁 [`docs/stage-2-backend-integration/`](docs/stage-2-backend-integration/README.md)

| Topic / Chủ Đề              | Description / Mô Tả                                       |
| --------------------------- | --------------------------------------------------------- |
| ORM Integration             | Hibernate, Prisma, Sequelize, SQLAlchemy                  |
| N+1 Problem                 | Query explosion / Bùng nổ truy vấn                       |
| Connection Pooling          | HikariCP, DBCP2                                           |
| Pagination Strategies       | Offset vs cursor / Phân trang theo offset vs con trỏ     |
| CQRS Patterns               | Command-query segregation / Phân tách lệnh-truy vấn      |
| Idempotency / Mãn đẳng      | Distributed consistency / Nhất quán phân tán             |
| Distributed Transactions    | Saga patterns / Mẫu Saga                                  |

---

## 🔴 Stage 3 — InnoDB Internals & Performance Engineering
## 🔴 Giai Đoạn 3 — Nội Tại InnoDB & Kỹ Thuật Hiệu Năng

📁 [`docs/stage-3-innodb-internals/`](docs/stage-3-innodb-internals/README.md)

| Topic / Chủ Đề              | Description / Mô Tả                                  |
| --------------------------- | ---------------------------------------------------- |
| Clustered Index             | Primary key storage / Lưu trữ khóa chính            |
| B+ Tree Internals           | Page organization / Tổ chức trang                   |
| Buffer Pool                 | Memory caching / Bộ nhớ đệm                         |
| MVCC                        | Snapshot isolation / Cô lập snapshot                |
| Undo / Redo Log             | WAL durability / Độ bền WAL                         |
| Isolation Levels           | RC, RR, Serializable                                 |
| Gap Locks / Next-Key Locks  | Phantom prevention / Ngăn chặn phantom              |
| Deadlocks / Bế tắc          | Detection & resolution / Phát hiện & giải quyết     |
| EXPLAIN ANALYZE             | Query plans / Kế hoạch thực thi                     |
| Slow Query Log              | Bottleneck analysis / Phân tích nút cổ chai         |
| Online DDL / gh-ost         | Zero-downtime migrations                             |

---

## 🟣 Stage 4 — Production Operations & Reliability
## 🟣 Giai Đoạn 4 — Vận Hành Production & Độ Tin Cậy

📁 [`docs/stage-4-production-operations/`](docs/stage-4-production-operations/README.md)

| Topic / Chủ Đề           | Description / Mô Tả                                   |
| ------------------------ | ----------------------------------------------------- |
| Binary Logs / Binlog      | Replication foundation / Nền tảng replication        |
| GTID Replication          | Transaction tracking / Theo dõi giao dịch            |
| Replication Lag           | Diagnosis & mitigation / Chẩn đoán & giảm thiểu     |
| InnoDB Cluster            | HA deployment / Triển khai độ sẵn sàng cao           |
| Failover Strategies       | Automated recovery / Phục hồi tự động                |
| mysqldump / XtraBackup    | Backup strategies / Chiến lược backup                |
| PITR                      | Point-in-time recovery / Phục hồi theo thời điểm    |
| Disaster Recovery         | Multi-region recovery / Phục hồi đa vùng            |
| Security / Bảo Mật        | Users, roles, SSL/TLS, audit logging                 |

---

## ⚫ Stage 5 — Distributed Systems & Scalability
## ⚫ Giai Đoạn 5 — Hệ Thống Phân Tán & Khả Năng Mở Rộng

📁 [`docs/stage-5-distributed-systems/`](docs/stage-5-distributed-systems/README.md)

| Topic / Chủ Đề             | Description / Mô Tả                                      |
| -------------------------- | -------------------------------------------------------- |
| Sharding / Phân mảnh       | Data partitioning / Phân vùng dữ liệu                   |
| Consistent Hashing         | Distributed routing / Định tuyến phân tán               |
| Vitess                     | Planet-scale MySQL                                       |
| ProxySQL                   | Query routing / Định tuyến truy vấn                     |
| CAP Theorem                | Consistency trade-offs / Đánh đổi nhất quán             |
| CDC / Debezium             | Change Data Capture / Bắt thay đổi dữ liệu             |
| Kafka Integration          | Event pipelines / Pipeline sự kiện                      |
| Outbox Pattern             | Reliable events / Sự kiện đáng tin cậy                  |
| Multi-region               | Global deployments / Triển khai toàn cầu                |

---

## 🟤 Stage 6 — Data Engineering & Warehousing
## 🟤 Giai Đoạn 6 — Kỹ Thuật Dữ Liệu & Kho Dữ Liệu

📁 [`docs/stage-6-data-engineering/`](docs/stage-6-data-engineering/README.md)

| Topic / Chủ Đề              | Description / Mô Tả                                   |
| --------------------------- | ----------------------------------------------------- |
| Star / Snowflake Schema     | Analytics modeling / Mô hình phân tích               |
| ETL vs ELT                  | Data movement paradigms / Mô hình di chuyển dữ liệu  |
| Incremental Loading         | Efficient sync / Đồng bộ hiệu quả                    |
| CDC Pipelines               | Binlog ingestion / Tiếp nhận binlog                  |
| dbt                         | Transformation pipelines / Pipeline biến đổi         |
| Airflow                     | Workflow orchestration / Điều phối workflow           |
| Spark Integration           | Distributed analytics / Phân tích phân tán           |
| BI Integration              | Tableau / Power BI                                   |

---

## 🔵 Stage 7 — Observability, SRE & Incident Engineering
## 🔵 Giai Đoạn 7 — Quan Sát, SRE & Kỹ Thuật Xử Lý Sự Cố

📁 [`docs/stage-7-observability/`](docs/stage-7-observability/README.md)

| Topic / Chủ Đề           | Description / Mô Tả                                         |
| ------------------------ | ----------------------------------------------------------- |
| Prometheus + Grafana     | Metrics & dashboards / Số liệu & bảng điều khiển          |
| MySQL Exporters          | Infrastructure metrics / Số liệu hạ tầng                  |
| Incident Response        | Deadlocks, replication failure, disk full                   |
| Slow Query Incidents     | Performance debugging / Gỡ lỗi hiệu năng                  |
| Capacity Planning        | CPU, memory, storage sizing / Định cỡ tài nguyên           |

---

## 🧪 Production Labs / Lab Thực Hành Production

| Lab                                                | Focus / Trọng Tâm                              |
| -------------------------------------------------- | ---------------------------------------------- |
| [Lab 01 — Deadlock Analysis](labs/lab-01-deadlock-analysis/README.md)   | Transaction debugging / Gỡ lỗi giao dịch |
| [Lab 02 — Replication Lag](labs/lab-02-replication-lag/README.md)       | Replica troubleshooting / Xử lý replica  |
| [Lab 03 — PITR Recovery](labs/lab-03-pitr-recovery/README.md)           | Disaster recovery / Phục hồi thảm họa   |
| [Lab 04 — Query Optimization](labs/lab-04-query-optimization/README.md) | Slow query tuning / Tối ưu truy vấn chậm|
| [Lab 05 — Online Migration](labs/lab-05-online-migration/README.md)     | Zero-downtime DDL / DDL không gián đoạn |
| [Lab 06 — CDC Streaming](labs/lab-06-cdc-streaming/README.md)           | Kafka + Debezium                         |
| [Lab 07 — Sharding Simulation](labs/lab-07-sharding-simulation/README.md)| Distributed routing                     |
| [Lab 08 — Warehouse ETL](labs/lab-08-warehouse-etl/README.md)           | Analytics pipelines / Pipeline phân tích|

---

## 🗂️ Sample Systems / Hệ Thống Mẫu

### OLTP Database — `shop_db`

| Table / Bảng | Purpose / Mục Đích                         |
| ------------ | ------------------------------------------ |
| customers    | Customer accounts / Tài khoản khách hàng  |
| products     | Product catalog / Danh mục sản phẩm       |
| orders       | Transactional orders / Đơn hàng           |
| order_items  | Order details / Chi tiết đơn hàng         |
| payments     | Financial transactions / Giao dịch tài chính |
| inventory    | Stock management / Quản lý tồn kho        |

→ [`sample-db/shop_db/`](sample-db/shop_db/README.md)

### OLAP Warehouse — `analytics_dw`

| Table / Bảng  | Purpose / Mục Đích                         |
| ------------- | ------------------------------------------ |
| fact_sales    | Sales metrics / Số liệu bán hàng          |
| dim_customer  | Customer dimensions / Chiều khách hàng    |
| dim_product   | Product dimensions / Chiều sản phẩm       |
| dim_date      | Time hierarchy / Phân cấp thời gian       |

→ [`sample-db/analytics_dw/`](sample-db/analytics_dw/README.md)

---

## 🗓️ Architecture Diagrams / Sơ Đồ Kiến Trúc

_All diagrams are written in [Mermaid](https://mermaid.js.org/) and render natively on GitHub._  
_Tất cả sơ đồ được viết bằng Mermaid và hiển thị trực tiếp trên GitHub._

| Diagram / Sơ Đồ | Description / Mô Tả |
| --- | --- |
| [🌐 System Architecture](diagrams/mysql-architecture-overview.md) | Full production topology with ProxySQL, replicas, CDC, monitoring |
| [🧠 InnoDB Internals](diagrams/innodb-internals.md) | Buffer pool, redo/undo log, B+ tree, MVCC layout |
| [🔄 Replication Topology](diagrams/replication-topology.md) | GTID replication, InnoDB Cluster, failover sequence |
| [🌐 Distributed Architecture](diagrams/distributed-architecture.md) | Vitess sharding, ProxySQL read/write split, CAP trade-offs |
| [🔄 ETL / CDC Pipeline](diagrams/etl-pipeline.md) | Debezium + Kafka, Airflow DAG, Outbox Pattern |
| [📊 Monitoring Stack](diagrams/monitoring-stack.md) | Prometheus + Grafana + Alertmanager flow |

---

## 📁 Repository Structure / Cấu Trúc Repository

```text
mysql-infra-engineering-roadmap/
│
├── docs/
│   ├── stage-0-data-modeling/
│   ├── stage-1-mysql-fundamentals/
│   ├── stage-2-backend-integration/
│   ├── stage-3-innodb-internals/
│   ├── stage-4-production-operations/
│   ├── stage-5-distributed-systems/
│   ├── stage-6-data-engineering/
│   └── stage-7-observability/
│
├── sample-db/
│   ├── shop_db/         ← OLTP schema + seed data
│   └── analytics_dw/   ← Star schema warehouse
│
├── docker/              ← Full dev/replication/monitoring stacks
├── replication/         ← GTID setup, failover scripts
├── labs/                ← 8 hands-on production labs
├── scripts/             ← Backup, monitoring, maintenance
├── monitoring/          ← Prometheus + Grafana configs
├── etl/                 ← Airflow DAGs + dbt models
├── cdc/                 ← Debezium connector configs
├── kubernetes/          ← MySQL StatefulSet manifests
├── benchmarks/          ← sysbench workloads
└── diagrams/            ← Architecture diagrams
```

---

## 🐳 Quick Start / Khởi Động Nhanh

```bash
# Start full dev environment / Khởi động môi trường dev đầy đủ
docker compose -f docker/docker-compose.yml up -d

# Start with replication / Khởi động với replication
docker compose -f docker/docker-compose.replication.yml up -d

# Start monitoring stack / Khởi động stack monitoring
docker compose -f docker/docker-compose.monitoring.yml up -d

# Connect to MySQL / Kết nối MySQL
mysql -h 127.0.0.1 -P 3306 -u root -psecret

# Connect with MySQL Shell / Kết nối với MySQL Shell
mysqlsh root@localhost:3306
```

---

## 🛠️ Recommended Tooling / Công Cụ Khuyến Nghị

| Tool            | Purpose / Mục Đích                         |
| --------------- | ------------------------------------------ |
| MySQL Shell     | Modern CLI / CLI hiện đại                 |
| DBeaver         | Universal GUI / GUI đa năng               |
| ProxySQL        | Query routing / Định tuyến truy vấn       |
| Vitess          | Sharding infrastructure / Hạ tầng sharding|
| Percona Toolkit | Diagnostics / Chẩn đoán                   |
| Prometheus      | Monitoring / Giám sát                     |
| Grafana         | Visualization / Trực quan hóa             |
| Airflow         | ETL orchestration / Điều phối ETL         |
| dbt             | Data transformations / Biến đổi dữ liệu  |
| Kafka           | Event streaming / Truyền phát sự kiện     |
| Debezium        | CDC pipelines / Pipeline CDC              |

---

## 📚 Recommended Reading / Tài Liệu Khuyến Đọc

### MySQL
- *High Performance MySQL* — Baron Schwartz et al.
- *MySQL 8.0 Reference Manual*
- *Efficient MySQL Performance* — Daniel Nichter

### Distributed Systems / Hệ Thống Phân Tán
- *Designing Data-Intensive Applications* — Martin Kleppmann
- *Database Internals* — Alex Petrov
- *Site Reliability Engineering* — Google

### Data Engineering / Kỹ Thuật Dữ Liệu
- *Fundamentals of Data Engineering* — Joe Reis, Matt Housley
- *Streaming Systems* — Tyler Akidau et al.
- *The Data Warehouse Toolkit* — Ralph Kimball

---

## 🚀 Final Goal / Mục Tiêu Cuối Cùng

By the end of this roadmap, you will be able to:
_Sau khi hoàn thành lộ trình này, bạn sẽ có thể:_

✅ Design production-grade relational schemas / Thiết kế schema quan hệ cấp production  
✅ Understand InnoDB internals deeply / Hiểu sâu về nội tại InnoDB  
✅ Diagnose replication & locking problems / Chẩn đoán vấn đề replication & lock  
✅ Operate MySQL clusters safely / Vận hành MySQL cluster an toàn  
✅ Build distributed database systems / Xây dựng hệ thống CSDL phân tán  
✅ Design scalable ETL & CDC pipelines / Thiết kế ETL & CDC pipeline có thể mở rộng  
✅ Build data warehouse architectures / Xây dựng kiến trúc kho dữ liệu  
✅ Monitor and troubleshoot production databases / Giám sát và xử lý sự cố DB production  
✅ Recover systems during operational failures / Phục hồi hệ thống khi xảy ra sự cố  
✅ Work as a SQL Infrastructure / Database Engineer professionally / Làm việc chuyên nghiệp với tư cách Kỹ sư Hạ tầng SQL / CSDL  

---

## 🤝 Contributing / Đóng Góp

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.  
_Xem [CONTRIBUTING.md](CONTRIBUTING.md) để biết hướng dẫn đóng góp._

See [CHANGELOG.md](CHANGELOG.md) for version history.  
_Xem [CHANGELOG.md](CHANGELOG.md) để xem lịch sử phiên bản._

---

<div align="center">
  <strong>Built for production engineers. Not for beginners who just want CRUD.</strong><br>
  <em>Được xây dựng cho các kỹ sư production. Không phải cho người mới chỉ muốn làm CRUD.</em><br><br>
  <a href="https://github.com/duongbaophuoc/mysql-for-me/actions"><img src="https://github.com/duongbaophuoc/mysql-for-me/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT License"></a>
</div>

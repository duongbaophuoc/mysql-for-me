# 📐 Architecture Diagrams / Sơ Đồ Kiến Trúc

This directory contains architecture diagrams for the MySQL Infrastructure Engineering Roadmap.
_Thư mục này chứa các sơ đồ kiến trúc cho Lộ Trình Kỹ Thuật Hạ Tầng MySQL._

---

## 📁 Diagrams / Sơ Đồ

| File | Description / Mô Tả |
|------|----------------------|
| [mysql-architecture-overview.md](mysql-architecture-overview.md) | Full system architecture / Kiến trúc hệ thống tổng quan |
| [innodb-internals.md](innodb-internals.md) | InnoDB storage engine internals / Nội tại storage engine InnoDB |
| [replication-topology.md](replication-topology.md) | Replication & HA topology / Cấu trúc replication & HA |
| [distributed-architecture.md](distributed-architecture.md) | Sharding & distributed topology / Kiến trúc phân tán & sharding |
| [etl-pipeline.md](etl-pipeline.md) | ETL/CDC data pipeline / Pipeline dữ liệu ETL/CDC |
| [monitoring-stack.md](monitoring-stack.md) | Observability stack / Stack giám sát |

---

## 🛠️ Tools Used / Công Cụ Sử Dụng

Diagrams are written in [Mermaid](https://mermaid.js.org/) — rendered natively on GitHub.
_Sơ đồ được viết bằng Mermaid — hiển thị trực tiếp trên GitHub._

To render locally:
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i diagram.md -o diagram.png
```

# CDC — Change Data Capture
# CDC — Bắt Thay Đổi Dữ Liệu

## Overview / Tổng Quan

Change Data Capture (CDC) is a pattern for capturing row-level changes (INSERT, UPDATE, DELETE) from a MySQL database and streaming them to downstream systems in real-time.
_CDC là mẫu thiết kế để bắt các thay đổi cấp hàng từ MySQL và stream đến hệ thống downstream theo thời gian thực._

---

## How CDC Works with MySQL / Cách CDC Hoạt Động với MySQL

```
MySQL Binary Log (ROW format)
    │
    ├── INSERT events → {op: "c", after: {new row data}}
    ├── UPDATE events → {op: "u", before: {old}, after: {new}}
    └── DELETE events → {op: "d", before: {old row data}}
```

MySQL's binary log (binlog) in ROW format contains the complete before/after state of every changed row. Debezium reads this log as a replica would, without running additional queries.
_Binary log MySQL ở định dạng ROW chứa trạng thái đầy đủ trước/sau mỗi hàng đã thay đổi._

---

## Files / Tập Tin

| File | Description |
|------|-------------|
| [`debezium-connector.json`](debezium-connector.json) | Debezium MySQL connector config |

---

## Quick Setup / Thiết Lập Nhanh

```bash
# Start the CDC lab stack / Khởi động stack CDC lab
docker compose -f ../labs/lab-06-cdc-streaming/docker-compose.yml up -d

# Register connector / Đăng ký connector
curl -X POST http://localhost:8083/connectors \
     -H "Content-Type: application/json" \
     -d @debezium-connector.json

# Watch topics / Xem topic
docker exec kafka-cdc kafka-topics.sh \
    --bootstrap-server localhost:9092 --list | grep shopdb
```

---

## Use Cases / Trường Hợp Sử Dụng

| Use Case | Description |
|----------|-------------|
| Analytics Sync | OLTP → Data Warehouse / OLTP → Kho dữ liệu |
| Search Indexing | MySQL → Elasticsearch |
| Cache Invalidation | DB change → Redis invalidate |
| Event Sourcing | Capture all state changes |
| Microservices | Shop DB → Payment Service events |

---

## See Also / Xem Thêm

- [Lab 06 — CDC Streaming](../labs/lab-06-cdc-streaming/README.md)
- [Stage 5 — CDC Debezium](../docs/stage-5-distributed-systems/06-cdc-debezium.md)

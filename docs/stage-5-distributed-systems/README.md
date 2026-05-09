# ⚫ Stage 5 — Distributed Systems & Scalability
# ⚫ Giai Đoạn 5 — Hệ Thống Phân Tán & Khả Năng Mở Rộng

> **"Scaling MySQL is not about running faster — it's about doing less on each node."**
> _"Mở rộng MySQL không phải chạy nhanh hơn — mà là làm ít hơn trên mỗi node."_

## Overview / Tổng Quan

When a single MySQL instance is no longer sufficient, you enter the world of distributed database systems. This stage covers sharding, distributed routing, CDC, and global database deployments.
_Khi một MySQL instance không còn đủ, bạn bước vào thế giới hệ thống CSDL phân tán._

## Topics / Chủ Đề

| File | Topic | Level |
|------|-------|-------|
| [01-sharding.md](01-sharding.md) | Horizontal partitioning strategies | Infrastructure |
| [02-consistent-hashing.md](02-consistent-hashing.md) | Hash ring, virtual nodes | Infrastructure |
| [03-vitess.md](03-vitess.md) | Planet-scale MySQL with Vitess | Infrastructure |
| [04-proxysql.md](04-proxysql.md) | Query routing & connection pooling | Infrastructure |
| [05-cap-theorem.md](05-cap-theorem.md) | CAP, PACELC, consistency models | Architecture |
| [06-cdc-debezium.md](06-cdc-debezium.md) | Change Data Capture with Debezium | Infrastructure |
| [07-kafka-integration.md](07-kafka-integration.md) | MySQL → Kafka event streaming | Infrastructure |
| [08-outbox-pattern.md](08-outbox-pattern.md) | Reliable event publishing | Architecture |
| [09-multi-region.md](09-multi-region.md) | Global read replicas, write routing | Expert |

## Learning Outcomes / Kết Quả Học Tập

- ✅ Design and implement MySQL sharding strategies
- ✅ Use Vitess for planet-scale MySQL deployments
- ✅ Configure ProxySQL for intelligent query routing
- ✅ Set up Debezium for real-time Change Data Capture
- ✅ Build reliable event publishing with the Outbox pattern
- ✅ Understand CAP theorem trade-offs in distributed databases

## Scaling Decision Tree / Cây Quyết Định Mở Rộng

```
Is your MySQL single instance overloaded?
Phiên bản MySQL đơn của bạn có bị quá tải không?
│
├─ Write throughput too high?     → Sharding / Vitess
│  Thông lượng ghi quá cao?
│
├─ Read throughput too high?      → Read replicas + ProxySQL
│  Thông lượng đọc quá cao?
│
├─ Single table too large?        → Table partitioning
│  Bảng đơn quá lớn?
│
├─ Need real-time data sync?      → CDC + Debezium + Kafka
│  Cần đồng bộ dữ liệu real-time?
│
└─ Geographic distribution?       → Multi-region replicas
   Phân phối địa lý?
```

## CDC Architecture / Kiến Trúc CDC

```
┌──────────────┐    binlog    ┌───────────────┐    events    ┌──────────────┐
│    MySQL     │ ──────────► │   Debezium    │ ──────────► │    Kafka     │
│  (Primary)   │             │  (Connector)  │              │  (Topic)     │
└──────────────┘             └───────────────┘              └──────┬───────┘
                                                                   │
                             ┌─────────────────────────────────────┤
                             │                                     │
                    ┌────────▼──────┐                   ┌─────────▼────────┐
                    │  analytics_dw │                   │  Search Index    │
                    │  (warehouse)  │                   │  (Elasticsearch) │
                    └───────────────┘                   └──────────────────┘
```

## Next Stage / Giai Đoạn Tiếp Theo

→ [Stage 6 — Data Engineering](../stage-6-data-engineering/README.md)

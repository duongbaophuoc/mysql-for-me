# CDC Pipelines for Analytics / Pipeline CDC Cho Phân Tích

## Overview / Tổng Quan

CDC (Change Data Capture) pipelines stream row-level changes from MySQL into analytics destinations **in real-time** — avoiding nightly ETL batch delays.
_Pipeline CDC stream thay đổi cấp hàng từ MySQL đến đích phân tích **theo thời gian thực** — tránh độ trễ batch ETL hàng đêm._

---

## CDC Pipeline Architecture / Kiến Trúc Pipeline CDC

```
MySQL (shop_db)
    │
    ├── Binary Log (ROW format)
    │
    ▼
Debezium MySQL Connector
    │
    ├── shop_db.orders   → Kafka topic prod.shop_db.orders
    ├── shop_db.products → Kafka topic prod.shop_db.products
    └── shop_db.customers→ Kafka topic prod.shop_db.customers
    │
    ▼
Kafka Streams / Faust / Spark Structured Streaming
    │ (Transform & enrich / Biến đổi & làm phong phú)
    │
    ▼
Analytics Destination / Đích Phân Tích
    ├── analytics_dw (MySQL)
    ├── ClickHouse / BigQuery
    └── Elasticsearch (search)
```

---

## Debezium Event Structure / Cấu Trúc Sự Kiện Debezium

```json
{
  "schema": { ... },
  "payload": {
    "before": null,
    "after": {
      "id": 100,
      "customer_id": 5,
      "status": "confirmed",
      "total_amount": 450000,
      "updated_at": 1734100000000
    },
    "source": {
      "db": "shop_db",
      "table": "orders",
      "ts_ms": 1734100000000,
      "gtid": "3E11FA47:100",
      "pos": 4294967295
    },
    "op": "u",       ← "c"=create, "u"=update, "d"=delete, "r"=read/snapshot
    "ts_ms": 1734100001234
  }
}
```

---

## Consumer: Faust (Python Streams) / Consumer: Faust

```python
import faust
import json
from datetime import datetime

app = faust.App('orders-cdc-consumer', broker='kafka://kafka:9092')

# Kafka topic → Faust topic / Topic Kafka → topic Faust
orders_topic = app.topic('prod.shop_db.orders', value_type=bytes)

@app.agent(orders_topic)
async def process_order_change(changes):
    async for change in changes:
        event = json.loads(change)
        op = event['payload']['op']
        after = event['payload'].get('after', {})
        before = event['payload'].get('before', {})

        if op in ('c', 'u'):          # insert or update
            await sync_to_warehouse(after)
        elif op == 'd':               # delete
            await mark_deleted_in_warehouse(before['id'])

async def sync_to_warehouse(order: dict):
    """Upsert order into analytics_dw / Upsert đơn hàng vào analytics_dw"""
    await warehouse_db.execute("""
        INSERT INTO fact_sales
            (order_nk, date_key, gross_revenue, net_revenue)
        VALUES (%s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
            gross_revenue = VALUES(gross_revenue),
            net_revenue   = VALUES(net_revenue)
    """, (
        order['id'],
        datetime.fromtimestamp(order['updated_at'] / 1000).strftime('%Y%m%d'),
        order['total_amount'],
        order['total_amount'] - order.get('discount_amount', 0)
    ))
```

---

## Initial Snapshot / Snapshot Ban Đầu

When Debezium starts for the first time, it creates a **snapshot** of all existing data before streaming new changes:
_Khi Debezium khởi động lần đầu, nó tạo **snapshot** tất cả dữ liệu hiện có trước khi stream thay đổi mới:_

```json
// Snapshot events have op="r" (read) / Sự kiện snapshot có op="r"
{
  "payload": {
    "op": "r",      ← "r" = snapshot read / đọc snapshot
    "after": { all existing row data }
  }
}
```

```ini
# Control snapshot behavior / Kiểm soát hành vi snapshot
snapshot.mode=initial      # snapshot + then stream   (default)
snapshot.mode=schema_only  # no data snapshot, stream from now
snapshot.mode=never        # skip snapshot, assume tables already loaded
```

---

## CDC vs Batch ETL Comparison / So Sánh CDC vs Batch ETL

| Aspect | Batch ETL | CDC Pipeline |
|--------|-----------|-------------|
| Latency | Hours (nightly) | Seconds |
| Load on source | High (full scan) | Minimal (binlog read) |
| Complexity | Medium | Higher |
| Late data handling | Built-in | Requires care |
| Historical load | Easy (full reload) | Initial snapshot |
| Best for | Reports, DW | Real-time dashboards, alerts |

---

## See Also / Xem Thêm

- [Debezium CDC](../stage-5-distributed-systems/06-cdc-debezium.md)
- [Lab 06 CDC Streaming](../../labs/lab-06-cdc-streaming/README.md)
- [Outbox Pattern](../stage-5-distributed-systems/08-outbox-pattern.md)

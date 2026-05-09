# Kafka Integration with MySQL / Tích Hợp Kafka Với MySQL

## Overview / Tổng Quan

Apache Kafka serves as the **nervous system** of a data platform — a durable, distributed message bus connecting MySQL to downstream systems in real-time.
_Apache Kafka là **hệ thần kinh** của nền tảng dữ liệu — bus thông điệp bền vững, phân tán kết nối MySQL với các hệ thống downstream theo thời gian thực._

---

## Integration Patterns / Mẫu Tích Hợp

```
Pattern 1: CDC via Debezium (recommended)
MySQL binlog → Debezium → Kafka topics → Consumers
(automatic, no application changes / tự động, không thay đổi ứng dụng)

Pattern 2: Application events
Application → Kafka producer → Kafka → Consumers
MySQL → (separately)      ← risk: dual-write problem!

Pattern 3: Outbox + Kafka
MySQL outbox_events → Polling worker → Kafka
(reliable, transactional / đáng tin cậy, giao dịch)
```

---

## Topic Design for MySQL Events / Thiết Kế Topic Cho Sự Kiện MySQL

```
Naming convention / Quy ước đặt tên:
  {environment}.{database}.{table}
  
Topics created by Debezium / Topic do Debezium tạo:
  prod.shop_db.orders           → all order changes
  prod.shop_db.customers        → all customer changes
  prod.shop_db.order_items      → all item changes
  prod.shop_db.outbox_events    → domain events (via outbox)
```

---

## Kafka Producer from Application / Kafka Producer Từ Ứng Dụng

```python
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers=['kafka:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    acks='all',          # wait for all replicas / chờ tất cả replica
    retries=3,
    max_in_flight_requests_per_connection=1,   # preserve ordering
)

def publish_order_event(order_id: int, event_type: str, data: dict):
    """
    Publish order domain event to Kafka.
    Phát sự kiện domain đơn hàng lên Kafka.
    Use order_id as partition key for ordering guarantees.
    Dùng order_id làm partition key để đảm bảo thứ tự.
    """
    producer.send(
        topic=f'prod.shop_db.{event_type}',
        key=str(order_id).encode(),    # same order → same partition → ordered
        value={
            'event_type': event_type,
            'order_id':   order_id,
            'timestamp':  data['updated_at'].isoformat(),
            'payload':    data
        }
    )
    producer.flush()   # ensure delivery before returning / đảm bảo giao trước khi trả về
```

---

## Kafka Consumer — Sync to Analytics / Consumer — Đồng Bộ Phân Tích

```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    'prod.shop_db.orders',
    bootstrap_servers=['kafka:9092'],
    group_id='analytics-warehouse-consumer',
    auto_offset_reset='earliest',
    enable_auto_commit=False,     # manual commit for reliability
    value_deserializer=lambda v: json.loads(v.decode('utf-8'))
)

def sync_orders_to_warehouse():
    for message in consumer:
        event = message.value
        
        # Handle Debezium envelope / Xử lý phong bì Debezium
        if event.get('op') == 'c':   # CREATE
            warehouse_db.insert_fact_sale(event['after'])
        elif event.get('op') == 'u': # UPDATE
            warehouse_db.update_fact_sale(event['after'])
        elif event.get('op') == 'd': # DELETE
            warehouse_db.soft_delete_fact(event['before']['id'])
        
        # Commit offset only after successful processing
        # Commit offset chỉ sau khi xử lý thành công
        consumer.commit()
```

---

## Kafka Connect vs Custom Producer / Kafka Connect vs Producer Tùy Chỉnh

| Approach | When to Use |
|----------|-------------|
| Debezium (Kafka Connect) | CDC from MySQL — no app code changes |
| JDBC Source Connector | Poll-based ingestion from MySQL |
| Custom Producer | Application-generated business events |
| Outbox + Worker | Transactionally reliable event publishing |

---

## Key Kafka Configurations for MySQL Workloads
## Cấu Hình Kafka Quan Trọng Cho Workload MySQL

```properties
# Producer / Nhà sản xuất
acks=all                          # durability / độ bền
enable.idempotence=true           # exactly-once for producer
compression.type=lz4              # compress MySQL row data (high repetition)
batch.size=65536                  # 64KB batches
linger.ms=5                       # wait 5ms to fill batch

# Consumer / Người tiêu dùng
max.poll.records=500              # process 500 messages per poll
max.poll.interval.ms=300000       # 5 min max between polls
isolation.level=read_committed    # only read committed Kafka transactions
```

---

## See Also / Xem Thêm

- [CDC with Debezium](06-cdc-debezium.md)
- [Outbox Pattern](08-outbox-pattern.md)
- [Lab 06 — CDC Streaming](../../labs/lab-06-cdc-streaming/README.md)

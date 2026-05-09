# Outbox Pattern / Mẫu Outbox

## Overview / Tổng Quan

The **Outbox Pattern** solves the dual-write problem: how to atomically write to a database AND publish a message/event.
_**Mẫu Outbox** giải quyết vấn đề ghi kép: làm sao ghi vào CSDL VÀ phát thông điệp/sự kiện nguyên tử._

---

## The Dual-Write Problem / Vấn Đề Ghi Kép

```
❌ Naive approach (unreliable) / Cách đơn giản (không đáng tin cậy):

1. INSERT order into orders table  → SUCCESS
2. Publish OrderCreated to Kafka   → CRASH!

Result / Kết quả:
  - Order in DB but event never published
  - Downstream services (payment, inventory) never notified!
  - Đơn hàng trong DB nhưng sự kiện không bao giờ được phát!
```

---

## The Outbox Solution / Giải Pháp Outbox

```sql
-- outbox_events table (in shop_db schema) / Bảng outbox_events (trong schema shop_db)
CREATE TABLE outbox_events (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    aggregate_id BIGINT UNSIGNED NOT NULL,
    event_type   VARCHAR(100)    NOT NULL,
    payload      JSON            NOT NULL,
    status       ENUM('pending','published','failed') DEFAULT 'pending',
    created_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_pending (status, created_at)
);

-- Atomic write: order + event in ONE transaction / Ghi nguyên tử: đơn hàng + sự kiện
START TRANSACTION;
    INSERT INTO orders (customer_id, total_amount, status)
    VALUES (5, 450000, 'pending');
    
    SET @order_id = LAST_INSERT_ID();
    
    INSERT INTO outbox_events (aggregate_id, event_type, payload)
    VALUES (@order_id, 'OrderCreated', JSON_OBJECT(
        'order_id',    @order_id,
        'customer_id', 5,
        'amount',      450000,
        'timestamp',   NOW()
    ));
COMMIT;

-- Either BOTH succeed or BOTH fail! / Cả hai thành công hoặc thất bại!
```

---

## Publisher Worker / Worker Phát Sự Kiện

```python
# Background worker that polls outbox and publishes
# Worker nền poll outbox và phát sự kiện

import asyncio
import json
from kafka import KafkaProducer

async def outbox_publisher(db, producer: KafkaProducer):
    while True:
        # Fetch pending events in batches / Lấy sự kiện chờ theo lô
        events = await db.query("""
            SELECT id, event_type, payload
            FROM outbox_events
            WHERE status = 'pending'
            ORDER BY created_at ASC
            LIMIT 100
        """)
        
        for event in events:
            try:
                # Publish to Kafka / Phát lên Kafka
                producer.send(
                    topic=event['event_type'],
                    value=json.loads(event['payload']).encode()
                )
                # Mark as published / Đánh dấu đã phát
                await db.execute(
                    "UPDATE outbox_events SET status='published' WHERE id=?",
                    event['id']
                )
            except Exception as e:
                await db.execute(
                    "UPDATE outbox_events SET status='failed' WHERE id=?",
                    event['id']
                )
        
        await asyncio.sleep(0.5)  # Poll every 500ms / Poll mỗi 500ms
```

---

## CDC-Based Outbox (Debezium) / Outbox Dựa Trên CDC

Instead of a polling worker, use Debezium to watch the outbox table:
_Thay vì worker polling, dùng Debezium để theo dõi bảng outbox:_

```json
{
  "table.include.list": "shop_db.outbox_events",
  "transforms": "outbox",
  "transforms.outbox.type": "io.debezium.transforms.outbox.EventRouter",
  "transforms.outbox.route.topic.replacement": "${routedByValue}"
}
```

```
outbox_events INSERT → Debezium reads binlog → Kafka topic (event_type name)
```

**No polling worker needed!** Debezium handles it automatically.
_**Không cần worker polling!** Debezium xử lý tự động._

---

## Cleanup / Dọn Dẹp

```sql
-- Clean up old published events / Dọn sự kiện đã phát cũ
DELETE FROM outbox_events
WHERE status = 'published'
  AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
LIMIT 10000;
```

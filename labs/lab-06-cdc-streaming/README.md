# Lab 06 — CDC Streaming with Debezium + Kafka
# Lab 06 — CDC Streaming với Debezium + Kafka

## Objective / Mục Tiêu

Stream real-time changes from `shop_db` MySQL to Kafka using Debezium CDC.
_Stream thay đổi real-time từ MySQL `shop_db` sang Kafka sử dụng Debezium CDC._

**Duration / Thời lượng**: ~90 minutes

---

## Stack / Hệ Thống

- MySQL 8.0 (source) / Nguồn
- Kafka + Zookeeper (message broker)
- Kafka Connect + Debezium MySQL Connector
- Kafka UI (for observation / để quan sát)

---

## Setup / Thiết Lập

```bash
docker compose -f labs/lab-06-cdc-streaming/docker-compose.yml up -d

# Wait for all services / Chờ tất cả dịch vụ
docker compose -f labs/lab-06-cdc-streaming/docker-compose.yml ps

# Check Kafka Connect is up / Kiểm tra Kafka Connect đang chạy
curl -s http://localhost:8083/ | jq .version
```

---

## Step 1: Register Debezium Connector / Đăng Ký Connector Debezium

```bash
# Deploy the connector / Triển khai connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @cdc/debezium-connector.json

# Check status / Kiểm tra trạng thái
curl -s http://localhost:8083/connectors/shop-db-connector/status | jq .
# Should show: "state": "RUNNING"
```

---

## Step 2: Trigger CDC Events / Kích Hoạt Sự Kiện CDC

```sql
-- Create changes in shop_db / Tạo thay đổi trong shop_db
USE shop_db;

-- INSERT / Chèn
INSERT INTO customers (uuid, email, full_name)
VALUES (UUID(), 'new.customer@test.com', 'New Customer CDC Test');

-- UPDATE / Cập nhật
UPDATE orders SET status = 'confirmed' WHERE id = 1;

-- Soft DELETE / Xóa mềm
UPDATE customers SET deleted_at = NOW() WHERE email = 'new.customer@test.com';
```

---

## Step 3: Verify Events in Kafka / Xác Minh Sự Kiện Trong Kafka

```bash
# List topics created by Debezium / Liệt kê topic được tạo bởi Debezium
docker exec kafka kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list | grep shopdb

# Consume events from orders topic / Tiêu thụ sự kiện từ topic orders
docker exec kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic shopdb.shop_db.orders \
  --from-beginning \
  --max-messages 5 | jq .

# Expected output / Kết quả mong đợi:
# {
#   "payload": {
#     "op": "u",              <- "u" = update / cập nhật
#     "before": { "status": "pending" },
#     "after": { "status": "confirmed" },
#     "source": { "table": "orders", "gtid": "..." }
#   }
# }
```

---

## Step 4: Write a Consumer / Viết Consumer

```python
# Simple Python consumer / Consumer Python đơn giản
# pip install kafka-python

from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    'shopdb.shop_db.orders',
    bootstrap_servers=['localhost:9092'],
    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
    auto_offset_reset='earliest',
    group_id='lab-06-consumer'
)

print("Listening for order changes... / Lắng nghe thay đổi đơn hàng...")
for msg in consumer:
    payload = msg.value.get('payload', {})
    op = payload.get('op')
    after = payload.get('after', {})
    
    ops = {'c': 'CREATE', 'u': 'UPDATE', 'd': 'DELETE', 'r': 'SNAPSHOT'}
    print(f"[{ops.get(op)}] Order ID={after.get('id')} Status={after.get('status')}")
```

---

## Kafka UI / Giao Diện Kafka

Open Kafka UI at `http://localhost:9000` to visually browse topics and messages.
_Mở Kafka UI tại `http://localhost:9000` để duyệt topic và message trực quan._

---

## Expected Outcomes / Kết Quả Mong Đợi

- ✅ Debezium connector registered and running
- ✅ Initial snapshot of shop_db streamed to Kafka
- ✅ Real-time INSERT/UPDATE/DELETE events visible in topics
- ✅ Python consumer reading and processing events

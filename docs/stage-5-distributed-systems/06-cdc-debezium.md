# CDC with Debezium / CDC với Debezium

## Overview / Tổng Quan

**CDC (Change Data Capture)** captures every INSERT, UPDATE, DELETE from MySQL's binary log and streams them as events to downstream systems.
_**CDC** bắt mọi INSERT, UPDATE, DELETE từ binary log MySQL và truyền phát dưới dạng sự kiện đến các hệ thống downstream._

**Debezium** is the most widely used open-source CDC tool for MySQL.
_**Debezium** là công cụ CDC mã nguồn mở được dùng rộng rãi nhất cho MySQL._

---

## Architecture / Kiến Trúc

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  MySQL Primary                                                       │
│  ┌─────────────┐  binlog  ┌──────────────────┐  events  ┌────────┐  │
│  │  shop_db    │ ────────►│   Debezium       │ ────────►│ Kafka  │  │
│  │  (source)   │          │   MySQL Connector │          │ Topics │  │
│  └─────────────┘          └──────────────────┘          └───┬────┘  │
│                                                             │        │
│                          ┌──────────────────────────────────┤        │
│                          │              │                   │        │
│                ┌─────────▼──────┐ ┌────▼────────┐ ┌───────▼──────┐ │
│                │  analytics_dw  │ │  Elastic-   │ │  KSQL /      │ │
│                │  (warehouse)   │ │  search     │ │  Flink       │ │
│                └────────────────┘ └─────────────┘ └──────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites / Điều Kiện Tiên Quyết

MySQL must have binary logging enabled in ROW format:
_MySQL phải bật binary logging ở định dạng ROW:_

```sql
SHOW VARIABLES LIKE 'log_bin';           -- ON
SHOW VARIABLES LIKE 'binlog_format';     -- ROW
SHOW VARIABLES LIKE 'binlog_row_image';  -- FULL
```

Create a Debezium replication user:
_Tạo user replication cho Debezium:_

```sql
CREATE USER 'debezium'@'%'
    IDENTIFIED WITH mysql_native_password BY 'debezium_secret';

GRANT SELECT, RELOAD, SHOW DATABASES,
      REPLICATION SLAVE, REPLICATION CLIENT
ON *.* TO 'debezium'@'%';

FLUSH PRIVILEGES;
```

---

## Debezium Connector Configuration / Cấu Hình Connector Debezium

```json
{
  "name": "shop-db-connector",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "tasks.max": "1",

    "database.hostname": "mysql-primary",
    "database.port": "3306",
    "database.user": "debezium",
    "database.password": "debezium_secret",
    "database.server.id": "184054",
    "database.server.name": "shopdb",

    "database.include.list": "shop_db",
    "table.include.list": "shop_db.orders,shop_db.payments,shop_db.customers",

    "database.history.kafka.bootstrap.servers": "kafka:9092",
    "database.history.kafka.topic": "shopdb.schema-changes",

    "include.schema.changes": "true",
    "snapshot.mode": "initial",

    "transforms": "route",
    "transforms.route.type": "org.apache.kafka.connect.transforms.ReplaceField$Value",

    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter"
  }
}
```

---

## Kafka Topic Structure / Cấu Trúc Topic Kafka

```
Topic per table / Topic mỗi bảng:
shopdb.shop_db.orders     ← all order changes / mọi thay đổi đơn hàng
shopdb.shop_db.payments   ← all payment changes
shopdb.shop_db.customers  ← all customer changes

Event format / Định dạng sự kiện:
{
  "op": "c",              // c=create, u=update, d=delete, r=read(snapshot)
  "ts_ms": 1702456789000,
  "before": null,         // previous row state / trạng thái hàng trước
  "after": {
    "id": 100,
    "status": "processing",
    "total_amount": 1599000
  },
  "source": {
    "db": "shop_db",
    "table": "orders",
    "gtid": "uuid:1234"
  }
}
```

---

## Consumer Example / Ví Dụ Consumer

```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    'shopdb.shop_db.orders',
    bootstrap_servers=['kafka:9092'],
    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
    group_id='warehouse-loader'
)

for message in consumer:
    event = message.value
    op = event['payload']['op']
    after = event['payload']['after']
    
    if op in ('c', 'u'):  # create or update / tạo hoặc cập nhật
        load_to_warehouse(after)
    elif op == 'd':        # delete / xóa
        mark_deleted_in_warehouse(event['payload']['before']['id'])
```

---

## Lab / Lab Thực Hành

See [Lab 06 — CDC Streaming](../../labs/lab-06-cdc-streaming/README.md) for hands-on practice.
_Xem Lab 06 để thực hành trực tiếp._

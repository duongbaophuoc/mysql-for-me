# ETL / CDC Data Pipeline / Pipeline Dữ Liệu ETL/CDC

## CDC Pipeline with Debezium + Kafka / Pipeline CDC với Debezium + Kafka

```mermaid
graph LR
    subgraph SOURCE["Source / Nguồn"]
        MYSQL[(MySQL<br/>Primary)]
    end

    subgraph CDC["Change Data Capture"]
        DBZ[Debezium<br/>Binlog Consumer]
    end

    subgraph STREAMING["Event Streaming / Truyền Phát Sự Kiện"]
        KAFKA[Apache Kafka<br/>Topics]
    end

    subgraph CONSUMERS["Consumers / Người Tiêu Thụ"]
        ES[Elasticsearch<br/>Search Index]
        CACHE[Redis Cache<br/>Invalidation]
        DW[(Data Warehouse<br/>analytics_dw)]
        NOTIF[Notification<br/>Service]
    end

    MYSQL -->|"Binlog"| DBZ
    DBZ -->|"CDC Events"| KAFKA
    KAFKA -->|"shop.orders"| DW
    KAFKA -->|"shop.products"| ES
    KAFKA -->|"shop.inventory"| CACHE
    KAFKA -->|"shop.payments"| NOTIF
```

---

## Batch ETL Pipeline with Airflow / Pipeline ETL Batch với Airflow

```mermaid
graph TD
    subgraph AIRFLOW["Airflow DAG: mysql_to_warehouse"]
        E[Extract<br/>MySQL → Staging]
        T[Transform<br/>dbt Models]
        L[Load<br/>Star Schema]
        V[Validate<br/>Data Quality]
        E --> T --> L --> V
    end

    subgraph SOURCES["Sources / Nguồn"]
        OLTP[(shop_db<br/>MySQL)]
    end

    subgraph TARGET["Target / Đích"]
        DW[(analytics_dw<br/>Warehouse)]
    end

    OLTP -->|"Incremental Extract"| E
    L --> DW
    V -->|"Alert on failure"| ALERT[PagerDuty / Slack]
```

---

## Outbox Pattern / Mẫu Outbox

```mermaid
sequenceDiagram
    participant SVC as Service
    participant DB as MySQL (shop_db)
    participant POLL as Outbox Poller
    participant KAFKA as Kafka

    SVC->>DB: BEGIN TRANSACTION
    SVC->>DB: INSERT INTO orders (...)
    SVC->>DB: INSERT INTO outbox (event_type, payload)
    SVC->>DB: COMMIT
    POLL->>DB: SELECT * FROM outbox WHERE processed = 0
    POLL->>KAFKA: Publish event
    POLL->>DB: UPDATE outbox SET processed = 1
    Note over SVC,KAFKA: Atomic write + guaranteed delivery
```

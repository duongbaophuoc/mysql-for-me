# MySQL Architecture Overview / Kiến Trúc Tổng Quan MySQL

```mermaid
graph TB
    subgraph CLIENT["Client Layer / Tầng Client"]
        APP[Application Servers]
        BI[BI Tools / Grafana]
    end

    subgraph PROXY["Proxy Layer / Tầng Proxy"]
        PX[ProxySQL / MaxScale]
    end

    subgraph HA["High Availability Cluster / Cluster HA"]
        PRIMARY[(MySQL Primary<br/>Read + Write)]
        R1[(Replica 1<br/>Read Only)]
        R2[(Replica 2<br/>Read Only)]
        PRIMARY -->|GTID Replication| R1
        PRIMARY -->|GTID Replication| R2
    end

    subgraph OBSERVABILITY["Observability / Giám Sát"]
        EXP[mysql_exporter]
        PROM[Prometheus]
        GRAF[Grafana]
        EXP --> PROM --> GRAF
    end

    subgraph PIPELINE["Data Pipeline / Pipeline Dữ Liệu"]
        DBZ[Debezium CDC]
        KAFKA[Kafka]
        DW[(Data Warehouse)]
        DBZ --> KAFKA --> DW
    end

    APP --> PX
    BI --> PX
    PX -->|Writes| PRIMARY
    PX -->|Reads| R1
    PX -->|Reads| R2
    PRIMARY --> EXP
    PRIMARY --> DBZ
```

---

## Component Responsibilities / Trách Nhiệm Từng Component

| Component | Role |
|-----------|------|
| **ProxySQL** | Read/write splitting, connection pooling, failover routing |
| **MySQL Primary** | Handles all writes, GTID-based replication source |
| **Replicas** | Read-only traffic, analytics queries, backup source |
| **Debezium** | Captures binlog changes → streams to Kafka |
| **Prometheus** | Scrapes mysql_exporter metrics every 15s |
| **Grafana** | Visualizes QPS, latency, replication lag, connections |

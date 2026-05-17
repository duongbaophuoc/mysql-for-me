# Monitoring Stack / Stack Giám Sát

## Observability Architecture / Kiến Trúc Quan Sát

```mermaid
graph TD
    subgraph MYSQL["MySQL Cluster"]
        P[(Primary)]
        R1[(Replica 1)]
        R2[(Replica 2)]
    end

    subgraph EXPORTERS["Exporters / Bộ Xuất Số Liệu"]
        EXP1[mysqld_exporter<br/>Primary :9104]
        EXP2[mysqld_exporter<br/>Replica :9105]
    end

    subgraph COLLECTION["Collection / Thu Thập"]
        PROM[Prometheus<br/>:9090<br/>Scrape every 15s]
    end

    subgraph VISUALIZATION["Visualization / Trực Quan Hóa"]
        GRAF[Grafana<br/>:3000<br/>Dashboards]
    end

    subgraph ALERTING["Alerting / Cảnh Báo"]
        AM[Alertmanager<br/>:9093]
        SLACK[Slack]
        PD[PagerDuty]
    end

    P --> EXP1
    R1 --> EXP2
    R2 --> EXP2
    EXP1 --> PROM
    EXP2 --> PROM
    PROM --> GRAF
    PROM -->|"Alert Rules"| AM
    AM --> SLACK
    AM --> PD
```

---

## Key Metrics to Monitor / Số Liệu Quan Trọng Cần Giám Sát

| Metric | Alert Threshold | Meaning |
|--------|:--------------:|---------|
| `mysql_global_status_threads_connected` | > 80% `max_connections` | Connection pressure |
| `mysql_global_status_innodb_row_lock_waits` | Spike > baseline | Lock contention |
| `mysql_slave_status_seconds_behind_master` | > 30s | Replication lag |
| `mysql_global_status_slow_queries` | Rate > 10/min | Query performance |
| `mysql_global_status_innodb_buffer_pool_reads` | High ratio | Cache miss — increase buffer pool |
| `mysql_global_status_aborted_connects` | > 0 | Auth/network issues |
| `node_disk_io_time_seconds_total` | > 80% utilization | Disk I/O bottleneck |

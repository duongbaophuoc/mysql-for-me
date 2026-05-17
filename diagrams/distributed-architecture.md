# Distributed Architecture / Kiến Trúc Phân Tán

## Sharding with Vitess / Phân Mảnh với Vitess

```mermaid
graph TB
    APP[Application]

    subgraph VITESS["Vitess Layer"]
        VTG[VTGate<br/>Query Router]
        VT1[VTTablet<br/>Shard 0: user_id 0–49]
        VT2[VTTablet<br/>Shard 1: user_id 50–99]
        VT3[VTTablet<br/>Shard 2: user_id 100–149]
    end

    subgraph SHARD0["Shard 0"]
        P0[(Primary 0)] --> R0[(Replica 0)]
    end

    subgraph SHARD1["Shard 1"]
        P1[(Primary 1)] --> R1[(Replica 1)]
    end

    subgraph SHARD2["Shard 2"]
        P2[(Primary 2)] --> R2[(Replica 2)]
    end

    APP --> VTG
    VTG -->|"Hash(user_id)"| VT1 --> P0
    VTG -->|"Hash(user_id)"| VT2 --> P1
    VTG -->|"Hash(user_id)"| VT3 --> P2
```

---

## ProxySQL Read/Write Splitting / Phân Tách Đọc/Ghi

```mermaid
graph LR
    APP[Application<br/>Port 6033]

    subgraph PROXYSQL["ProxySQL"]
        RG1["Hostgroup 10<br/>Write Group"]
        RG2["Hostgroup 20<br/>Read Group"]
    end

    subgraph MYSQL["MySQL Cluster"]
        P[(Primary<br/>:3306)]
        R1[(Replica 1<br/>:3307)]
        R2[(Replica 2<br/>:3308)]
    end

    APP -->|"DML / DDL"| RG1 --> P
    APP -->|"SELECT"| RG2
    RG2 -->|"Round Robin"| R1
    RG2 -->|"Round Robin"| R2
```

---

## CAP Theorem Trade-offs / Đánh Đổi CAP

| Configuration | Consistency | Availability | Partition Tolerance |
|---------------|:-----------:|:------------:|:-------------------:|
| Single Primary (Async) | ✅ | ✅ | ⚠️ |
| Semi-sync Replication | ✅✅ | ⚠️ | ⚠️ |
| Group Replication (Paxos) | ✅✅ | ✅ | ✅ |
| Vitess Sharding | ⚠️ | ✅✅ | ✅✅ |

# Replication Topology / Cấu Trúc Replication

## Standard GTID Replication / Replication GTID Tiêu Chuẩn

```mermaid
graph TD
    PRIMARY[(Primary<br/>Read + Write<br/>:3306)]

    subgraph REPLICAS["Read Replicas / Replica Đọc"]
        R1[(Replica 1<br/>Read Only<br/>:3307)]
        R2[(Replica 2<br/>Read Only<br/>:3308)]
    end

    subgraph BACKUP["Backup Replica / Replica Backup"]
        R3[(Replica 3<br/>Backup Source<br/>:3309)]
    end

    PRIMARY -->|"Binlog Stream<br/>GTID-based"| R1
    PRIMARY -->|"Binlog Stream<br/>GTID-based"| R2
    PRIMARY -->|"Binlog Stream<br/>GTID-based"| R3

    R3 -->|XtraBackup| BKUP[(Backup Storage)]
```

---

## InnoDB Cluster Topology / Cấu Trúc InnoDB Cluster

```mermaid
graph LR
    subgraph CLUSTER["InnoDB Cluster (Group Replication)"]
        P[(Primary<br/>R+W)]
        S1[(Secondary 1<br/>R only)]
        S2[(Secondary 2<br/>R only)]
        P <-->|"Paxos<br/>Consensus"| S1
        P <-->|"Paxos<br/>Consensus"| S2
        S1 <-->|"Paxos<br/>Consensus"| S2
    end

    ROUTER[MySQL Router<br/>Automatic Failover]
    APP[Application]

    APP --> ROUTER
    ROUTER -->|"Write"| P
    ROUTER -->|"Read"| S1
    ROUTER -->|"Read"| S2
```

---

## Failover Flow / Luồng Failover

```mermaid
sequenceDiagram
    participant APP as Application
    participant PX as ProxySQL
    participant P as Primary
    participant R1 as Replica 1
    participant ORC as Orchestrator

    P->>ORC: ❌ Primary down
    ORC->>R1: Promote to Primary
    ORC->>PX: Update routing rules
    PX->>APP: Route writes to new Primary
    APP->>R1: Writes resume (new Primary)
    Note over APP,R1: RTO < 30 seconds
```

---

## Replication Monitoring / Giám Sát Replication

```sql
-- Check replication lag / Kiểm tra độ trễ replication
SHOW REPLICA STATUS\G
-- Key metric: Seconds_Behind_Source

-- Check GTID status / Kiểm tra trạng thái GTID
SELECT @@global.gtid_executed;
SELECT @@global.gtid_purged;
```

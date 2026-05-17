# InnoDB Internals Diagram / Sơ Đồ Nội Tại InnoDB

```mermaid
graph TD
    subgraph MEMORY["InnoDB Buffer Pool (Memory)"]
        BP[Buffer Pool Pages]
        AHI[Adaptive Hash Index]
        CP[Change Buffer]
        FL[Flush List - Dirty Pages]
    end

    subgraph LOG["Log System / Hệ Thống Log"]
        REDO[Redo Log<br/>ib_logfile0/1]
        UNDO[Undo Log<br/>Rollback Segments]
        DWB[Doublewrite Buffer]
    end

    subgraph DISK["InnoDB Tablespace (Disk)"]
        IBD[.ibd Files<br/>B+ Tree Pages]
        SYS[ibdata1<br/>System Tablespace]
    end

    subgraph TRX["Transaction Engine / Giao Dịch"]
        MVCC[MVCC<br/>Read Views]
        LOCK[Lock Manager<br/>Row & Gap Locks]
        PURGE[Purge Thread<br/>Undo Cleanup]
    end

    BP <-->|Page Read/Write| IBD
    FL -->|Checkpoint Flush| DWB --> IBD
    REDO --> SYS
    UNDO --> MVCC
    LOCK --> BP
    PURGE --> UNDO
    AHI --> BP
    CP --> BP
```

---

## Key Concepts / Khái Niệm Quan Trọng

| Component | Purpose | Tuning Parameter |
|-----------|---------|-----------------|
| **Buffer Pool** | Cache pages in memory | `innodb_buffer_pool_size` (70–80% RAM) |
| **Redo Log** | WAL for crash recovery | `innodb_log_file_size` |
| **Undo Log** | MVCC historical versions | `innodb_undo_tablespaces` |
| **Doublewrite Buffer** | Prevents torn page writes | `innodb_doublewrite` |
| **Adaptive Hash Index** | Auto-index hot data | `innodb_adaptive_hash_index` |
| **Change Buffer** | Defer secondary index writes | `innodb_change_buffer_max_size` |
| **Purge Thread** | Clean up old undo versions | `innodb_purge_threads` |

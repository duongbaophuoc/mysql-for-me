# 🔴 Stage 3 — InnoDB Internals & Performance Engineering
# 🔴 Giai Đoạn 3 — Nội Tại InnoDB & Kỹ Thuật Hiệu Năng

> **"To optimize MySQL, you must understand how InnoDB thinks."**
> _"Để tối ưu MySQL, bạn phải hiểu InnoDB nghĩ như thế nào."_

## Overview / Tổng Quan

This is the most critical stage for database engineers. Understanding InnoDB storage internals is the difference between a developer who writes SQL and a database engineer who diagnoses production incidents.
_Đây là giai đoạn quan trọng nhất cho database engineer. Hiểu nội tại lưu trữ InnoDB là sự khác biệt giữa developer viết SQL và database engineer chẩn đoán sự cố production._

## Topics / Chủ Đề

| File | Topic | Level |
|------|-------|-------|
| [01-clustered-vs-secondary-indexes.md](01-clustered-vs-secondary-indexes.md) | How InnoDB stores rows | Advanced |
| [02-bplus-tree-internals.md](02-bplus-tree-internals.md) | B+ Tree pages and traversal | Advanced |
| [03-buffer-pool.md](03-buffer-pool.md) | LRU, dirty pages, flush | Advanced |
| [04-mvcc-and-undo-log.md](04-mvcc-and-undo-log.md) | Snapshot isolation mechanics | Advanced |
| [05-redo-log-wal.md](05-redo-log-wal.md) | WAL, checkpoint, crash recovery | Advanced |
| [06-isolation-levels.md](06-isolation-levels.md) | RC, RR, Serializable comparison | Advanced |
| [07-locking-gap-locks-next-key.md](07-locking-gap-locks-next-key.md) | Row locks, gap locks, next-key | Advanced |
| [08-deadlocks.md](08-deadlocks.md) | Detection, resolution, prevention | Advanced |
| [09-explain-analyze.md](09-explain-analyze.md) | Reading query execution plans | Advanced |
| [10-covering-composite-indexes.md](10-covering-composite-indexes.md) | Index design patterns | Advanced |
| [11-slow-query-log.md](11-slow-query-log.md) | Capturing & analyzing slow queries | Advanced |
| [12-online-schema-changes.md](12-online-schema-changes.md) | gh-ost, pt-osc, Online DDL | Expert |

## Learning Outcomes / Kết Quả Học Tập

- ✅ Explain how InnoDB stores rows using clustered indexes
- ✅ Understand B+ tree page splits and their performance impact
- ✅ Diagnose buffer pool pressure from metrics
- ✅ Understand MVCC — how multiple transactions see different data simultaneously
- ✅ Read and interpret EXPLAIN ANALYZE output
- ✅ Design optimal composite and covering indexes
- ✅ Diagnose and resolve deadlocks from `SHOW ENGINE INNODB STATUS`
- ✅ Run zero-downtime schema migrations with gh-ost

## InnoDB Architecture Diagram / Sơ Đồ Kiến Trúc InnoDB

```
┌─────────────────────────────────────────────────────────────┐
│                     InnoDB Storage Engine                    │
│                                                             │
│  ┌──────────────────────────────────┐  ┌─────────────────┐ │
│  │         Buffer Pool              │  │  Redo Log       │ │
│  │  ┌──────────┐  ┌──────────────┐  │  │  (WAL)          │ │
│  │  │ LRU List │  │  Flush List  │  │  │  ib_logfile0    │ │
│  │  │ (clean)  │  │  (dirty pgs) │  │  │  ib_logfile1    │ │
│  │  └──────────┘  └──────────────┘  │  └─────────────────┘ │
│  │  ┌──────────────────────────────┐ │                      │
│  │  │  Adaptive Hash Index (AHI)   │ │  ┌─────────────────┐ │
│  │  └──────────────────────────────┘ │  │  Undo Logs      │ │
│  └──────────────────────────────────┘  │  (MVCC history)  │ │
│                                        └─────────────────┘ │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Tablespace (ibdata / .ibd files)        │   │
│  │   B+ Tree pages (16KB each) — Clustered by PK       │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Key Diagnostic Commands / Lệnh Chẩn Đoán Quan Trọng

```sql
-- InnoDB engine status / Trạng thái InnoDB
SHOW ENGINE INNODB STATUS\G

-- Buffer pool utilization / Mức sử dụng buffer pool
SELECT * FROM information_schema.INNODB_BUFFER_POOL_STATS\G

-- Active transactions / Giao dịch đang hoạt động
SELECT * FROM information_schema.INNODB_TRX\G

-- Lock waits / Chờ lock
SELECT * FROM performance_schema.data_lock_waits\G

-- History List Length (MVCC pressure) / Áp lực MVCC
SELECT NAME, COUNT FROM information_schema.INNODB_METRICS
WHERE NAME = 'trx_rseg_history_len';
```

## Next Stage / Giai Đoạn Tiếp Theo

→ [Stage 4 — Production Operations](../stage-4-production-operations/README.md)

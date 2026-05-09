# Vitess — MySQL Sharding at Scale / Vitess — Phân Mảnh MySQL Ở Quy Mô Lớn

## Overview / Tổng Quan

**Vitess** is a database clustering system for MySQL developed at YouTube. It adds a sharding layer transparently, so applications see a single MySQL connection.
_**Vitess** là hệ thống phân cụm CSDL MySQL phát triển tại YouTube. Nó thêm tầng sharding trong suốt, ứng dụng thấy một kết nối MySQL đơn._

---

## Architecture / Kiến Trúc

```
App ──────────────────────────────► VTGate (proxy layer)
                                         │
                            ┌────────────┼────────────┐
                            │            │            │
                       VTTablet-1   VTTablet-2   VTTablet-3
                       (Shard -80)  (Shard 80-)  (Lookup)
                            │            │
                         MySQL A      MySQL B
                      (id 1-50%)   (id 50-100%)
```

---

## Key Components / Thành Phần Chính

| Component | Role |
|-----------|------|
| **VTGate** | Query router — apps connect here (MySQL protocol) |
| **VTTablet** | Manages one MySQL shard |
| **etcd/Topology** | Stores shard routing metadata |
| **vtctld** | Admin interface for cluster management |
| **vttablet** | Runs as sidecar to each MySQL instance |

---

## How Vitess Routes Queries / Cách Vitess Định Tuyến Truy Vấn

```sql
-- App sends this to VTGate (standard MySQL connection)
-- Ứng dụng gửi đến VTGate (kết nối MySQL chuẩn)
SELECT * FROM orders WHERE customer_id = 12345;

-- VTGate:
-- 1. Looks up routing table: customer_id 12345 → Shard-1 (hash range 0-50%)
-- 2. Rewrites query with shard key hint
-- 3. Sends to VTTablet-1 → MySQL Shard-1
-- 4. Returns result to app

-- App sees: exactly what it would see from a single MySQL!
-- Ứng dụng thấy: đúng như một MySQL đơn!
```

---

## VSchema — Vitess Schema / Schema Vitess

```json
{
  "sharded": true,
  "vindexes": {
    "hash_customer_id": {
      "type": "hash"
    }
  },
  "tables": {
    "orders": {
      "columnVindexes": [
        {
          "column": "customer_id",
          "name": "hash_customer_id"
        }
      ]
    },
    "customers": {
      "columnVindexes": [
        {
          "column": "id",
          "name": "hash_customer_id"
        }
      ]
    }
  }
}
```

---

## When to Use Vitess / Khi Nào Dùng Vitess

```
Use Vitess when:
  → Single MySQL can't handle write throughput (> 50K TPS)
  → Dataset > 5TB that can't fit on one server
  → Need live resharding without downtime
  → Facebook/YouTube scale requirements

Don't use for:
  → Small to medium applications (< 10K TPS)
  → Teams without dedicated DBA resources
  → Applications with heavy cross-shard transactions

Alternative: PlanetScale (managed Vitess-based MySQL)
```

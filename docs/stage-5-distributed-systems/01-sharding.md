# Sharding / Phân Mảnh

## Overview / Tổng Quan

**Horizontal sharding** splits data across multiple independent MySQL servers (shards) based on a **shard key**.
_**Sharding ngang** phân chia dữ liệu qua nhiều MySQL server độc lập (shard) dựa trên **shard key**._

The problem sharding solves: a single MySQL master can handle ~10K-50K TPS. Beyond that, you need to scale horizontally.
_Vấn đề sharding giải quyết: Một MySQL master có thể xử lý ~10K-50K TPS. Vượt quá đó, cần scale ngang._

---

## Sharding Key Selection / Chọn Shard Key

The shard key determines which shard stores a row. Choose it carefully:
_Shard key xác định shard nào lưu một hàng. Chọn cẩn thận:_

| Criteria | Requirement |
|----------|-------------|
| High cardinality | Many distinct values to spread data evenly |
| Present in all queries | Avoid cross-shard queries |
| Immutable | Never changes (can't re-shard a row) |
| Used in hottest joins | Co-locate related data |

---

## Sharding Strategies / Chiến Lược Phân Mảnh

### Range Sharding / Phân Mảnh Phạm Vi

```
Shard 0: customer_id 0–999,999
Shard 1: customer_id 1,000,000–1,999,999
Shard 2: customer_id 2,000,000+
```

```python
def get_shard(customer_id: int) -> str:
    if customer_id < 1_000_000: return 'shard_0'
    if customer_id < 2_000_000: return 'shard_1'
    return 'shard_2'
```

✅ Easy range queries, simple rebalancing  
❌ Hotspots if new customers cluster on one shard

### Hash Sharding / Phân Mảnh Hash

```python
def get_shard(customer_id: int, num_shards=4) -> int:
    return customer_id % num_shards   # 0, 1, 2, or 3

# Problem: resharding requires moving 75% of data when adding a shard
# Vấn đề: resharding đòi di chuyển 75% dữ liệu khi thêm shard
```

### Consistent Hashing / Hash Nhất Quán

```
Virtual hash ring: 0 ─── 1000000
Shard A: handles hash range 0–250000
Shard B: handles hash range 250001–500000
Shard C: handles hash range 500001–750000
Shard D: handles hash range 750001–1000000

Add a new shard: only ~25% of data moves!
Thêm shard mới: chỉ ~25% dữ liệu cần di chuyển!
```

---

## Cross-Shard Problems / Vấn Đề Liên Shard

```sql
-- NO cross-shard JOINs possible! / Không thể JOIN liên shard!
-- This query requires querying ALL shards:
-- Truy vấn này phải chạy trên TẤT CẢ shard:
SELECT * FROM orders WHERE created_at > '2024-01-01';  -- no shard key!

-- Solution / Giải pháp:
-- 1. Always include shard key in every query / Luôn có shard key trong mọi truy vấn
-- 2. Maintain a global lookup table (directory shard) / Duy trì bảng tra cứu toàn cục
-- 3. Use Vitess to abstract sharding / Dùng Vitess để trừu tượng hóa

-- Cross-shard aggregation must happen in application
-- Tổng hợp liên shard phải thực hiện ở tầng ứng dụng:
total = sum([
    shard.query("SELECT SUM(total) FROM orders WHERE created_at > '2024-01-01'")
    for shard in all_shards
])
```

---

## When to Shard / Khi Nào Phân Mảnh

```
Before sharding, exhaust these options / Trước sharding, thử các lựa chọn này:
  ✅ Vertical scaling (bigger machine)
  ✅ Read replicas (offload reads)
  ✅ Caching (Redis, Memcached)
  ✅ ProxySQL connection multiplexing
  ✅ Query optimization

Shard when / Phân mảnh khi:
  → Single primary > 10-20K TPS sustained writes
  → Dataset > 10TB (single table > 100M rows)
  → Need geographical distribution
```

---

## See Also / Xem Thêm

- [Vitess](03-vitess.md) — MySQL sharding abstraction layer
- [Lab 07](../../labs/lab-07-sharding-simulation/README.md) — Hands-on sharding

# Consistent Hashing / Hash Nhất Quán

## Overview / Tổng Quan

Consistent hashing minimizes the amount of data that must be moved when adding or removing nodes from a distributed system.
_Hash nhất quán giảm thiểu lượng dữ liệu phải di chuyển khi thêm hoặc xóa node khỏi hệ thống phân tán._

---

## The Problem with Simple Hash / Vấn Đề Của Hash Đơn Giản

```python
# Simple hash: shard_id = customer_id % num_shards
# When you add a 5th shard: 80% of data moves!
# Khi thêm shard thứ 5: 80% dữ liệu phải di chuyển!

# 4 shards → 5 shards: most keys change shard
num_shards = 4
customer_id = 1000
shard = customer_id % num_shards  # = 0

num_shards = 5
shard = customer_id % num_shards  # = 0 (same, lucky!)
# But 1001 % 4 = 1, 1001 % 5 = 1 (same)
# And 1002 % 4 = 2, 1002 % 5 = 2 (same)
# But 1003 % 4 = 3, 1003 % 5 = 3 (same)
# And 1004 % 4 = 0, 1004 % 5 = 4 (MOVED! Di chuyển!)
```

---

## Consistent Hashing Ring / Vòng Hash Nhất Quán

```
Imagine a hash ring from 0 to 2^32 / Tưởng tượng vòng hash từ 0 đến 2^32:

           0
    ┌──────┴──────┐
    │   Hash Ring │
  A │  (0-90°)   │ B (90-180°)
    │             │
    └──────┬──────┘
           │  C,D  (180-360°)

Data is placed on the ring by hash(key).
Assigned to the first node clockwise.
Dữ liệu đặt trên vòng theo hash(key), gán cho node đầu tiên theo chiều kim đồng hồ.
```

```python
import hashlib
import bisect

class ConsistentHashRing:
    def __init__(self, replicas=100):
        self.replicas = replicas    # virtual nodes / node ảo
        self.ring = {}
        self.sorted_keys = []

    def add_node(self, node: str):
        for i in range(self.replicas):
            key = self._hash(f"{node}:{i}")
            self.ring[key] = node
            bisect.insort(self.sorted_keys, key)

    def remove_node(self, node: str):
        for i in range(self.replicas):
            key = self._hash(f"{node}:{i}")
            del self.ring[key]
            self.sorted_keys.remove(key)

    def get_node(self, data_key: str) -> str:
        if not self.ring:
            raise Exception("No nodes in ring!")
        hash_val = self._hash(data_key)
        idx = bisect.bisect(self.sorted_keys, hash_val) % len(self.sorted_keys)
        return self.ring[self.sorted_keys[idx]]

    def _hash(self, key: str) -> int:
        return int(hashlib.md5(key.encode()).hexdigest(), 16)

# Usage / Sử dụng:
ring = ConsistentHashRing(replicas=150)
ring.add_node("shard-0")
ring.add_node("shard-1")
ring.add_node("shard-2")

print(ring.get_node("customer:12345"))  # → shard-1
print(ring.get_node("customer:99999"))  # → shard-0

# Add new shard: only ~25% of data moves! / Thêm shard mới: chỉ ~25% dữ liệu di chuyển!
ring.add_node("shard-3")
```

---

## Virtual Nodes / Node Ảo

```
Without virtual nodes / Không có node ảo:
  Uneven distribution if only 3 nodes on the ring
  Phân phối không đều nếu chỉ có 3 node

With virtual nodes (replicas=150) / Với node ảo:
  Each physical node has 150 "virtual" positions on the ring
  → More even distribution even with few physical nodes
  → Mỗi node vật lý có 150 vị trí "ảo" → phân phối đều hơn
```

---

## Consistent Hashing in MySQL Context

```sql
-- Application determines shard, then queries the right MySQL instance
-- Ứng dụng xác định shard, sau đó truy vấn MySQL instance đúng

-- Example: customer 12345 hashes to shard-1
-- Ví dụ: customer 12345 hash đến shard-1
MYSQL_CONNECTIONS = {
    "shard-0": "mysql://shard-0-host:3306/shop_db",
    "shard-1": "mysql://shard-1-host:3306/shop_db",
    "shard-2": "mysql://shard-2-host:3306/shop_db",
}

def get_orders(customer_id):
    shard = ring.get_node(f"customer:{customer_id}")
    db = get_connection(MYSQL_CONNECTIONS[shard])
    return db.query("SELECT * FROM orders WHERE customer_id = ?", customer_id)
```

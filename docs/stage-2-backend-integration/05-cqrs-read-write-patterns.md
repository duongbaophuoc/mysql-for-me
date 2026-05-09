# CQRS & Read/Write Patterns / CQRS & Mẫu Đọc/Ghi

## Overview / Tổng Quan

**CQRS (Command Query Responsibility Segregation)** separates the data model used for **writes (Commands)** from the model used for **reads (Queries)**.
_**CQRS** tách biệt mô hình dữ liệu dùng cho **ghi (Lệnh)** khỏi mô hình dùng cho **đọc (Truy Vấn)**._

---

## Why CQRS with MySQL / Tại Sao CQRS Với MySQL

```
Problem / Vấn đề:
  Write model (OLTP): normalized, 3NF, optimized for transactions
  Read model: needs denormalized, pre-joined data for fast API responses

Solution / Giải pháp:
  Primary → handles all writes (Commands)
  Replica → handles all reads (Queries)
  Or: Primary → CDC → Read-optimized store (Redis, Elasticsearch, read DB)
```

---

## Simple CQRS: Primary Read from Replica / Primary Đọc Từ Replica

```python
from sqlalchemy import create_engine

# Write engine (primary) / Engine ghi (primary)
write_engine = create_engine(
    "mysql://user:pass@mysql-primary:3306/shop_db",
    pool_size=5
)

# Read engine (replica) / Engine đọc (replica)
read_engine = create_engine(
    "mysql://user:pass@mysql-replica:3306/shop_db",
    pool_size=20   # More connections for read traffic / Nhiều kết nối hơn
)

def create_order(data):
    """Write operation — goes to primary"""
    with write_engine.begin() as conn:
        return conn.execute("INSERT INTO orders ...", data)

def get_customer_orders(customer_id):
    """Read operation — goes to replica (can tolerate slight lag)"""
    with read_engine.connect() as conn:
        return conn.execute(
            "SELECT ... FROM orders WHERE customer_id = ?", customer_id
        ).fetchall()
```

---

## Advanced CQRS: Separate Read Models / Mô Hình Đọc Riêng Biệt

```
Command Side / Phía Lệnh:          Query Side / Phía Truy Vấn:
  shop_db (MySQL primary)             Redis (cache hot data)
    orders                              order_list:{customer_id}
    order_items                       Elasticsearch
    products                            product search index
                     ──CDC──►        MySQL Replica
                                       denormalized views
```

```python
# Command: create order / Tạo đơn hàng
async def create_order(command: CreateOrderCommand):
    async with db.begin():
        order_id = await orders_repo.insert(command)
        await inventory_repo.reserve(command.items)
        
    # Publish event for read model updates / Phát sự kiện cập nhật mô hình đọc
    await event_bus.publish(OrderCreatedEvent(order_id=order_id))

# Query: get order list (from read model) / Lấy danh sách đơn hàng (từ mô hình đọc)
async def get_orders(customer_id: int, cursor: str = None):
    # Try Redis cache first / Thử Redis cache trước
    cached = await redis.get(f"orders:{customer_id}:{cursor}")
    if cached:
        return cached
    # Fall back to replica / Dự phòng vào replica
    return await read_db.query(
        "SELECT ... FROM v_order_summary WHERE customer_id = ?",
        customer_id
    )
```

---

## Read Model: Materialized Views in MySQL
## Mô Hình Đọc: View Vật Thể Hóa Trong MySQL

```sql
-- Create a pre-joined "read model" table / Tạo bảng "mô hình đọc" đã join trước
CREATE TABLE rm_customer_order_summary (
    customer_id   BIGINT UNSIGNED NOT NULL,
    customer_name VARCHAR(200),
    total_orders  INT UNSIGNED DEFAULT 0,
    total_spent   DECIMAL(16,2) DEFAULT 0,
    last_order_at DATETIME(3),
    PRIMARY KEY (customer_id)
);

-- Refresh via scheduled job every 5 minutes / Làm mới qua job định kỳ mỗi 5 phút
INSERT INTO rm_customer_order_summary
SELECT
    c.id,
    c.full_name,
    COUNT(o.id),
    COALESCE(SUM(o.total_amount), 0),
    MAX(o.created_at)
FROM customers c LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id
ON DUPLICATE KEY UPDATE
    total_orders  = VALUES(total_orders),
    total_spent   = VALUES(total_spent),
    last_order_at = VALUES(last_order_at);
```

---

## When to Apply CQRS / Khi Nào Áp Dụng CQRS

```
Start simple (no CQRS) → add when you have:
Bắt đầu đơn giản → thêm khi bạn có:

✅ Read : Write ratio > 10:1
✅ Read queries need different data shape than write model
✅ Need to scale reads independently of writes
✅ Complex reporting that hurts transactional performance
❌ Small application with simple queries — over-engineering
```

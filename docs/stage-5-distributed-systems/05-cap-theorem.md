# CAP Theorem & MySQL / Định Lý CAP & MySQL

## Overview / Tổng Quan

The **CAP theorem** states that a distributed data store can guarantee at most **2 of 3** properties simultaneously:
_**Định lý CAP** phát biểu rằng kho dữ liệu phân tán chỉ có thể đảm bảo tối đa **2 trong 3** thuộc tính đồng thời:_

- **C**onsistency: Every read receives the most recent write or an error
- **A**vailability: Every request receives a non-error response
- **P**artition tolerance: The system continues despite network partitions

_**C**onsistency: Mọi đọc nhận được dữ liệu ghi mới nhất hoặc lỗi_
_**A**vailability: Mọi request nhận được phản hồi không lỗi_
_**P**artition tolerance: Hệ thống tiếp tục dù mạng bị phân vùng_

---

## MySQL's CAP Classification / Phân Loại CAP Của MySQL

```
Standard MySQL replication = CP (Consistency + Partition Tolerance)
─────────────────────────────────────────────────────────────────────
During network partition / Khi mạng bị phân vùng:
  Replica loses connection to primary
  → If we promote replica: might miss some committed transactions
  → MySQL semi-sync replication: primary WAITS for at least 1 replica
    → Sacrifices A (availability) for C (consistency)
```

---

## Consistency Modes in MySQL / Chế Độ Nhất Quán Trong MySQL

### Strong Consistency / Nhất Quán Mạnh

```sql
-- All reads go to primary / Tất cả đọc đến primary
-- No stale reads / Không đọc cũ
-- Lower availability if primary fails / Khả dụng thấp hơn nếu primary lỗi

app_config = {
    "read_from": "primary_only"
}
```

### Eventual Consistency / Nhất Quán Cuối Cùng

```sql
-- Reads can go to replicas / Đọc có thể đến replica
-- Might read stale data (replication lag) / Có thể đọc dữ liệu cũ
-- Higher availability / Khả dụng cao hơn

-- Application must handle stale reads: / Ứng dụng phải xử lý đọc cũ:
-- "Your order is being processed" (instead of showing stale 'pending')
-- "Đơn hàng của bạn đang được xử lý"
```

### Read-After-Write Consistency / Nhất Quán Đọc-Sau-Ghi

```python
# After a write, read from primary for that session
# Sau khi ghi, đọc từ primary cho phiên đó
def create_order(data):
    order_id = write_db.insert("INSERT INTO orders ...", data)
    # Force read from primary for this operation
    # Buộc đọc từ primary cho thao tác này
    order = write_db.query("SELECT * FROM orders WHERE id = ?", order_id)
    return order   # guaranteed to see the write! / đảm bảo thấy lần ghi!
```

---

## PACELC Extension / Mở Rộng PACELC

PACELC extends CAP: even when no partition, there's a latency/consistency trade-off.
_PACELC mở rộng CAP: ngay cả khi không có phân vùng, vẫn có đánh đổi giữa độ trễ và tính nhất quán._

```
MySQL semi-sync replication:
  P → C (consistency over availability on partition)
  E → L (some latency to ensure at least 1 replica acknowledged)

MySQL async replication:
  P → A (availability, accept possibly stale replicas)
  E → L (fast writes, low latency)
```

---

## Practical Implications / Tác Động Thực Tế

| Scenario | MySQL Setting | Trade-off |
|----------|--------------|-----------|
| Payment processing | Read from primary only | Low availability |
| Product catalog | Read from replica | Possible stale data |
| Shopping cart | Read from primary or session-pinned | Balance |
| Analytics reports | Read from replica | Fine with minutes of lag |

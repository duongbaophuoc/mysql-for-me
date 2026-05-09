# The N+1 Problem / Vấn Đề N+1

## Overview / Tổng Quan

The N+1 problem is one of the most common performance killers in ORM-based applications.
_Vấn đề N+1 là một trong những thủ phủ hiệu năng phổ biến nhất trong ứng dụng dùng ORM._

For N rows fetched, the app executes N additional queries — totaling N+1 instead of 1 JOIN.
_Với N hàng được lấy, ứng dụng thực thi thêm N truy vấn — tổng N+1 thay vì 1 JOIN._

---

## The Problem / Vấn Đề

```python
# SQLAlchemy — BAD / Tệ
orders = session.query(Order).all()   # 1 query → 100 rows

for order in orders:
    print(order.customer.email)       # N queries — one per order!
# Total: 101 queries for 100 orders!
```

```sql
-- What MySQL actually receives / MySQL thực tế nhận được:
SELECT * FROM orders;                         -- 1 query
SELECT * FROM customers WHERE id = 1;         -- query 2
SELECT * FROM customers WHERE id = 5;         -- query 3
SELECT * FROM customers WHERE id = 5;         -- query 4 (SAME customer!)
-- ... 100 more / ... 100 lần nữa
```

---

## Detection / Phát Hiện

```sql
-- Find repeated query patterns / Tìm mẫu truy vấn lặp lại
SELECT
    DIGEST_TEXT,
    COUNT_STAR   AS executions,
    ROUND(AVG_TIMER_WAIT / 1e9, 3) AS avg_ms
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT LIKE '%customers%'
ORDER BY COUNT_STAR DESC
LIMIT 10;
```

---

## Solution 1: Eager Loading / Tải Trước

```python
# SQLAlchemy — GOOD / Tốt
from sqlalchemy.orm import joinedload

orders = session.query(Order).options(
    joinedload(Order.customer),
    joinedload(Order.order_items)
).all()
# Generated: 1 query with LEFT JOIN / Sinh ra: 1 truy vấn với LEFT JOIN
```

```javascript
// Sequelize — GOOD / Tốt
const orders = await Order.findAll({
    include: [
        { model: Customer, attributes: ['id', 'email', 'full_name'] },
        { model: OrderItem }
    ]
});
```

---

## Solution 2: Raw JOIN / JOIN Thủ Công

```sql
-- One query replaces N+1 / Một truy vấn thay thế N+1
SELECT
    o.id, o.total_amount, o.status,
    c.email       AS customer_email,
    c.full_name   AS customer_name
FROM orders o
INNER JOIN customers c ON c.id = o.customer_id
WHERE o.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
ORDER BY o.created_at DESC
LIMIT 100;
```

---

## Performance Impact / Tác Động Hiệu Năng

| Scenario | Queries | Latency |
|----------|---------|---------|
| N+1 with 100 orders | 101 | ~500ms |
| JOIN query | 1 | ~5ms |
| N+1 with 10,000 orders | 10,001 | timeout! |
| JOIN query | 1 | ~50ms |

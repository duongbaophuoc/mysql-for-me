# 🟡 Stage 2 — Backend Integration & Application Data Layer
# 🟡 Giai Đoạn 2 — Tích Hợp Backend & Tầng Dữ Liệu Ứng Dụng

> **"ORMs don't write good SQL. Engineers do."**
> _"ORM không viết SQL tốt. Kỹ sư mới làm được điều đó."_

## Overview / Tổng Quan

Most backend engineers interact with MySQL through an ORM. This stage teaches how ORMs generate SQL, where they fail, and how to build robust, scalable data-access layers.
_Hầu hết backend engineer tương tác với MySQL qua ORM. Giai đoạn này dạy cách ORM sinh SQL, chỗ chúng thất bại, và cách xây dựng tầng truy cập dữ liệu mạnh mẽ._

## Topics / Chủ Đề

| File | Topic | Level |
|------|-------|-------|
| [01-orm-overview.md](01-orm-overview.md) | Hibernate, Prisma, Sequelize, SQLAlchemy | Intermediate |
| [02-n-plus-1-problem.md](02-n-plus-1-problem.md) | Query explosion detection & fix | Intermediate |
| [03-connection-pooling.md](03-connection-pooling.md) | HikariCP, DBCP2, pgBouncer patterns | Intermediate |
| [04-pagination-strategies.md](04-pagination-strategies.md) | Offset vs Keyset cursor pagination | Intermediate |
| [05-cqrs-patterns.md](05-cqrs-patterns.md) | Command-Query Responsibility Segregation | Advanced |
| [06-idempotency.md](06-idempotency.md) | Idempotency keys for distributed systems | Advanced |
| [07-distributed-transactions-saga.md](07-distributed-transactions-saga.md) | Saga pattern, 2PC, compensation | Advanced |

## Learning Outcomes / Kết Quả Học Tập

- ✅ Identify and fix N+1 query problems in ORM code
- ✅ Configure connection pools for production traffic
- ✅ Implement efficient pagination for large datasets
- ✅ Design CQRS-based read/write separated architectures
- ✅ Implement idempotent payment and order processing
- ✅ Understand distributed transaction trade-offs (Saga vs 2PC)

## The N+1 Problem — Quick Demo / Vấn Đề N+1 — Demo Nhanh

```python
# BAD: N+1 queries / Tệ: N+1 truy vấn
orders = Order.query.all()          # 1 query
for order in orders:
    print(order.customer.email)     # N queries — one per order!

# GOOD: Eager load / Tốt: Tải trước
orders = Order.query.options(
    joinedload(Order.customer)
).all()                             # 1 query with JOIN
```

## Pagination — Offset vs Cursor / Phân Trang — Offset vs Con Trỏ

```sql
-- OFFSET — simple but slow on large tables / Đơn giản nhưng chậm trên bảng lớn
SELECT * FROM orders ORDER BY id LIMIT 20 OFFSET 10000;
-- MySQL must scan 10020 rows / MySQL phải quét 10020 hàng

-- KEYSET CURSOR — fast at any depth / Nhanh ở mọi độ sâu
SELECT * FROM orders
WHERE id > :last_seen_id
ORDER BY id
LIMIT 20;
-- MySQL uses index scan directly / MySQL dùng quét chỉ mục trực tiếp
```

## Next Stage / Giai Đoạn Tiếp Theo

→ [Stage 3 — InnoDB Internals](../stage-3-innodb-internals/README.md)

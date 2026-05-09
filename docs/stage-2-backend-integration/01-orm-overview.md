# ORM Overview / Tổng Quan ORM

## What is an ORM? / ORM Là Gì?

**ORM (Object-Relational Mapper)** bridges the gap between object-oriented application code and relational databases by mapping classes to tables and objects to rows.
_**ORM** thu hẹp khoảng cách giữa code ứng dụng hướng đối tượng và CSDL quan hệ bằng cách ánh xạ lớp thành bảng và đối tượng thành hàng._

---

## Popular ORMs by Language / ORM Phổ Biến Theo Ngôn Ngữ

| Language | ORM | Notes |
|----------|-----|-------|
| Python | SQLAlchemy | Most powerful, raw SQL support |
| Python | Django ORM | Tightly coupled to Django |
| Node.js | Prisma | Type-safe, modern |
| Node.js | Sequelize | Mature, flexible |
| Java | Hibernate / JPA | Enterprise standard |
| Go | GORM | Most popular Go ORM |
| PHP | Eloquent | Laravel's ORM |
| Ruby | Active Record | Rails ORM |

---

## ORM in Practice / ORM Trong Thực Tế

### Python SQLAlchemy

```python
from sqlalchemy import Column, BigInteger, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship, DeclarativeBase

class Base(DeclarativeBase):
    pass

class Customer(Base):
    __tablename__ = 'customers'

    id         = Column(BigInteger, primary_key=True, autoincrement=True)
    email      = Column(String(255), nullable=False, unique=True)
    full_name  = Column(String(200), nullable=False)
    status     = Column(String(20), default='active')
    orders     = relationship('Order', back_populates='customer')

class Order(Base):
    __tablename__ = 'orders'

    id          = Column(BigInteger, primary_key=True)
    customer_id = Column(BigInteger, ForeignKey('customers.id'), nullable=False)
    total_amount = Column(Numeric(14, 2))
    status      = Column(String(20))
    customer    = relationship('Customer', back_populates='orders')
```

### Node.js Prisma

```typescript
// schema.prisma
model Customer {
  id        BigInt    @id @default(autoincrement())
  email     String    @unique @db.VarChar(255)
  fullName  String    @map("full_name") @db.VarChar(200)
  orders    Order[]
  @@map("customers")
}

// Query / Truy vấn
const customers = await prisma.customer.findMany({
  where: { status: 'active' },
  include: { orders: { where: { status: 'pending' } } },
  orderBy: { createdAt: 'desc' },
  take: 20,
});
```

---

## ORM Pros & Cons / Ưu & Nhược Điểm ORM

| Aspect | ORM | Raw SQL |
|--------|-----|---------|
| Development speed | ✅ Fast | ❌ Slower |
| Code maintainability | ✅ | ⚠️ |
| Performance control | ❌ Hidden queries | ✅ Full control |
| Complex queries | ❌ Awkward | ✅ Natural |
| N+1 prevention | ⚠️ Requires care | ✅ Always explicit |
| Database portability | ✅ | ❌ |
| Debugging | ❌ Harder | ✅ Easier |

---

## Golden Rule / Quy Tắc Vàng

**Use ORM for 80% of queries. Use raw SQL for the 20% that need performance.**
_**Dùng ORM cho 80% truy vấn. Dùng raw SQL cho 20% cần hiệu năng.**_

```python
# SQLAlchemy: drop to raw SQL when needed / Chuyển sang raw SQL khi cần
result = session.execute(
    text("""
        SELECT p.name, SUM(oi.quantity) AS total_sold
        FROM order_items oi
        JOIN products p ON p.id = oi.product_id
        JOIN orders o ON o.id = oi.order_id
        WHERE o.status = 'delivered'
          AND o.created_at >= :start_date
        GROUP BY p.id, p.name
        ORDER BY total_sold DESC
        LIMIT 20
    """),
    {"start_date": "2024-01-01"}
).fetchall()
```

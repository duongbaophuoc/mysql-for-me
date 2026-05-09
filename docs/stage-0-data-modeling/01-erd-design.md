# ERD Design / Thiết Kế Sơ Đồ ERD

## Overview / Tổng Quan

Entity-Relationship Diagrams (ERDs) are the blueprint for your database schema.
_Sơ đồ Thực thể-Quan hệ (ERD) là bản thiết kế cho schema CSDL của bạn._

A well-designed ERD prevents costly schema changes later. In production, table restructuring can take hours or days due to table locks.
_ERD được thiết kế tốt ngăn chặn thay đổi schema tốn kém sau này._

---

## Core Concepts / Khái Niệm Cơ Bản

### Entities → Tables / Thực Thể → Bảng

An entity is a real-world object that has data worth storing.
_Thực thể là đối tượng thực tế có dữ liệu đáng lưu trữ._

```
Customer, Product, Order, Payment, Invoice, Employee...
```

### Attributes → Columns / Thuộc Tính → Cột

Each entity has attributes describing its properties.
_Mỗi thực thể có thuộc tính mô tả đặc điểm của nó._

```
Customer: id, email, full_name, phone, created_at
Product:  id, sku, name, price, category_id
```

### Relationships / Quan Hệ

| Type | Symbol | Example / Ví Dụ |
|------|--------|-----------------|
| One-to-One (1:1) | `——‖——` | User ↔ Profile |
| One-to-Many (1:N) | `——‖—<` | Customer → Orders |
| Many-to-Many (M:N) | `>—‖—<` | Products ↔ Tags |

---

## Cardinality / Lực Lượng Quan Hệ

```
  customers               orders
┌───────────┐           ┌──────────┐
│ id   (PK) │ 1       N │ id  (PK) │
│ email     ├───────────┤customer_id│
│ full_name │           │ total    │
└───────────┘           └──────────┘

One customer can have many orders.
Một khách hàng có thể có nhiều đơn hàng.
```

### M:N → Junction Table / Bảng Trung Gian

```
  products                              tags
┌───────────┐  product_tags  ┌───────────┐
│ id   (PK) │◄──────────────►│ id   (PK) │
│ name      │  product_id    │ name      │
└───────────┘  tag_id        └───────────┘
```

```sql
-- Junction table / Bảng trung gian
CREATE TABLE product_tags (
    product_id BIGINT UNSIGNED NOT NULL,
    tag_id     INT UNSIGNED    NOT NULL,
    PRIMARY KEY (product_id, tag_id),           -- Composite PK
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (tag_id)     REFERENCES tags(id)
) ENGINE=InnoDB;
```

---

## ERD for shop_db / ERD Cho shop_db

```
customers
  │ 1
  │
  │ N
  ├── customer_addresses
  │
  │ N
  └── orders
        │ 1            N
        ├── order_items ──────────► products
        │                                │ 1
        │                                │ N
        └── payments              inventory
                          categories (tree)
                             └── products
```

---

## Design Rules / Quy Tắc Thiết Kế

### Rule 1: Every table needs a primary key
_Mọi bảng cần khóa chính_

```sql
-- Good / Tốt
CREATE TABLE customers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    PRIMARY KEY (id)
);

-- Bad / Tệ — no PK
CREATE TABLE log_entries (
    message TEXT,
    created_at DATETIME
);
-- InnoDB will create a hidden 6-byte row ID / InnoDB sẽ tạo row ID ẩn 6 byte
```

### Rule 2: Use foreign keys to enforce referential integrity
_Dùng foreign key để đảm bảo tính toàn vẹn tham chiếu_

```sql
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id)
    REFERENCES customers(id)
    ON DELETE RESTRICT      -- Prevent orphan orders / Ngăn đơn hàng mồ côi
    ON UPDATE CASCADE;
```

### Rule 3: Name columns consistently
_Đặt tên cột nhất quán_

```
id, uuid, created_at, updated_at, deleted_at   ← standard audit columns
{entity}_id                                     ← foreign key naming
is_{flag}                                       ← boolean columns
{action}_at                                     ← timestamp columns
```

---

## Practical Exercise / Bài Tập Thực Hành

Design an ERD for a hotel booking system with:
_Thiết kế ERD cho hệ thống đặt phòng khách sạn với:_

- Hotels, Rooms, Room Types
- Customers, Bookings, Payments
- Amenities (M:N with Room Types)

Considerations / Cân nhắc:
- A booking spans multiple nights (date range)
- A room can have multiple amenities
- Prices vary by room type and season

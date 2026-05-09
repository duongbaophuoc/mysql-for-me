# shop_db — OLTP Sample Database
# shop_db — Cơ Sở Dữ Liệu Mẫu OLTP

## Overview / Tổng Quan

`shop_db` is a production-representative e-commerce OLTP database schema.
_`shop_db` là schema CSDL thương mại điện tử đại diện cho môi trường production._

It demonstrates best practices for:
_Nó minh họa các thực hành tốt nhất cho:_

- InnoDB table design with proper indexes / Thiết kế bảng InnoDB với chỉ mục phù hợp
- Soft delete pattern (`deleted_at`) / Mẫu xóa mềm
- UUID vs AUTO_INCREMENT strategies / Chiến lược UUID vs AUTO_INCREMENT
- Outbox pattern for reliable event publishing / Mẫu outbox cho phát sự kiện đáng tin cậy
- Idempotency keys in payments / Khóa mãn đẳng trong thanh toán
- JSON columns for flexible attributes / Cột JSON cho thuộc tính linh hoạt
- Generated columns for computed values / Cột được sinh cho giá trị tính toán
- Composite indexes for common query patterns / Chỉ mục tổng hợp cho mẫu truy vấn phổ biến
- Hierarchical category data (nested sets) / Dữ liệu danh mục phân cấp (nested sets)

## Schema / Lược Đồ

```
customers
  └── customer_addresses
  └── orders
        └── order_items → products
        └── payments
categories (self-referencing)
  └── products
        └── inventory
audit_log
outbox
```

## Tables / Các Bảng

| Table                  | Rows (sample) | Key Patterns                            |
| ---------------------- | ------------- | --------------------------------------- |
| `customers`            | 7             | UUID, soft delete, email unique         |
| `customer_addresses`   | 7             | FK cascade, is_default flag             |
| `categories`           | 11            | Nested sets, self-reference             |
| `products`             | 7             | JSON attributes, generated column       |
| `inventory`            | 9             | Composite unique (product+warehouse)    |
| `orders`               | 7             | UUID, composite status+customer index   |
| `order_items`          | 7             | Generated `line_total` column           |
| `payments`             | 7             | Idempotency key, gateway JSON response  |
| `audit_log`            | —             | Change tracking                         |
| `outbox`               | —             | Reliable event publishing               |

## Quick Start / Khởi Động Nhanh

```bash
# Start Docker / Khởi động Docker
docker compose -f ../../docker/docker-compose.yml up -d

# Load schema / Nạp schema
mysql -h 127.0.0.1 -P 3306 -u root -psecret < schema.sql

# Load seed data / Nạp dữ liệu mẫu
mysql -h 127.0.0.1 -P 3306 -u root -psecret < seed.sql

# Verify / Kiểm tra
mysql -h 127.0.0.1 -P 3306 -u root -psecret -e "USE shop_db; SHOW TABLES; SELECT COUNT(*) FROM orders;"
```

## Sample Queries / Truy Vấn Mẫu

```sql
-- Top selling products / Sản phẩm bán chạy nhất
SELECT p.name, SUM(oi.quantity) AS total_sold
FROM order_items oi
JOIN products p ON p.id = oi.product_id
JOIN orders o ON o.id = oi.order_id
WHERE o.status = 'delivered'
GROUP BY p.id, p.name
ORDER BY total_sold DESC;

-- Customer order history / Lịch sử đơn hàng khách hàng
SELECT c.full_name, o.id AS order_id, o.total_amount, o.status
FROM customers c
JOIN orders o ON o.customer_id = c.id
WHERE c.deleted_at IS NULL
ORDER BY o.created_at DESC;

-- Revenue by source channel / Doanh thu theo kênh bán
SELECT source, COUNT(*) AS orders, SUM(total_amount) AS revenue
FROM orders
WHERE status = 'delivered'
GROUP BY source;
```

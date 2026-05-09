# JOINs in MySQL / JOIN Trong MySQL

## Overview / Tổng Quan

JOINs combine rows from two or more tables based on a related column between them.
_JOIN kết hợp các hàng từ hai hoặc nhiều bảng dựa trên cột liên quan giữa chúng._

---

## INNER JOIN — Most Common / Phổ Biến Nhất

Returns rows where the join condition is TRUE in **both** tables.
_Trả về hàng mà điều kiện join là TRUE trong **cả hai** bảng._

```sql
-- Orders with their customer / Đơn hàng với khách hàng của họ
SELECT
    o.id          AS order_id,
    o.total_amount,
    o.status,
    c.email       AS customer_email,
    c.full_name
FROM orders o
INNER JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'pending'
ORDER BY o.created_at DESC;
-- Only orders that HAVE a customer are returned
-- Chỉ trả về đơn hàng CÓ khách hàng
```

---

## LEFT JOIN — Include All from Left Table / Bao Gồm Tất Cả Từ Bảng Trái

Returns all rows from LEFT table, NULL for non-matching RIGHT rows.
_Trả về tất cả hàng từ bảng TRÁI, NULL cho hàng không khớp bên phải._

```sql
-- All customers, even those with no orders
-- Tất cả khách hàng, kể cả người chưa có đơn hàng
SELECT
    c.id,
    c.full_name,
    COUNT(o.id)    AS order_count,
    COALESCE(SUM(o.total_amount), 0) AS lifetime_value
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
                   AND o.status != 'cancelled'  -- join condition, not WHERE!
WHERE c.deleted_at IS NULL
GROUP BY c.id, c.full_name
ORDER BY lifetime_value DESC;
```

---

## RIGHT JOIN — Rarely Used / Hiếm Khi Dùng

Same as LEFT JOIN but reversed. Rewrite as LEFT JOIN for clarity.
_Giống LEFT JOIN nhưng ngược lại. Viết lại thành LEFT JOIN để rõ ràng hơn._

---

## CROSS JOIN — Cartesian Product / Tích Đề-các

Returns every combination of rows from both tables. Use with caution.
_Trả về mọi tổ hợp hàng từ cả hai bảng. Dùng cẩn thận._

```sql
-- Generate all (warehouse, product) combinations / Tạo tất cả tổ hợp (kho, sản phẩm)
SELECT p.id AS product_id, w.code AS warehouse_code
FROM products p
CROSS JOIN (SELECT 'WH-HN-01' AS code UNION SELECT 'WH-SGN-01') w
WHERE p.status = 'active';
-- 7 products × 2 warehouses = 14 rows / 7 sản phẩm × 2 kho = 14 hàng
```

---

## SELF JOIN — Table Joins Itself / Bảng Tự Join

```sql
-- Find customers in same city / Tìm khách hàng cùng thành phố
-- (requires customer_addresses)
SELECT
    a1.customer_id AS customer_a,
    a2.customer_id AS customer_b,
    a1.city
FROM customer_addresses a1
INNER JOIN customer_addresses a2
    ON a1.city = a2.city
    AND a1.customer_id < a2.customer_id  -- avoid duplicates
WHERE a1.is_default = 1 AND a2.is_default = 1;
```

---

## Multi-table JOIN / JOIN Nhiều Bảng

```sql
-- Complete order details / Chi tiết đơn hàng đầy đủ
SELECT
    o.id          AS order_id,
    o.status,
    c.full_name   AS customer,
    p.name        AS product,
    oi.quantity,
    oi.unit_price,
    oi.line_total,
    pay.method    AS payment_method,
    pay.status    AS payment_status
FROM orders o
INNER JOIN customers   c   ON c.id   = o.customer_id
INNER JOIN order_items oi  ON oi.order_id = o.id
INNER JOIN products    p   ON p.id   = oi.product_id
LEFT  JOIN payments    pay ON pay.order_id = o.id   -- payment might not exist yet
WHERE o.id = 3;
```

---

## JOIN Performance Tips / Mẹo Hiệu Năng JOIN

```sql
-- 1. Always join on indexed columns / Luôn join trên cột đã index
-- customers.id is PK (indexed), orders.customer_id should be indexed
ALTER TABLE orders ADD INDEX idx_orders_customer_id (customer_id);

-- 2. Use EXPLAIN to verify JOIN type / Dùng EXPLAIN để kiểm tra kiểu JOIN
EXPLAIN SELECT o.id, c.email FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'pending'\G
-- Look for: type=eq_ref on customers ← perfect (PK lookup per row)

-- 3. Filter early / Lọc sớm
-- Join only the rows you need, not all then filter
FROM (SELECT * FROM orders WHERE status = 'pending' LIMIT 1000) o
JOIN customers c ON c.id = o.customer_id
```

---

## JOIN vs Subquery / JOIN vs Subquery

```sql
-- JOIN (usually faster) / JOIN (thường nhanh hơn)
SELECT o.id FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE c.status = 'active';

-- Correlated subquery (slower for large sets)
SELECT o.id FROM orders o
WHERE EXISTS (
    SELECT 1 FROM customers c
    WHERE c.id = o.customer_id AND c.status = 'active'
);
```

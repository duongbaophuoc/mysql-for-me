# CTEs & Recursive Queries / CTE & Truy Vấn Đệ Quy

## Overview / Tổng Quan

**CTE (Common Table Expression)** is a named temporary result set defined within a query using `WITH`.
_**CTE** là tập kết quả tạm có tên được định nghĩa trong một truy vấn sử dụng `WITH`._

---

## Basic CTE / CTE Cơ Bản

```sql
-- Non-recursive CTE: cleaner alternative to subqueries
-- CTE không đệ quy: thay thế subquery rõ ràng hơn
WITH pending_orders AS (
    SELECT id, customer_id, total_amount, created_at
    FROM orders
    WHERE status = 'pending'
      AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
),
high_value AS (
    SELECT * FROM pending_orders WHERE total_amount > 1000000
)
SELECT
    po.id,
    c.full_name,
    po.total_amount
FROM high_value po
JOIN customers c ON c.id = po.customer_id
ORDER BY po.total_amount DESC;
```

---

## Multiple CTEs / Nhiều CTE

```sql
-- Chain CTEs for step-by-step logic / Chuỗi CTE cho logic từng bước
WITH
-- Step 1: completed orders / Bước 1: đơn hàng hoàn thành
completed AS (
    SELECT customer_id, COUNT(*) AS orders, SUM(total_amount) AS revenue
    FROM orders
    WHERE status = 'delivered'
    GROUP BY customer_id
),
-- Step 2: classify customers / Bước 2: phân loại khách hàng
classified AS (
    SELECT
        customer_id,
        orders,
        revenue,
        CASE
            WHEN revenue > 50000000  THEN 'vip'
            WHEN revenue > 10000000  THEN 'regular'
            ELSE                          'new'
        END AS segment
    FROM completed
)
-- Step 3: join to get names
SELECT c.full_name, cl.segment, cl.revenue
FROM classified cl
JOIN customers c ON c.id = cl.customer_id
ORDER BY cl.revenue DESC;
```

---

## Recursive CTE / CTE Đệ Quy

Recursive CTEs traverse tree-structured data:
_CTE đệ quy duyệt dữ liệu cấu trúc cây:_

```sql
-- Traverse category hierarchy / Duyệt phân cấp danh mục
WITH RECURSIVE category_path AS (
    -- Base case: start at root / Trường hợp gốc: bắt đầu tại gốc
    SELECT
        id,
        parent_id,
        name,
        CAST(name AS CHAR(1000))   AS full_path,
        0                           AS depth
    FROM categories
    WHERE parent_id IS NULL       -- root categories / danh mục gốc

    UNION ALL

    -- Recursive case: add children / Trường hợp đệ quy: thêm con
    SELECT
        c.id,
        c.parent_id,
        c.name,
        CONCAT(cp.full_path, ' > ', c.name),
        cp.depth + 1
    FROM categories c
    INNER JOIN category_path cp ON cp.id = c.parent_id
)
SELECT * FROM category_path ORDER BY full_path;

-- Result:
-- Electronics
-- Electronics > Accessories
-- Electronics > Laptops
-- Electronics > Laptops > Business Laptops
-- Electronics > Laptops > Gaming Laptops
-- Electronics > Smartphones
```

---

## Recursive CTE for Number Series / CTE Đệ Quy Cho Dãy Số

```sql
-- Generate a sequence: useful for date ranges, test data
-- Tạo dãy số: hữu ích cho phạm vi ngày, dữ liệu test
WITH RECURSIVE nums AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 100
)
SELECT n FROM nums;  -- 1 to 100

-- Generate date series / Tạo dãy ngày
WITH RECURSIVE dates AS (
    SELECT '2024-01-01' AS dt
    UNION ALL
    SELECT DATE_ADD(dt, INTERVAL 1 DAY)
    FROM dates
    WHERE dt < '2024-12-31'
)
SELECT dt FROM dates;
```

---

## CTE vs Subquery / CTE vs Subquery

```sql
-- Subquery (harder to read) / Subquery (khó đọc hơn)
SELECT id FROM orders WHERE customer_id IN (
    SELECT id FROM customers WHERE status = 'active'
    AND id NOT IN (SELECT customer_id FROM orders WHERE status = 'cancelled')
);

-- CTE (cleaner) / CTE (rõ ràng hơn)
WITH active_customers AS (
    SELECT id FROM customers WHERE status = 'active'
),
cancelled_customers AS (
    SELECT DISTINCT customer_id FROM orders WHERE status = 'cancelled'
)
SELECT o.id
FROM orders o
JOIN active_customers ac ON ac.id = o.customer_id
WHERE o.customer_id NOT IN (SELECT customer_id FROM cancelled_customers);
```

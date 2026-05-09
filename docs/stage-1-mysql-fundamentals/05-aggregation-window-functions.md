# Aggregation & Window Functions / Tổng Hợp & Hàm Cửa Sổ

## Overview / Tổng Quan

Aggregation summarizes many rows into one. Window functions perform calculations across related rows **without collapsing them**.
_Tổng hợp thu gọn nhiều hàng thành một. Hàm cửa sổ thực hiện tính toán trên các hàng liên quan **mà không thu gọn chúng**._

---

## Aggregation Functions / Hàm Tổng Hợp

```sql
SELECT
    status,
    COUNT(*)                          AS order_count,
    COUNT(DISTINCT customer_id)       AS unique_customers,
    SUM(total_amount)                 AS total_revenue,
    AVG(total_amount)                 AS avg_order_value,
    MIN(total_amount)                 AS min_order,
    MAX(total_amount)                 AS max_order
FROM orders
WHERE created_at >= '2024-01-01'
GROUP BY status
HAVING COUNT(*) > 5            -- filter on aggregate (not WHERE) / lọc trên tổng hợp
ORDER BY total_revenue DESC;
```

---

## GROUP BY Rules / Quy Tắc GROUP BY

```sql
-- In MySQL 8.0 (ONLY_FULL_GROUP_BY enabled by default):
-- Every SELECT column must be in GROUP BY or an aggregate function
-- Mỗi cột SELECT phải có trong GROUP BY hoặc là hàm tổng hợp

-- BAD / Tệ (fails in strict mode):
SELECT customer_id, email, COUNT(*) FROM orders GROUP BY customer_id;
-- 'email' not in GROUP BY!

-- GOOD / Tốt:
SELECT o.customer_id, c.email, COUNT(*) AS orders
FROM orders o JOIN customers c ON c.id = o.customer_id
GROUP BY o.customer_id, c.email;
```

---

## Window Functions / Hàm Cửa Sổ

Window functions operate over a "window" of related rows:
_Hàm cửa sổ hoạt động trên một "cửa sổ" các hàng liên quan:_

```sql
SELECT
    id,
    customer_id,
    total_amount,
    -- Rank orders by value within each customer / Xếp hạng đơn hàng theo giá trị
    ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY total_amount DESC
    ) AS rank_in_customer,
    -- Running total for each customer / Tổng luỹ kế mỗi khách hàng
    SUM(total_amount) OVER (
        PARTITION BY customer_id
        ORDER BY created_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_spend,
    -- Customer's total (same for all rows of that customer)
    -- Tổng của khách hàng (giống nhau cho tất cả hàng của KH đó)
    SUM(total_amount) OVER (PARTITION BY customer_id) AS customer_total,
    -- Percentage of customer total / Phần trăm tổng khách hàng
    ROUND(
        total_amount / SUM(total_amount) OVER (PARTITION BY customer_id) * 100, 2
    ) AS pct_of_customer_total
FROM orders
WHERE status = 'delivered';
```

---

## Ranking Functions / Hàm Xếp Hạng

```sql
SELECT
    product_id,
    SUM(quantity)    AS units_sold,
    -- ROW_NUMBER: unique rank, no ties / Xếp hạng duy nhất, không có hòa
    ROW_NUMBER()  OVER (ORDER BY SUM(quantity) DESC) AS row_num,
    -- RANK: ties get same rank, next skips / Hòa cùng hạng, hạng tiếp bị bỏ qua
    RANK()        OVER (ORDER BY SUM(quantity) DESC) AS rank_with_gaps,
    -- DENSE_RANK: ties get same rank, no gaps / Hòa cùng hạng, không bỏ hạng
    DENSE_RANK()  OVER (ORDER BY SUM(quantity) DESC) AS dense_rank,
    -- NTILE: divide into N buckets / Chia thành N nhóm
    NTILE(4)      OVER (ORDER BY SUM(quantity) DESC) AS quartile
FROM order_items
GROUP BY product_id;
```

---

## LAG / LEAD — Compare Adjacent Rows / So Sánh Hàng Kề

```sql
-- Month-over-month revenue comparison / So sánh doanh thu tháng này vs tháng trước
SELECT
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    SUM(total_amount)                AS revenue,
    LAG(SUM(total_amount), 1) OVER (
        ORDER BY DATE_FORMAT(created_at, '%Y-%m')
    ) AS prev_month_revenue,
    ROUND(
        (SUM(total_amount) - LAG(SUM(total_amount), 1)
         OVER (ORDER BY DATE_FORMAT(created_at, '%Y-%m')))
        / LAG(SUM(total_amount), 1)
          OVER (ORDER BY DATE_FORMAT(created_at, '%Y-%m')) * 100, 2
    ) AS mom_growth_pct
FROM orders
WHERE status = 'delivered'
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY month;
```

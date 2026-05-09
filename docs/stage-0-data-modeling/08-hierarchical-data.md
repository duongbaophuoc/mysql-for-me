# Hierarchical Data in MySQL / Dữ Liệu Phân Cấp Trong MySQL

## Overview / Tổng Quan

Trees and hierarchies (categories, org charts, menus, comment threads) require special modeling in relational databases.
_Cây và phân cấp (danh mục, sơ đồ tổ chức, menu, chuỗi bình luận) cần mô hình hóa đặc biệt trong CSDL quan hệ._

---

## Pattern 1: Adjacency List / Danh Sách Kề

Each row stores a reference to its **direct parent**.
_Mỗi hàng lưu tham chiếu đến **cha trực tiếp**._

```sql
CREATE TABLE categories (
    id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    parent_id INT UNSIGNED NULL,                    -- NULL = root
    name      VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    KEY idx_parent (parent_id),
    FOREIGN KEY (parent_id) REFERENCES categories(id)
);

-- Simple, easy to maintain / Đơn giản, dễ bảo trì
-- But: fetching full path requires recursive queries
-- Nhưng: lấy đường dẫn đầy đủ cần truy vấn đệ quy
```

### Recursive CTE for tree traversal / CTE đệ quy duyệt cây

```sql
-- Get all descendants of Electronics (id=1)
-- Lấy tất cả hậu duệ của Electronics (id=1)
WITH RECURSIVE category_tree AS (
    -- Base: start node / Gốc: nút bắt đầu
    SELECT id, parent_id, name, 0 AS depth
    FROM categories WHERE id = 1

    UNION ALL

    -- Recursive: children of each node / Đệ quy: con của mỗi nút
    SELECT c.id, c.parent_id, c.name, ct.depth + 1
    FROM categories c
    JOIN category_tree ct ON ct.id = c.parent_id
)
SELECT * FROM category_tree ORDER BY depth, name;
```

---

## Pattern 2: Nested Sets / Tập Hợp Lồng Nhau

Each node stores **left** and **right** boundary values. Subtrees are retrieved with a range query.
_Mỗi nút lưu giá trị biên **trái** và **phải**. Cây con được lấy bằng truy vấn phạm vi._

```sql
CREATE TABLE categories_ns (
    id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    lft  INT UNSIGNED NOT NULL,
    rgt  INT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    KEY idx_lft_rgt (lft, rgt)
);

-- Tree structure / Cấu trúc cây:
-- Electronics (lft=1, rgt=20)
--   Phones (lft=2, rgt=7)
--     Android (lft=3, rgt=4)
--     iPhone (lft=5, rgt=6)
--   Laptops (lft=8, rgt=13)

-- Get all descendants of Electronics in ONE query!
-- Lấy tất cả hậu duệ của Electronics trong MỘT truy vấn!
SELECT child.*
FROM categories_ns parent
JOIN categories_ns child
    ON child.lft BETWEEN parent.lft AND parent.rgt
WHERE parent.id = 1  -- Electronics
ORDER BY child.lft;

-- Count depth / Đếm độ sâu
SELECT c.name,
       COUNT(p.id) - 1 AS depth
FROM categories_ns c
JOIN categories_ns p ON c.lft BETWEEN p.lft AND p.rgt
WHERE c.id = 3  -- Android
GROUP BY c.id, c.name;
```

### Nested Sets: Pros & Cons / Ưu & Nhược Điểm

```
✅ Very fast reads (range query, one JOIN)
✅ Depth calculation easy
❌ Complex writes (INSERT rebalances all lft/rgt values)
❌ Concurrent writes need full table lock
```

---

## Pattern 3: Closure Table / Bảng Đóng

Separate table storing all ancestor-descendant pairs:
_Bảng riêng lưu tất cả cặp tổ tiên-hậu duệ:_

```sql
CREATE TABLE category_paths (
    ancestor   INT UNSIGNED NOT NULL,
    descendant INT UNSIGNED NOT NULL,
    depth      INT          NOT NULL DEFAULT 0,
    PRIMARY KEY (ancestor, descendant),
    KEY idx_descendant (descendant)
);

-- Get all ancestors of iPhone (id=4)
-- Lấy tất cả tổ tiên của iPhone (id=4)
SELECT c.*
FROM category_paths cp
JOIN categories c ON c.id = cp.ancestor
WHERE cp.descendant = 4
ORDER BY cp.depth;
```

---

## Pattern in shop_db / Mẫu Trong shop_db

```sql
-- shop_db uses nested sets for categories
-- shop_db dùng nested sets cho danh mục
-- See: sample-db/shop_db/schema.sql
-- categories table has: lft, rgt, depth columns

-- Get all categories under Electronics / Lấy tất cả danh mục trong Electronics
SELECT child.name, child.depth
FROM categories parent
JOIN categories child
    ON child.lft BETWEEN parent.lft AND parent.rgt
WHERE parent.slug = 'electronics'
ORDER BY child.lft;
```

---

## Choosing a Pattern / Chọn Mẫu

| Pattern | Read | Write | Depth Query | Best For |
|---------|------|-------|-------------|----------|
| Adjacency List | Medium | Easy | Recursive CTE | General use |
| Nested Sets | Fast | Hard | Fast | Read-heavy hierarchies |
| Closure Table | Fast | Medium | Fast | Flexible querying |
| Path Enumeration | Medium | Easy | Simple | Small trees |

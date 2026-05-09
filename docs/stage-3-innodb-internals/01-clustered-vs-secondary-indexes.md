# Clustered vs Secondary Indexes / Index Cụm vs Index Phụ

## Overview / Tổng Quan

InnoDB organizes all table data inside the **clustered index** (the B+ tree built on the primary key). Every other index is a **secondary index**.
_InnoDB tổ chức tất cả dữ liệu bảng trong **index cụm** (cây B+ xây dựng trên khóa chính). Mọi index khác là **index phụ**._

---

## Clustered Index / Index Cụm

```
B+ Tree built on PRIMARY KEY / Cây B+ xây dựng trên PRIMARY KEY:

           [50]                    ← Internal node (key only)
          /    \
       [25]    [75]
      /    \      \
[1─10][11─24][26─49]  [51─74][75─100]  ← Leaf nodes (full row data!)
   data  data  data     data    data
```

- Leaf nodes contain the **actual row data** / Leaf node chứa **dữ liệu hàng thực tế**
- Only one clustered index per table / Chỉ một index cụm mỗi bảng
- If no PK defined, InnoDB creates a hidden 6-byte rowid / Nếu không có PK, InnoDB tạo rowid ẩn 6 byte

---

## Secondary Index / Index Phụ

```
Secondary index on (status) / Index phụ trên (status):

B+ Tree: [confirmed][delivered][pending]...
Leaf nodes contain: / Leaf node chứa:
  status value + PRIMARY KEY value (not full row!)
  giá trị status + giá trị PRIMARY KEY (không phải hàng đầy đủ!)
```

### Double Lookup (Table Bounce) / Tra Cứu Kép

```sql
-- Query using secondary index / Truy vấn dùng index phụ
SELECT id, email FROM customers WHERE status = 'active';
```

```
Step 1: Walk secondary index to find status='active'
        Duyệt index phụ để tìm status='active'
        → Returns: [PK=1, PK=5, PK=12, PK=33...]

Step 2: For each PK, go back to clustered index to fetch (id, email)
        Với mỗi PK, quay lại index cụm để lấy (id, email)
        → Random IO! / IO ngẫu nhiên!
```

**Covering index** eliminates Step 2 by including all needed columns in the secondary index.
_**Index bao phủ** loại bỏ Bước 2 bằng cách đưa tất cả cột cần thiết vào index phụ._

```sql
ALTER TABLE customers
    ADD INDEX idx_status_cover (status, id, email);
-- Now only secondary index walk needed — no clustered lookup!
-- Chỉ cần duyệt index phụ — không cần tra cứu cụm!
```

---

## Primary Key Design Impact / Tác Động Thiết Kế Khóa Chính

### INT/BIGINT AUTO_INCREMENT (Best for InnoDB)
```sql
PRIMARY KEY (id)   -- Sequential inserts = optimal B+ tree
                   -- Chèn tuần tự = B+ tree tối ưu
```

### UUID v4 (Random — Causes Page Splits)
```sql
PRIMARY KEY (uuid)  -- Random order = B+ tree page splits
                    -- Thứ tự ngẫu nhiên = phân tách trang B+
-- 30-50% worse write performance on large tables
-- Hiệu năng ghi tệ hơn 30-50% trên bảng lớn
```

---

## Checking Indexes / Kiểm Tra Index

```sql
-- View all indexes on a table / Xem tất cả index trên bảng
SHOW INDEX FROM orders\G

-- Cardinality matters: higher = more selective = better index
-- Tính đặc trưng quan trọng: cao hơn = chọn lọc hơn = index tốt hơn
-- |Cardinality|  |Rows| ratio should be high

-- Index usage from performance schema / Sử dụng index từ performance schema
SELECT INDEX_NAME, COUNT_FETCH, COUNT_INSERT
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_NAME = 'orders'
  AND OBJECT_SCHEMA = 'shop_db';
```

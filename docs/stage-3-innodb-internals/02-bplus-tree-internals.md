# B+ Tree Internals / Nội Bộ Cây B+

## Overview / Tổng Quan

InnoDB uses **B+ trees** (Balanced Plus trees) as the data structure for all indexes.
_InnoDB sử dụng **cây B+** làm cấu trúc dữ liệu cho tất cả index._

---

## B+ Tree Structure / Cấu Trúc Cây B+

```
B+ Tree with order 3 / Cây B+ bậc 3 (max 3 keys per node):

                  Root Node / Nút gốc
                  ┌──────────┐
                  │  25 │ 50 │
                  └──┬───┬───┘
          ┌──────────┘   └──────────┐
    ┌─────┴──────┐           ┌──────┴─────┐
    │  10 │ 20  │           │  35 │ 45  │
    └──┬──┬──┬──┘           └──┬──┬──┬──┘
     leaf leaf leaf          leaf leaf leaf leaf

Leaf Node / Nút lá (in InnoDB, for clustered index):
┌─────────────────────────────────────────────┐
│  id=10 │ (full row data) │ → │  next leaf  │
└─────────────────────────────────────────────┘
Leaf nodes are linked as a doubly-linked list
Nút lá được liên kết thành danh sách liên kết đôi
```

---

## Why B+ Tree? / Tại Sao Cây B+?

```
Balanced: all leaves at same depth → O(log n) for all operations
          tất cả lá ở cùng độ sâu → O(log n) cho mọi thao tác

Page-friendly: fits 100s of keys per 16KB page → few disk reads
               hàng trăm key mỗi trang 16KB → ít đọc đĩa

For 10M rows table / Cho bảng 10M hàng:
  Height ≈ log(1000) × log(10,000,000) ≈ 3-4 levels
  Search = only 3-4 disk reads / Tìm kiếm = chỉ 3-4 đọc đĩa!
```

---

## Page Structure / Cấu Trúc Trang

```
InnoDB Page (16KB default) / Trang InnoDB (16KB mặc định):

┌──────────────────────────────────────────┐
│ Page Header (38 bytes)                   │
│   page_no, page_type, LSN, checksum      │
├──────────────────────────────────────────┤
│ Row Data (variable)                      │
│   [row1][row2]...[rowN]                  │
│   Sorted by PK / Sắp xếp theo PK        │
├──────────────────────────────────────────┤
│ Page Directory (variable)                │
│   Slots pointing to row groups           │
├──────────────────────────────────────────┤
│ Page Trailer (8 bytes)                   │
│   Checksum for integrity                 │
└──────────────────────────────────────────┘
```

---

## Insert Performance / Hiệu Năng Chèn

### Sequential vs Random Inserts / Chèn Tuần Tự vs Ngẫu Nhiên

```
SEQUENTIAL (AUTO_INCREMENT PK) / Tuần tự:
  New rows always append to the rightmost leaf
  → No page splits needed
  → Efficient use of 16KB pages (~95% full)
  Chèn vào lá ngoài cùng bên phải — không phân tách trang

RANDOM (UUID v4 PK) / Ngẫu nhiên:
  New rows insert anywhere in the tree
  → Frequent page splits (page becomes 50% full after split)
  → More pages needed, more disk space, slower queries
  Chèn khắp nơi trong cây — phân tách trang thường xuyên
```

---

## Reading B+ Tree Info from MySQL / Đọc Thông Tin Cây B+

```sql
-- Index page statistics / Thống kê trang index
SELECT
    INDEX_NAME,
    STAT_NAME,
    STAT_VALUE,
    STAT_DESCRIPTION
FROM mysql.innodb_index_stats
WHERE database_name = 'shop_db'
  AND table_name    = 'orders'
ORDER BY INDEX_NAME, STAT_NAME;

-- Key stat: n_leaf_pages = number of leaf node pages
-- Stat quan trọng: n_leaf_pages = số trang nút lá
-- size = total pages in the index tree
-- n_diff_pfx01 = cardinality of first index column
```

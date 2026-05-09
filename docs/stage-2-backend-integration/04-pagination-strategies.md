# Pagination Strategies / Chiến Lược Phân Trang

## Overview / Tổng Quan

Pagination is how applications retrieve large result sets in manageable chunks.
_Phân trang là cách ứng dụng lấy tập kết quả lớn theo từng khúc có thể quản lý._

---

## Strategy 1: OFFSET / LIMIT — The Classic Problem

```sql
-- Page 1 / Trang 1 (fast)
SELECT id, status, total_amount
FROM orders
ORDER BY created_at DESC
LIMIT 20 OFFSET 0;

-- Page 5001 / Trang 5001 (SLOW!)
SELECT id, status, total_amount
FROM orders
ORDER BY created_at DESC
LIMIT 20 OFFSET 100000;   -- MySQL scans 100,020 rows to return 20!
-- MySQL quét 100,020 hàng để trả về 20!
```

### Why OFFSET Is Slow / Tại Sao OFFSET Chậm

```
MySQL must walk through all previous rows before reaching OFFSET position.
MySQL phải đi qua tất cả hàng trước trước khi đến vị trí OFFSET.

Page 1:   scan  20 rows ✅
Page 100: scan 2,000 rows ⚠️
Page 5000: scan 100,020 rows ❌ (100x slower than page 1!)
```

---

## Strategy 2: Keyset Pagination (Cursor-based) — Recommended
## Chiến Lược 2: Phân Trang Keyset (Dựa Trên Con Trỏ) — Khuyến Nghị

```sql
-- First page / Trang đầu
SELECT id, status, total_amount, created_at
FROM orders
ORDER BY created_at DESC, id DESC
LIMIT 20;
-- Returns last row: created_at='2024-12-15 14:23:01', id=1050

-- Next page — use last row as cursor / Dùng hàng cuối làm con trỏ
SELECT id, status, total_amount, created_at
FROM orders
WHERE (created_at, id) < ('2024-12-15 14:23:01', 1050)
   -- OR: created_at < '2024-12-15 14:23:01'
   -- OR: created_at = '2024-12-15 14:23:01' AND id < 1050
ORDER BY created_at DESC, id DESC
LIMIT 20;
-- Always scans exactly LIMIT rows — constant performance!
-- Luôn quét đúng LIMIT hàng — hiệu năng hằng định!
```

### Supporting Index for Keyset / Chỉ Mục Cho Keyset

```sql
-- Index that supports the cursor query / Chỉ mục hỗ trợ truy vấn con trỏ
ALTER TABLE orders ADD INDEX idx_orders_cursor (created_at DESC, id DESC);
```

---

## Strategy 3: Page Count with Approximation

```sql
-- Exact count is slow on large tables / COUNT chính xác chậm trên bảng lớn
SELECT COUNT(*) FROM orders WHERE status = 'active';  -- SLOW on 10M rows

-- Use table statistics for approximate count / Dùng thống kê bảng cho số gần đúng
SELECT TABLE_ROWS AS approx_count
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'shop_db' AND TABLE_NAME = 'orders';
-- ~accurate within 10-20% / ~chính xác trong 10-20%
```

---

## Strategy 4: Seek with ID Range

```sql
-- Efficient for purely ID-based navigation / Hiệu quả cho điều hướng thuần túy theo ID
SELECT id, status, total_amount
FROM orders
WHERE id > :last_seen_id       -- only read forward / chỉ đọc tiến
  AND status = 'pending'
ORDER BY id ASC
LIMIT 20;
```

---

## API Response Format for Pagination / Định Dạng API Cho Phân Trang

```json
{
  "data": [...20 orders...],
  "pagination": {
    "limit": 20,
    "has_more": true,
    "next_cursor": "2024-12-15T14:23:01.000Z_1050",
    "total_approximate": 15000
  }
}
```

---

## Comparison / So Sánh

| Strategy | Performance | Random Access | Consistent | UI Support |
|----------|-------------|--------------|------------|------------|
| OFFSET/LIMIT | ❌ O(n) | ✅ Yes | ❌ No | ✅ Page numbers |
| Keyset | ✅ O(1) | ❌ No | ✅ Yes | ⚠️ Prev/Next only |
| ID Range | ✅ | ⚠️ Sequential | ✅ | ⚠️ |

**Rule**: Use OFFSET/LIMIT only for admin UIs with few pages. Use keyset for APIs and high-volume pagination.
_**Quy tắc**: Chỉ dùng OFFSET/LIMIT cho UI admin có ít trang. Dùng keyset cho API và phân trang lượng lớn._

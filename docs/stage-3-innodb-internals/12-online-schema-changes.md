# Online Schema Changes / Thay Đổi Schema Không Gián Đoạn

## Overview / Tổng Quan

In production, standard `ALTER TABLE` can lock a table for minutes or hours. For large tables, this is unacceptable.
_Trong production, `ALTER TABLE` chuẩn có thể lock bảng trong vài phút hoặc giờ. Với bảng lớn, điều này không thể chấp nhận._

---

## MySQL 8.0 Instant DDL / DDL Tức Thì MySQL 8.0

MySQL 8.0 introduced `ALGORITHM=INSTANT` for many common operations:
_MySQL 8.0 giới thiệu `ALGORITHM=INSTANT` cho nhiều thao tác phổ biến:_

```sql
-- Instantly: add column at end of table / Tức thì: thêm cột vào cuối bảng
ALTER TABLE orders
    ADD COLUMN promo_code VARCHAR(50) NULL,
    ALGORITHM=INSTANT;

-- Instantly: change column DEFAULT / Đổi DEFAULT tức thì
ALTER TABLE orders
    ALTER COLUMN source SET DEFAULT 'web',
    ALGORITHM=INSTANT;

-- Instantly: rename index / Đổi tên index tức thì
ALTER TABLE orders
    RENAME INDEX idx_old_name TO idx_new_name,
    ALGORITHM=INSTANT;

-- Operations that still require table rebuild (NOT INSTANT):
-- Thao tác vẫn cần rebuild bảng (KHÔNG INSTANT):
-- - Change column type
-- - Add/modify column in middle of table (MySQL < 8.0.29)
-- - Add INDEX (uses INPLACE — concurrent reads/writes allowed)
```

---

## INPLACE vs COPY Algorithm / Thuật Toán INPLACE vs COPY

```sql
-- INPLACE: modifies table in-place, allows concurrent DML
-- INPLACE: sửa đổi bảng tại chỗ, cho phép DML đồng thời
ALTER TABLE orders
    ADD INDEX idx_status_created (status, created_at),
    ALGORITHM=INPLACE,
    LOCK=NONE;          -- NONE: full concurrent access! / truy cập đồng thời đầy đủ!

-- COPY: creates a full copy → table is locked during copy
-- COPY: tạo bản sao đầy đủ → bảng bị lock trong quá trình sao chép
ALTER TABLE orders
    CHANGE COLUMN total_amount total_amount DECIMAL(16,2),  -- type change
    ALGORITHM=COPY;     -- must lock! / phải lock!
```

---

## gh-ost — GitHub's Online Schema Change

For changes that can't use INSTANT or INPLACE without locks:
_Cho thay đổi không thể dùng INSTANT hoặc INPLACE không lock:_

```bash
gh-ost \
  --mysql-host=127.0.0.1 \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password=secret \
  --database=shop_db \
  --table=orders \
  --alter="CHANGE COLUMN amount amount DECIMAL(16,4)" \
  --allow-on-master \
  --execute

# gh-ost approach / Cách tiếp cận gh-ost:
# 1. Create shadow table _orders_gho with new schema
# 2. Copy rows in chunks (default 1000 rows)
# 3. Apply ongoing binlog changes to shadow table
# 4. Atomic rename: orders → _orders_del, _orders_gho → orders
```

---

## pt-online-schema-change (pt-osc) — Percona Toolkit

Trigger-based alternative to gh-ost:
_Thay thế dựa trên trigger cho gh-ost:_

```bash
pt-online-schema-change \
  --alter="ADD COLUMN promo_code VARCHAR(50) NULL" \
  --host=localhost \
  --user=root \
  --password=secret \
  --database=shop_db \
  --table=orders \
  --execute
```

---

## Tool Comparison / So Sánh Công Cụ

| Tool | Method | Replica safe | Low-risk |
|------|--------|-------------|---------|
| `INSTANT` | Meta-only | ✅ | ✅ |
| `INPLACE, LOCK=NONE` | In-place | ✅ | ✅ |
| `gh-ost` | Binlog stream | ✅ | ✅✅ |
| `pt-osc` | Triggers | ⚠️ | ✅ |
| `COPY` | Full copy | ❌ (locks) | ❌ |

**Preference order for large tables**: INSTANT → INPLACE → gh-ost → pt-osc → avoid COPY

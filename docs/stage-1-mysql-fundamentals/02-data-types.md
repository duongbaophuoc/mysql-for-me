# MySQL Data Types / Kiểu Dữ Liệu MySQL

## Overview / Tổng Quan

Choosing the right data type affects **storage**, **index efficiency**, and **query performance**.
_Chọn đúng kiểu dữ liệu ảnh hưởng đến **lưu trữ**, **hiệu quả chỉ mục**, và **hiệu năng truy vấn**._

---

## Integer Types / Kiểu Số Nguyên

| Type | Storage | Signed Range | Unsigned Range | Use Case |
|------|---------|-------------|---------------|----------|
| `TINYINT` | 1 byte | -128 to 127 | 0–255 | booleans, small enums |
| `SMALLINT` | 2 bytes | -32,768 to 32,767 | 0–65,535 | status codes |
| `MEDIUMINT` | 3 bytes | -8M to 8M | 0–16M | moderate counts |
| `INT` | 4 bytes | -2.1B to 2.1B | 0–4.3B | standard IDs |
| `BIGINT` | 8 bytes | ±9.2×10¹⁸ | 0–1.8×10¹⁹ | large PKs, timestamps |

```sql
-- Use UNSIGNED for IDs — doubles the positive range
-- Dùng UNSIGNED cho ID — nhân đôi phạm vi dương
id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT

-- Use TINYINT(1) for booleans / Dùng TINYINT(1) cho boolean
is_active TINYINT(1) NOT NULL DEFAULT 1
-- MySQL 8.0+: use BOOLEAN (alias for TINYINT(1))
is_active BOOLEAN NOT NULL DEFAULT TRUE
```

---

## String Types / Kiểu Chuỗi

| Type | Max Size | Storage | Use When |
|------|----------|---------|----------|
| `CHAR(n)` | 255 chars | Fixed n bytes | Fixed-length (UUID CHAR(36), country CHAR(2)) |
| `VARCHAR(n)` | 65,535 bytes | 1–2 + actual | Variable strings (email, name) |
| `TEXT` | 64 KB | Off-page if large | Articles, descriptions |
| `MEDIUMTEXT` | 16 MB | Off-page | Large documents |
| `LONGTEXT` | 4 GB | Off-page | Huge content |

```sql
-- Good / Tốt: right-sized columns
email      VARCHAR(255) NOT NULL,   -- max real email is ~254 chars
country    CHAR(2)      NOT NULL,   -- always exactly 2 chars: 'VN', 'US'
uuid       CHAR(36)     NOT NULL,   -- UUIDs are always 36 chars
phone      VARCHAR(30)  NULL,       -- variable with country codes

-- Bad / Tệ: over-sized
description VARCHAR(10000)          -- use TEXT instead
tiny_code   VARCHAR(255)            -- if always 3 chars, use CHAR(3)
```

---

## Numeric Types / Kiểu Số

```sql
-- DECIMAL — exact precision, for money / DECIMAL — độ chính xác chính xác, cho tiền
price        DECIMAL(12, 2) NOT NULL,  -- 12 total digits, 2 decimal
tax_amount   DECIMAL(14, 4) NOT NULL,  -- more precision for tax calculations

-- FLOAT/DOUBLE — approximate, NOT for money / Xấp xỉ, KHÔNG dùng cho tiền
latitude     DOUBLE NOT NULL,          -- geographic coordinates OK
percentage   FLOAT,                    -- never use for financial data!

-- Money rule: store in smallest unit / Quy tắc tiền tệ: lưu đơn vị nhỏ nhất
-- Better: store VND as integers (no decimals in VND)
price_vnd    BIGINT UNSIGNED NOT NULL  -- 1500000 VND
```

---

## Date & Time Types / Kiểu Ngày Giờ

| Type | Storage | Range | Timezone | Use Case |
|------|---------|-------|----------|----------|
| `DATE` | 3 bytes | 1000–9999 | No | Birthdates, calendar dates |
| `DATETIME` | 5 bytes | 1000–9999 | **No** | Application timestamps |
| `TIMESTAMP` | 4 bytes | 1970–2038 | **Yes** (UTC) | System timestamps |
| `TIME` | 3 bytes | -838h to 838h | No | Duration |
| `YEAR` | 1 byte | 1901–2155 | No | Year only |

```sql
-- Best practice for audit columns / Thực hành tốt cho cột kiểm toán
created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
           ON UPDATE CURRENT_TIMESTAMP(3),

-- DATETIME(3) = millisecond precision / độ chính xác millisecond
-- Use DATETIME (not TIMESTAMP) to avoid 2038 problem
-- Dùng DATETIME (không phải TIMESTAMP) để tránh vấn đề năm 2038
```

---

## JSON Type / Kiểu JSON

```sql
-- Store flexible attributes / Lưu thuộc tính linh hoạt
attributes JSON NULL,

-- Insert / Chèn
INSERT INTO products (attributes)
VALUES ('{"color": "black", "ram": "12GB", "warranty_months": 12}');

-- Query JSON fields / Truy vấn trường JSON
SELECT
    id,
    attributes->>'$.color'    AS color,       -- ->> extracts as string
    attributes->>'$.ram'      AS ram,
    JSON_VALUE(attributes, '$.warranty_months') AS warranty
FROM products
WHERE attributes->>'$.color' = 'black';

-- Index a JSON field (generated column trick) / Đánh index trường JSON
ALTER TABLE products
    ADD COLUMN product_color VARCHAR(50)
    GENERATED ALWAYS AS (attributes->>'$.color') STORED,
    ADD INDEX idx_product_color (product_color);
```

---

## Type Selection Cheat Sheet / Bảng Chọn Nhanh

```
Primary Key ID      → BIGINT UNSIGNED AUTO_INCREMENT
UUID                → CHAR(36)
Boolean             → TINYINT(1) / BOOLEAN
Money (VND)         → DECIMAL(14,2) or BIGINT
Email               → VARCHAR(255)
Phone               → VARCHAR(30)
Status/Enum         → ENUM('val1','val2') or TINYINT
Timestamp           → DATETIME(3)
Free-form text      → TEXT
Flexible attributes → JSON
```

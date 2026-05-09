# UUID v7 vs AUTO_INCREMENT / UUID v7 vs AUTO_INCREMENT

## Overview / Tổng Quan

Choosing your primary key strategy is one of the most consequential schema design decisions. It affects **storage size**, **index performance**, **distributed scalability**, and **security**.
_Chọn chiến lược khóa chính là một trong những quyết định thiết kế schema quan trọng nhất. Nó ảnh hưởng đến **kích thước lưu trữ**, **hiệu năng chỉ mục**, **khả năng mở rộng phân tán** và **bảo mật**._

---

## AUTO_INCREMENT (BIGINT) — The Classic

```sql
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    PRIMARY KEY (id)
);
```

### Pros / Ưu điểm
- **Sequential inserts** → minimal B+ tree page splits / Chèn tuần tự → ít phân tách trang B+
- **Compact**: 8 bytes vs 16 bytes UUID / Nhỏ gọn: 8 byte vs 16 byte UUID
- **Readable** for debugging, support tickets / Dễ đọc để gỡ lỗi
- **Fast joins** on integer keys / Join nhanh trên khóa số nguyên

### Cons / Nhược điểm
- **Predictable/guessable** — security risk for URLs like `/orders/1001` / Có thể đoán được — rủi ro bảo mật
- **Single point of generation** — hard to distribute / Điểm tạo đơn — khó phân tán
- **Cross-system merges** are painful (ID collisions) / Gộp đa hệ thống khó (va chạm ID)

---

## UUID v4 — Universally Unique, Poor Performance

```sql
CREATE TABLE orders (
    id   CHAR(36) NOT NULL DEFAULT (UUID()),  -- '550e8400-e29b-41d4-a716-446655440000'
    PRIMARY KEY (id)
);
```

### Problem: Random inserts cause B+ tree page splits
_Vấn đề: Chèn ngẫu nhiên gây phân tách trang B+_

```
B+ Tree with sequential IDs / B+ Tree với ID tuần tự:
[1][2][3][4] → always appends to rightmost leaf
              → luôn chèn vào lá ngoài cùng bên phải

B+ Tree with random UUIDs / B+ Tree với UUID ngẫu nhiên:
[a3b][c12][e99] → random insertion causes page splits everywhere
                 → chèn ngẫu nhiên gây phân tách trang khắp nơi
```

**Impact**: 30-50% worse write performance on large tables.
_**Tác động**: Hiệu năng ghi tệ hơn 30-50% trên bảng lớn._

---

## UUID v7 — Best of Both Worlds

UUID v7 is **time-ordered** (first 48 bits = Unix timestamp milliseconds).
_UUID v7 có **thứ tự thời gian** (48 bit đầu = Unix timestamp milliseconds)._

```
UUID v7 format:
xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
│               │         │
│               │         └── random bits
│               └── version = 7
└── 48-bit Unix timestamp ms (time-ordered!)
    Timestamp ms 48-bit — có thứ tự thời gian!
```

```sql
-- MySQL 8.0 doesn't have native UUID v7 yet
-- MySQL 8.0 chưa có UUID v7 native
-- Use a function / Dùng một hàm:

DELIMITER $$
CREATE FUNCTION uuid_v7() RETURNS BINARY(16)
BEGIN
    -- Generate time-ordered UUID v7 / Tạo UUID v7 có thứ tự thời gian
    DECLARE unix_ms BIGINT DEFAULT UNIX_TIMESTAMP(NOW(3)) * 1000;
    RETURN UNHEX(CONCAT(
        LPAD(HEX(unix_ms), 12, '0'),    -- 48-bit timestamp
        '7',                              -- version
        LPAD(HEX(FLOOR(RAND() * 0xFFF)), 3, '0'),
        HEX(0x8000 | FLOOR(RAND() * 0x3FFF)),
        LPAD(HEX(FLOOR(RAND() * 0xFFFFFFFFFFFF)), 12, '0')
    ));
END$$
DELIMITER ;
```

---

## Practical Strategy / Chiến Lược Thực Tế

```sql
CREATE TABLE orders (
    -- Surrogate PK for internal JOINs / Khóa thay thế cho JOIN nội bộ
    id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    -- UUID for external exposure (API, URLs) / UUID cho bên ngoài (API, URL)
    uuid CHAR(36)        NOT NULL DEFAULT (UUID()),
    
    PRIMARY KEY (id),
    UNIQUE KEY uq_orders_uuid (uuid)   -- Enforce uniqueness / Đảm bảo duy nhất
);
```

**Rule of thumb / Quy tắc kinh nghiệm**:
- Use `BIGINT AUTO_INCREMENT` as the **internal** PK for joins
- Use `UUID` (v4 or v7) as the **external** identifier in APIs

---

## Comparison Table / Bảng So Sánh

| Property | AUTO_INCREMENT | UUID v4 | UUID v7 |
|----------|---------------|---------|---------|
| Storage (bytes) | 8 | 16–36 | 16 |
| Insert performance | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| Globally unique | ❌ | ✅ | ✅ |
| Time-ordered | ✅ | ❌ | ✅ |
| Guessable | ✅ (security risk) | ❌ | ❌ |
| Cross-DB merge | ❌ | ✅ | ✅ |
| MySQL native | ✅ | ✅ (8.0) | ⚠️ (function) |

---

## Recommendation / Khuyến Nghị

```
Single MySQL server → BIGINT AUTO_INCREMENT (internal) + UUID v4 (external)
Distributed / sharded → UUID v7 as primary key
Microservices with cross-service references → UUID v7
```

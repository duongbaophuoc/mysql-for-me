# Normalization / Chuẩn Hóa

## Overview / Tổng Quan

Normalization is the process of structuring a relational database to reduce redundancy and improve data integrity.
_Chuẩn hóa là quá trình cấu trúc hóa CSDL quan hệ để giảm dư thừa và cải thiện tính toàn vẹn dữ liệu._

**The goal**: Each piece of data is stored in exactly one place.
_**Mục tiêu**: Mỗi dữ liệu được lưu trữ đúng một nơi._

---

## First Normal Form (1NF) / Dạng Chuẩn 1

**Rule**: Each column must contain atomic (indivisible) values. No repeating groups.
_**Quy tắc**: Mỗi cột phải chứa giá trị nguyên tử (không thể chia). Không có nhóm lặp._

### Violation / Vi Phạm

```sql
-- BAD: phone_numbers is not atomic / Tệ: phone_numbers không nguyên tử
CREATE TABLE customers_bad (
    id           INT,
    name         VARCHAR(100),
    phone_numbers VARCHAR(200)   -- '0901234567,0912345678'
);
```

### Fix / Sửa

```sql
-- GOOD: separate table for phone numbers / Tốt: bảng riêng cho số điện thoại
CREATE TABLE customer_phones (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id INT UNSIGNED NOT NULL,
    phone       VARCHAR(30)  NOT NULL,
    type        ENUM('mobile','home','work') DEFAULT 'mobile',
    PRIMARY KEY (id),
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);
```

---

## Second Normal Form (2NF) / Dạng Chuẩn 2

**Rule**: Must be in 1NF. Every non-key column must depend on the **entire** primary key (no partial dependencies).
_**Quy tắc**: Phải ở 1NF. Mọi cột không phải khóa phải phụ thuộc vào **toàn bộ** khóa chính._

> Only relevant when primary key is composite.
> _Chỉ liên quan khi khóa chính là tổng hợp._

### Violation / Vi Phạm

```sql
-- BAD: product_name depends only on product_id, not on (order_id, product_id)
-- Tệ: product_name chỉ phụ thuộc product_id, không phải cả (order_id, product_id)
CREATE TABLE order_products_bad (
    order_id     INT UNSIGNED,
    product_id   INT UNSIGNED,
    product_name VARCHAR(200),   -- partial dependency! / phụ thuộc một phần!
    quantity     INT,
    PRIMARY KEY (order_id, product_id)
);
```

### Fix / Sửa

```sql
-- GOOD: product_name belongs in products table / Tốt: đặt product_name vào bảng products
CREATE TABLE order_items (
    order_id   INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    quantity   INT          NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,  -- snapshot at order time
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

---

## Third Normal Form (3NF) / Dạng Chuẩn 3

**Rule**: Must be in 2NF. No transitive dependencies — non-key columns must not depend on other non-key columns.
_**Quy tắc**: Phải ở 2NF. Không phụ thuộc bắc cầu — cột không phải khóa không được phụ thuộc cột không phải khóa khác._

### Violation / Vi Phạm

```sql
-- BAD: city depends on zip_code, not directly on customer_id
-- Tệ: city phụ thuộc zip_code, không trực tiếp vào customer_id
CREATE TABLE customers_bad (
    id       INT UNSIGNED,
    name     VARCHAR(100),
    zip_code VARCHAR(10),
    city     VARCHAR(100),   -- transitive: depends on zip_code / phụ thuộc bắc cầu
    country  VARCHAR(50)     -- transitive: depends on zip_code
);
```

### Fix / Sửa

```sql
-- GOOD: extract zip codes to a reference table / Tốt: tách mã zip ra bảng tham chiếu
CREATE TABLE zip_codes (
    zip_code VARCHAR(10)  NOT NULL,
    city     VARCHAR(100) NOT NULL,
    province VARCHAR(100),
    country  CHAR(2)      NOT NULL,
    PRIMARY KEY (zip_code)
);

CREATE TABLE customers (
    id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name     VARCHAR(100) NOT NULL,
    zip_code VARCHAR(10),
    PRIMARY KEY (id),
    FOREIGN KEY (zip_code) REFERENCES zip_codes(zip_code)
);
```

---

## Normalization Cheat Sheet / Bảng Tóm Tắt Chuẩn Hóa

| Normal Form | Rule Summary | Fixes |
|-------------|--------------|-------|
| **1NF** | Atomic values, no repeating groups | Split multi-value columns |
| **2NF** | No partial dependencies on composite PK | Move partial deps to their own table |
| **3NF** | No transitive dependencies | Extract reference tables |
| **BCNF** | Every determinant is a candidate key | Rare in practice |

---

## Real-World Example: shop_db / Ví Dụ Thực Tế: shop_db

```sql
-- Does shop_db orders table satisfy 3NF? / Bảng orders có thỏa 3NF không?
-- ✅ Yes because:
--   - customer_id → customer data (in customers table)
--   - shipping_address stored as address_id → reference to customer_addresses
--   - total_amount is a derived sum stored for performance (acceptable denorm)
```

---

## When to Stop Normalizing / Khi Nào Nên Dừng Chuẩn Hóa

- 3NF is sufficient for most OLTP applications.
- _3NF là đủ cho hầu hết ứng dụng OLTP._
- Over-normalization creates excessive JOINs that hurt read performance.
- _Chuẩn hóa quá mức tạo ra JOIN quá nhiều làm giảm hiệu năng đọc._
- For OLAP/warehouses, denormalization is intentional (Stage 0 → Stage 6).
- _Đối với OLAP/kho dữ liệu, phi chuẩn hóa là cố ý._

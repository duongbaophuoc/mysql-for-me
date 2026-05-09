# Multi-Tenant Database Design / Thiết Kế CSDL Đa Tenant

## Overview / Tổng Quan

Multi-tenancy means a single application serves multiple customers (tenants), each with isolated data.
_Đa tenant nghĩa là một ứng dụng phục vụ nhiều khách hàng (tenant), mỗi tenant có dữ liệu riêng biệt._

---

## Strategy 1: Shared Database, Shared Tables / CSDL Chung, Bảng Chung

Add `tenant_id` to every table:
_Thêm `tenant_id` vào mọi bảng:_

```sql
CREATE TABLE orders (
    id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    tenant_id INT UNSIGNED    NOT NULL,   -- ← tenant discriminator
    customer_id BIGINT UNSIGNED NOT NULL,
    total_amount DECIMAL(14,2) NOT NULL,
    PRIMARY KEY (id),
    KEY idx_tenant_orders (tenant_id, id)   -- every query filtered by tenant
);

-- Every query MUST include tenant_id / Mọi truy vấn PHẢI bao gồm tenant_id
SELECT * FROM orders WHERE tenant_id = :tenant AND status = 'pending';
```

### Pros / Ưu điểm
- Simplest to operate / Đơn giản nhất để vận hành
- Best hardware utilization / Sử dụng phần cứng tốt nhất
- Single schema to manage / Một schema để quản lý

### Cons / Nhược điểm
- Risk of cross-tenant data leak if `tenant_id` filter forgotten / Rủi ro rò rỉ dữ liệu
- One bad tenant can impact all (noisy neighbor) / Một tenant xấu ảnh hưởng tất cả
- Compliance harder (GDPR delete = delete rows, not drop DB) / Tuân thủ khó hơn

---

## Strategy 2: Shared Database, Separate Schemas / CSDL Chung, Schema Riêng

Each tenant gets their own MySQL schema (database):
_Mỗi tenant có MySQL schema (database) riêng:_

```sql
-- Tenant A / Tenant A
CREATE DATABASE tenant_acme;
CREATE TABLE tenant_acme.orders (...);

-- Tenant B / Tenant B
CREATE DATABASE tenant_betacorp;
CREATE TABLE tenant_betacorp.orders (...);

-- Application connects to the right schema per request
-- Ứng dụng kết nối đến schema đúng cho mỗi request
USE tenant_acme;
SELECT * FROM orders;   -- no tenant_id needed!
```

### When to Use / Khi Nào Dùng
- Compliance requirements (data isolation) / Yêu cầu tuân thủ (cô lập dữ liệu)
- Per-tenant customization needed / Cần tùy chỉnh theo tenant
- < 1000 tenants (schema proliferation becomes unmanageable) / < 1000 tenant

---

## Strategy 3: Separate Databases / CSDL Riêng Biệt

Each tenant gets their own MySQL instance/server:
_Mỗi tenant có MySQL instance/server riêng:_

```
Tenant A → MySQL instance A (dedicated hardware)
Tenant B → MySQL instance B
Tenant C → MySQL instance C
```

### When to Use / Khi Nào Dùng
- Enterprise SaaS with strict SLAs / SaaS doanh nghiệp với SLA nghiêm ngặt
- Tenants with very high volume / Tenant có lượng truy cập rất cao
- Regulatory isolation required / Yêu cầu cô lập theo quy định

---

## Comparison / So Sánh

| Aspect | Shared Tables | Shared DB, Separate Schemas | Separate DBs |
|--------|--------------|---------------------------|-------------|
| Tenant count | Unlimited | < 1000 | < 100 |
| Data isolation | Low | Medium | High |
| Operational cost | Low | Medium | High |
| Customization | Hard | Medium | Easy |
| GDPR delete | Complex | Easy (drop rows) | Easy (drop DB) |
| Best for | SMB SaaS | Mid-market SaaS | Enterprise |

---

## Implementation: Shared Tables with Row-Level Security
## Triển Khai: Bảng Chung Với Bảo Mật Cấp Hàng

```sql
-- Enforce tenant isolation at application level / Bắt buộc cô lập tenant ở tầng ứng dụng

-- Step 1: Create a tenants lookup / Tạo bảng tra cứu tenant
CREATE TABLE tenants (
    id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    slug     VARCHAR(100) NOT NULL,
    plan     ENUM('free','pro','enterprise') NOT NULL DEFAULT 'free',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    UNIQUE KEY uq_tenant_slug (slug)
);

-- Step 2: Every table has tenant_id as first key component
-- Mọi bảng có tenant_id làm thành phần đầu tiên của key
CREATE TABLE products (
    id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    tenant_id INT UNSIGNED    NOT NULL,
    name      VARCHAR(255)    NOT NULL,
    PRIMARY KEY (id),
    KEY idx_tenant_products (tenant_id, name)   -- tenant prefix on every index!
);

-- Step 3: Application middleware injects tenant_id
-- Middleware ứng dụng tự động chèn tenant_id
-- Never trust client-provided tenant_id
-- Không bao giờ tin tenant_id do client cung cấp
```

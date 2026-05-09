# 🟢 Stage 0 — Data Modeling & Database Architecture
# 🟢 Giai Đoạn 0 — Mô Hình Hóa Dữ Liệu & Kiến Trúc Cơ Sở Dữ Liệu

> **"Most production incidents begin with bad schema design."**
> _"Hầu hết sự cố production bắt đầu từ thiết kế schema tệ."_

## Overview / Tổng Quan

Before writing a single line of SQL, you must understand how to model data for real-world systems.
_Trước khi viết một dòng SQL nào, bạn phải hiểu cách mô hình hóa dữ liệu cho hệ thống thực tế._

This stage covers the foundations of relational database design, from ERD diagrams to multi-tenant architectures.
_Giai đoạn này bao gồm nền tảng thiết kế CSDL quan hệ, từ sơ đồ ERD đến kiến trúc đa tenant._

## Topics / Chủ Đề

| File | Topic | Level |
|------|-------|-------|
| [01-erd-design.md](01-erd-design.md) | ERD Design | Beginner |
| [02-normalization.md](02-normalization.md) | Normalization 1NF→3NF | Beginner |
| [03-denormalization.md](03-denormalization.md) | Denormalization strategies | Intermediate |
| [04-oltp-vs-olap.md](04-oltp-vs-olap.md) | OLTP vs OLAP modeling | Intermediate |
| [05-star-snowflake-schema.md](05-star-snowflake-schema.md) | Star & Snowflake schemas | Intermediate |
| [06-scd.md](06-scd.md) | Slowly Changing Dimensions | Intermediate |
| [07-keys-uuid-vs-autoincrement.md](07-keys-uuid-vs-autoincrement.md) | UUID v7 vs AUTO_INCREMENT | Advanced |
| [08-hierarchical-data.md](08-hierarchical-data.md) | Trees, nested sets | Intermediate |
| [09-audit-columns-soft-delete.md](09-audit-columns-soft-delete.md) | Audit & soft delete patterns | Intermediate |
| [10-multi-tenant-design.md](10-multi-tenant-design.md) | Multi-tenant architecture | Advanced |

## Learning Outcomes / Kết Quả Học Tập

After completing this stage, you will be able to:
_Sau khi hoàn thành giai đoạn này, bạn sẽ có thể:_

- ✅ Design normalized schemas up to 3NF
- ✅ Understand when and why to denormalize
- ✅ Model OLTP and OLAP databases differently
- ✅ Choose appropriate key strategies (UUID vs AUTO_INCREMENT)
- ✅ Implement audit trails and soft-delete patterns
- ✅ Design multi-tenant schemas for SaaS products

## Key Concepts / Khái Niệm Chính

```
Entity Relationship Diagram (ERD)
  ├── Entities → Tables / Thực thể → Bảng
  ├── Attributes → Columns / Thuộc tính → Cột
  └── Relationships → Foreign Keys / Quan hệ → Khóa ngoại
      ├── 1:1  (One-to-One)
      ├── 1:N  (One-to-Many) ← most common / phổ biến nhất
      └── M:N  (Many-to-Many → junction table)

Normalization / Chuẩn hóa
  ├── 1NF: Atomic values, no repeating groups
  ├── 2NF: No partial dependencies (composite PK)
  └── 3NF: No transitive dependencies
```

## Prerequisite / Điều Kiện Tiên Quyết

No prior MySQL knowledge required, but understanding of basic data concepts helps.
_Không cần kiến thức MySQL trước đó, nhưng hiểu biết về khái niệm dữ liệu cơ bản sẽ giúp ích._

## Next Stage / Giai Đoạn Tiếp Theo

→ [Stage 1 — MySQL Fundamentals](../stage-1-mysql-fundamentals/README.md)

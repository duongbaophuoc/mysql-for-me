# 🟢 Stage 1 — MySQL Fundamentals
# 🟢 Giai Đoạn 1 — Nền Tảng MySQL

> **"You cannot optimize what you don't understand."**
> _"Bạn không thể tối ưu điều bạn không hiểu."_

## Overview / Tổng Quan

This stage builds your MySQL foundation — from setting up a development environment to understanding storage engines and writing production-quality SQL.
_Giai đoạn này xây dựng nền tảng MySQL của bạn — từ thiết lập môi trường phát triển đến hiểu storage engine và viết SQL chất lượng production._

## Topics / Chủ Đề

| File | Topic | Level |
|------|-------|-------|
| [01-environment-setup.md](01-environment-setup.md) | Docker + MySQL Shell + DBeaver | Beginner |
| [02-data-types.md](02-data-types.md) | INT, BIGINT, VARCHAR, JSON, DATETIME | Beginner |
| [03-ddl-dml.md](03-ddl-dml.md) | CREATE, ALTER, DROP, CRUD | Beginner |
| [04-joins.md](04-joins.md) | INNER, LEFT, RIGHT, CROSS, SELF | Beginner |
| [05-aggregation-window-functions.md](05-aggregation-window-functions.md) | GROUP BY, HAVING, Window Functions | Intermediate |
| [06-ctes-recursive.md](06-ctes-recursive.md) | CTEs, Recursive CTEs | Intermediate |
| [07-views.md](07-views.md) | Views, updatable views | Intermediate |
| [08-stored-procedures-triggers.md](08-stored-procedures-triggers.md) | SP, Functions, Triggers | Intermediate |
| [09-storage-engines.md](09-storage-engines.md) | InnoDB, MyISAM, MEMORY, ARCHIVE | Intermediate |

## Learning Outcomes / Kết Quả Học Tập

- ✅ Set up a complete local MySQL development environment
- ✅ Understand MySQL data types and their storage implications
- ✅ Write complex queries with JOINs, aggregations, and window functions
- ✅ Use CTEs for readable, recursive queries
- ✅ Understand storage engine trade-offs (InnoDB vs MyISAM)
- ✅ Write stored procedures, functions, and triggers

## Quick Environment Setup / Thiết Lập Môi Trường Nhanh

```bash
# Start MySQL via Docker / Khởi động MySQL qua Docker
docker compose -f ../../docker/docker-compose.yml up -d

# Verify / Kiểm tra
docker exec -it mysql-primary mysql -u root -psecret -e "SELECT VERSION();"

# Connect with MySQL Shell / Kết nối MySQL Shell
mysqlsh root:secret@localhost:3306

# Load sample database / Nạp CSDL mẫu
mysql -h 127.0.0.1 -P 3306 -u root -psecret < ../../sample-db/shop_db/schema.sql
mysql -h 127.0.0.1 -P 3306 -u root -psecret < ../../sample-db/shop_db/seed.sql
```

## Next Stage / Giai Đoạn Tiếp Theo

→ [Stage 2 — Backend Integration](../stage-2-backend-integration/README.md)

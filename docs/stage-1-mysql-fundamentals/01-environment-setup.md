# Environment Setup / Thiết Lập Môi Trường

## Overview / Tổng Quan

A proper local development environment is the foundation for all MySQL learning.
_Môi trường phát triển cục bộ thích hợp là nền tảng cho tất cả việc học MySQL._

We use Docker for MySQL — no local installation needed, version-controlled, reproducible.
_Chúng ta dùng Docker cho MySQL — không cần cài đặt cục bộ, kiểm soát phiên bản, có thể tái tạo._

---

## Prerequisites / Điều Kiện Tiên Quyết

- Docker Desktop 4.x+ (Windows/Mac) or Docker Engine (Linux)
- MySQL Shell (`mysqlsh`)
- DBeaver Community Edition (optional GUI)

---

## 1. Start MySQL with Docker / Khởi Động MySQL Với Docker

```bash
# Start full dev stack (MySQL + ProxySQL + Adminer) / Khởi động stack dev đầy đủ
docker compose -f docker/docker-compose.yml up -d

# Verify MySQL is running / Xác minh MySQL đang chạy
docker ps | grep mysql

# Check MySQL logs / Xem log MySQL
docker logs mysql-primary --tail 50

# Wait for healthy status / Chờ trạng thái healthy
docker inspect mysql-primary | grep Health -A 5
```

### Manual single container / Container đơn thủ công

```bash
docker run --name mysql-dev \
  -e MYSQL_ROOT_PASSWORD=secret \
  -e MYSQL_DATABASE=shop_db \
  -p 3306:3306 \
  -v mysql_data:/var/lib/mysql \
  -d mysql:8.0 \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci
```

---

## 2. Connect to MySQL / Kết Nối MySQL

### Via mysql CLI / Qua mysql CLI

```bash
# Basic connection / Kết nối cơ bản
mysql -h 127.0.0.1 -P 3306 -u root -psecret

# Execute a file / Thực thi file
mysql -h 127.0.0.1 -P 3306 -u root -psecret < sample-db/shop_db/schema.sql

# Execute a command / Thực thi lệnh
mysql -h 127.0.0.1 -P 3306 -u root -psecret -e "SHOW DATABASES;"
```

### Via MySQL Shell / Qua MySQL Shell

```bash
# Install MySQL Shell / Cài đặt MySQL Shell
# https://dev.mysql.com/downloads/shell/

mysqlsh root:secret@localhost:3306

# Switch to SQL mode / Chuyển sang chế độ SQL
\sql

# Run a query / Chạy truy vấn
SELECT VERSION();

# Switch to Python / Chuyển sang Python
\py
session.run_sql("SELECT COUNT(*) FROM shop_db.orders")
```

### Inside Docker / Bên Trong Docker

```bash
docker exec -it mysql-primary mysql -u root -psecret
```

---

## 3. Load Sample Databases / Nạp CSDL Mẫu

```bash
# Load shop_db schema / Nạp schema shop_db
mysql -h 127.0.0.1 -P 3306 -u root -psecret \
  < sample-db/shop_db/schema.sql

# Load seed data / Nạp dữ liệu mẫu
mysql -h 127.0.0.1 -P 3306 -u root -psecret \
  < sample-db/shop_db/seed.sql

# Load analytics warehouse / Nạp kho dữ liệu phân tích
mysql -h 127.0.0.1 -P 3306 -u root -psecret \
  < sample-db/analytics_dw/schema.sql

# Verify / Xác minh
mysql -h 127.0.0.1 -P 3306 -u root -psecret -e "
  USE shop_db;
  SELECT 'customers' AS tbl, COUNT(*) FROM customers
  UNION ALL
  SELECT 'orders', COUNT(*) FROM orders
  UNION ALL
  SELECT 'products', COUNT(*) FROM products;
"
```

---

## 4. DBeaver Setup / Cài Đặt DBeaver

DBeaver is a free universal DB GUI — excellent for exploring schemas and running queries.
_DBeaver là GUI CSDL đa năng miễn phí — tuyệt vời để khám phá schema và chạy truy vấn._

```
1. Download DBeaver Community: https://dbeaver.io/download/
2. New Connection → MySQL
   Host: 127.0.0.1
   Port: 3306
   Database: shop_db
   Username: root
   Password: secret
3. Test Connection → OK → Finish
```

---

## 5. Useful MySQL CLI Commands / Lệnh MySQL CLI Hữu Ích

```sql
-- Show databases / Hiển thị CSDL
SHOW DATABASES;

-- Switch database / Chuyển CSDL
USE shop_db;

-- Show tables / Hiển thị bảng
SHOW TABLES;

-- Describe table structure / Mô tả cấu trúc bảng
DESCRIBE orders;
-- or / hoặc
SHOW CREATE TABLE orders\G

-- Show server status / Hiển thị trạng thái server
SHOW STATUS LIKE 'Threads%';
SHOW VARIABLES LIKE 'innodb_buffer%';

-- Show running queries / Hiển thị truy vấn đang chạy
SHOW PROCESSLIST;

-- Show InnoDB engine status / Hiển thị trạng thái InnoDB
SHOW ENGINE INNODB STATUS\G
```

---

## 6. my.cnf Key Settings Reference / Tham Chiếu Cài Đặt my.cnf

```ini
[mysqld]
# Performance / Hiệu năng
innodb_buffer_pool_size = 512M    # 50-70% RAM in production / 50-70% RAM production
innodb_log_file_size    = 128M    # Larger = fewer checkpoints / Lớn hơn = ít checkpoint

# Logging / Ghi nhật ký
slow_query_log       = ON
long_query_time      = 1          # Log queries > 1 second / Log truy vấn > 1 giây

# Replication / Sao chép
log-bin              = mysql-bin  # Enable binary log / Bật binary log
gtid_mode            = ON
server-id            = 1
```

---

## Cheat Sheet / Bảng Tham Chiếu Nhanh

| Task | Command |
|------|---------|
| Start / Khởi động | `docker compose up -d` |
| Stop / Dừng | `docker compose down` |
| Connect / Kết nối | `mysql -h 127.0.0.1 -P 3306 -u root -psecret` |
| Load SQL file | `mysql ... < file.sql` |
| Check status | `docker ps` |
| View logs | `docker logs mysql-primary` |
| Shell into container | `docker exec -it mysql-primary bash` |

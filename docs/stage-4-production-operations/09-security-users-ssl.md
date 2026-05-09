# Security: Users, Privileges & SSL / Bảo Mật: Users, Quyền & SSL

## Overview / Tổng Quan

MySQL security operates at multiple layers: **network**, **authentication**, and **authorization**.
_Bảo mật MySQL hoạt động ở nhiều tầng: **mạng**, **xác thực**, và **phân quyền**._

---

## User Management / Quản Lý User

```sql
-- Create a least-privilege application user / Tạo user ứng dụng quyền tối thiểu
CREATE USER 'app_user'@'10.0.0.%'          -- only from app server subnet
    IDENTIFIED BY 'strong_password_here'
    PASSWORD EXPIRE INTERVAL 90 DAY
    FAILED_LOGIN_ATTEMPTS 5
    PASSWORD_LOCK_TIME 2;                   -- lock 2 days after 5 failed attempts

-- Grant minimal privileges / Cấp quyền tối thiểu
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_db.* TO 'app_user'@'10.0.0.%';
-- NOT GRANT ALL! / KHÔNG CẤP TẤT CẢ!

-- Separate read-only user for reporting / User chỉ đọc cho báo cáo
CREATE USER 'report_user'@'%' IDENTIFIED BY 'password';
GRANT SELECT ON shop_db.* TO 'report_user'@'%';

-- Replication user / User sao chép
CREATE USER 'replicator'@'%' IDENTIFIED WITH mysql_native_password BY 'repl_pass';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';

FLUSH PRIVILEGES;
```

---

## Column-Level Privileges / Quyền Cấp Cột

```sql
-- Hide sensitive columns / Ẩn cột nhạy cảm
CREATE USER 'limited_user'@'%' IDENTIFIED BY 'pass';

GRANT SELECT (id, uuid, email, full_name, status, created_at)
    ON shop_db.customers TO 'limited_user'@'%';
-- No access to: phone, date_of_birth, personal data
-- Không truy cập: phone, date_of_birth, dữ liệu cá nhân

-- Or use a VIEW to hide columns / Hoặc dùng VIEW để ẩn cột
CREATE VIEW v_customers_safe AS
    SELECT id, uuid, email, full_name, status FROM customers;
GRANT SELECT ON shop_db.v_customers_safe TO 'limited_user'@'%';
```

---

## Auditing User Activity / Kiểm Toán Hoạt Động User

```sql
-- Check all user grants / Kiểm tra quyền tất cả user
SELECT user, host, authentication_string IS NOT NULL AS has_password
FROM mysql.user;

-- Show grants for a specific user / Hiển thị quyền user cụ thể
SHOW GRANTS FOR 'app_user'@'10.0.0.%';

-- Find users with dangerous privileges / Tìm user có quyền nguy hiểm
SELECT user, host, Super_priv, Grant_priv, File_priv
FROM mysql.user
WHERE Super_priv = 'Y' OR Grant_priv = 'Y';
```

---

## SSL/TLS Configuration / Cấu Hình SSL/TLS

```ini
[mysqld]
# Enable SSL / Bật SSL
ssl-ca   = /etc/mysql/ssl/ca.pem
ssl-cert = /etc/mysql/ssl/server-cert.pem
ssl-key  = /etc/mysql/ssl/server-key.pem
require_secure_transport = ON   # Force all connections to use SSL
```

```sql
-- Require SSL for a user / Yêu cầu SSL cho user
ALTER USER 'app_user'@'%' REQUIRE SSL;

-- Verify SSL connection / Xác minh kết nối SSL
SHOW STATUS LIKE 'Ssl_cipher';
-- Ssl_cipher: TLS_AES_256_GCM_SHA384  ← encrypted! / đã mã hóa!

-- Create SSL certificates (dev) / Tạo chứng chỉ SSL (dev)
-- mysql_ssl_rsa_setup --datadir=/var/lib/mysql
```

---

## Security Checklist / Danh Sách Kiểm Tra Bảo Mật

```
□ Root account has no remote login / Root không có đăng nhập từ xa
□ All users have strong passwords / Tất cả user có mật khẩu mạnh
□ Application user has least privilege / User ứng dụng có quyền tối thiểu
□ MySQL port (3306) not exposed to internet / Không mở cổng 3306 ra internet
□ SSL enabled for all connections / SSL bật cho tất cả kết nối
□ No anonymous users / Không có user ẩn danh
□ Audit logging enabled / Ghi log kiểm toán bật
□ Regular privilege review / Kiểm tra quyền định kỳ

-- Check for anonymous users / Kiểm tra user ẩn danh
SELECT user, host FROM mysql.user WHERE user = '';
-- Should return empty! / Phải trả về rỗng!

-- Remove anonymous users / Xóa user ẩn danh
DELETE FROM mysql.user WHERE user = '';
FLUSH PRIVILEGES;
```

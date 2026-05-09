# Backup Strategies: mysqldump & XtraBackup
# Chiến Lược Backup: mysqldump & XtraBackup

## Overview / Tổng Quan

Every production database needs a tested, automated backup strategy.
_Mọi CSDL production cần chiến lược backup tự động và đã được kiểm thử._

**No backup = no recovery. An untested backup = no backup.**
_Không backup = không khôi phục. Backup chưa kiểm thử = không có backup._

---

## mysqldump — Logical Backup

Creates SQL text that recreates the database.
_Tạo SQL text để tái tạo lại CSDL._

```bash
# Full dump with all options / Dump đầy đủ với mọi tùy chọn
mysqldump \
  --host=localhost \
  --user=root \
  --password=secret \
  --all-databases \                # All schemas / Tất cả schema
  --single-transaction \           # Consistent snapshot without lock / Snapshot nhất quán không lock
  --master-data=2 \                # Record binlog position / Ghi vị trí binlog
  --flush-logs \                   # Rotate binlog after lock / Xoay binlog
  --routines \                     # Include stored procedures / Bao gồm SP
  --triggers \                     # Include triggers / Bao gồm trigger
  --events \                       # Include events / Bao gồm event
  > /backups/full_$(date +%Y%m%d).sql

# Compress / Nén
mysqldump ... | gzip > /backups/full_$(date +%Y%m%d).sql.gz

# Restore / Khôi phục
mysql -u root -psecret < /backups/full_20241215.sql
# or / hoặc
zcat /backups/full_20241215.sql.gz | mysql -u root -psecret
```

### mysqldump Limitations / Hạn Chế

| Limitation | Issue |
|------------|-------|
| Slow restore | Large databases take hours to restore |
| Not incremental | Full dump required each time |
| No point-in-time granularity | Must combine with binlogs |
| Holds metadata lock briefly | Even with --single-transaction |

---

## XtraBackup — Physical Hot Backup

Percona XtraBackup copies InnoDB `.ibd` files without locking the database.
_Percona XtraBackup sao chép file `.ibd` InnoDB mà không lock CSDL._

```bash
# Install / Cài đặt
apt-get install percona-xtrabackup-80

# Full backup / Backup đầy đủ
xtrabackup \
  --backup \
  --user=root \
  --password=secret \
  --target-dir=/backups/xb_$(date +%Y%m%d) \
  --parallel=4 \
  --compress \
  --compress-threads=4

# Incremental backup (since last full) / Backup gia tăng
xtrabackup \
  --backup \
  --target-dir=/backups/xb_incr_$(date +%Y%m%d_%H) \
  --incremental-basedir=/backups/xb_$(date +%Y%m%d)

# Prepare full backup / Chuẩn bị backup đầy đủ
xtrabackup --prepare \
  --target-dir=/backups/xb_20241215

# Apply incremental / Áp dụng gia tăng
xtrabackup --prepare \
  --target-dir=/backups/xb_20241215 \
  --incremental-dir=/backups/xb_incr_20241215_02

# Restore / Khôi phục (stop MySQL first!)
xtrabackup --copy-back --target-dir=/backups/xb_20241215
chown -R mysql:mysql /var/lib/mysql
```

---

## Comparison / So Sánh

| Aspect | mysqldump | XtraBackup |
|--------|-----------|-----------|
| Type | Logical (SQL) | Physical (files) |
| Hot backup | ✅ (--single-transaction) | ✅ |
| Speed (backup) | Slow | Fast |
| Speed (restore) | Very slow | Fast |
| Incremental | ❌ | ✅ |
| Compression | ✅ | ✅ |
| Cross-version restore | ✅ | Limited |
| Best for | Small DBs, portability | Production, large DBs |

---

## Backup Schedule Recommendation / Lịch Backup Khuyến Nghị

```
Daily full backup (XtraBackup) — 2:00 AM
Hourly incremental (XtraBackup) — :00 every hour
Binary logs retained — 7 days (continuous shipping to S3)
Test restore — Weekly
```

# Disaster Recovery / Khôi Phục Thảm Họa

## Overview / Tổng Quan

Disaster recovery (DR) covers scenarios where entire data centers fail, data is corrupted, or both primary and replica are lost.
_Khôi phục thảm họa bao gồm các tình huống toàn bộ trung tâm dữ liệu thất bại, dữ liệu bị hỏng, hoặc cả primary và replica đều mất._

---

## DR Plan Components / Thành Phần Kế Hoạch DR

```
RPO = 1 hour  → Backups every hour, binlog shipped every 1 min
RTO = 30 min  → Automated restore from backup + binlog replay

RTO 30 phút = Restore tự động từ backup + phát lại binlog
RPO 1 giờ   = Backup mỗi giờ, vận chuyển binlog mỗi 1 phút
```

---

## Backup Storage Strategy / Chiến Lược Lưu Trữ Backup

```bash
# Rule: Follow 3-2-1 backup rule / Quy tắc: Tuân theo quy tắc 3-2-1
# 3 copies / 3 bản sao
# 2 different media / 2 phương tiện khác nhau
# 1 offsite / 1 nơi khác

# Copy backups to S3 / Sao lưu lên S3
aws s3 cp /backups/xb_$(date +%Y%m%d).tar.gz \
    s3://company-mysql-backups/$(date +%Y/%m/%d)/

# Ship binary logs continuously / Vận chuyển binary log liên tục
mysqlbinlog --read-from-remote-server \
    --host=mysql-primary \
    --user=replicator \
    --password=repl_pass \
    --raw \
    --to-last-log mysql-bin.000001 | \
    aws s3 cp - s3://company-mysql-binlogs/$(hostname)/
```

---

## DR Runbook: Restore from S3 / Khôi Phục Từ S3

```bash
# Step 1: Find latest backup / Bước 1: Tìm backup mới nhất
aws s3 ls s3://company-mysql-backups/ --recursive | sort | tail -5

# Step 2: Download / Bước 2: Tải xuống
aws s3 cp s3://company-mysql-backups/2024/12/15/xb_20241215.tar.gz /tmp/

# Step 3: Restore with XtraBackup / Bước 3: Khôi phục
systemctl stop mysql
tar -xzf /tmp/xb_20241215.tar.gz -C /var/lib/mysql
xtrabackup --prepare --target-dir=/var/lib/mysql
chown -R mysql:mysql /var/lib/mysql
systemctl start mysql

# Step 4: Apply binlogs to reach target time / Bước 4: Áp dụng binlog đến thời gian mục tiêu
mysqlbinlog \
    --start-datetime="2024-12-15 02:00:00" \
    --stop-datetime="2024-12-15 14:30:00" \
    /tmp/binlogs/mysql-bin.* | mysql -u root -psecret
```

---

## Testing DR / Kiểm Tra DR

**Golden rule**: A DR plan never tested is not a DR plan.
_**Quy tắc vàng**: Kế hoạch DR chưa được kiểm tra không phải là kế hoạch DR._

```bash
# Monthly DR test / Kiểm tra DR hàng tháng
# 1. Restore to isolated test environment / Khôi phục vào môi trường test cách ly
# 2. Verify data integrity / Xác minh tính toàn vẹn dữ liệu
# 3. Run application smoke tests / Chạy smoke test ứng dụng
# 4. Measure actual RTO / Đo RTO thực tế
# 5. Document results / Ghi lại kết quả

mysql -h test-restore -u root -psecret -e "
SELECT COUNT(*) FROM shop_db.orders;
SELECT MAX(created_at) FROM shop_db.orders;
SHOW SLAVE STATUS\G
"
```

---

## DR Metrics / Metric DR

| Metric | Target | Measurement |
|--------|--------|-------------|
| RTO | < 30 min | Time from incident to writes available |
| RPO | < 1 hour | Age of oldest uncommitted data at recovery |
| MTTR | < 2 hours | Mean time to full recovery |
| Backup success rate | 100% | Failed backup alerts via Prometheus |

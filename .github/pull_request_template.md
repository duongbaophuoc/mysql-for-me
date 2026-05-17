---
name: Pull Request
about: Submit a contribution to the roadmap
title: ''
labels: ''
assignees: ''
---

## Summary / Tóm Tắt

Brief description of changes. _Mô tả ngắn gọn về thay đổi._

## Type of Change / Loại Thay Đổi

- [ ] 📝 Documentation fix / Sửa tài liệu
- [ ] 🐛 Bug fix (script or SQL error) / Sửa lỗi
- [ ] ✨ New content (new topic, lab, diagram) / Nội dung mới
- [ ] 🔧 Infrastructure improvement (Docker, K8s, monitoring) / Cải tiến hạ tầng
- [ ] 📊 New diagram / Sơ đồ mới

## Stage / Lab Affected / Stage/Lab Liên Quan

_Which stage or lab does this PR affect?_

## Checklist / Danh Sách Kiểm Tra

- [ ] Content is technically accurate / Nội dung chính xác kỹ thuật
- [ ] SQL/scripts tested against MySQL 8.0 / SQL/script đã test với MySQL 8.0
- [ ] Bilingual (EN + VI) where applicable / Song ngữ nếu phù hợp
- [ ] Follows existing file naming conventions / Tuân thủ quy ước đặt tên file
- [ ] Added to CHANGELOG.md if significant / Đã thêm vào CHANGELOG.md nếu quan trọng

## Testing / Kiểm Thử

Describe how you tested the changes. _Mô tả cách bạn kiểm thử thay đổi._

```bash
# Commands run to validate
docker compose -f docker/docker-compose.yml up -d
mysql -h 127.0.0.1 -P 3306 -u root -psecret < path/to/script.sql
```

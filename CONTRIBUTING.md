# Contributing / Hướng Dẫn Đóng Góp

Thank you for your interest in contributing to the MySQL Infrastructure Engineering Roadmap!
_Cảm ơn bạn đã quan tâm đến việc đóng góp cho Lộ Trình Kỹ Thuật Hạ Tầng MySQL!_

---

## How to Contribute / Cách Đóng Góp

### 1. Report Issues / Báo Cáo Vấn Đề

- Open a GitHub Issue for typos, outdated information, or bugs in SQL scripts
- _Mở GitHub Issue cho lỗi chính tả, thông tin lỗi thời, hoặc lỗi trong script SQL_
- Please include: stage number, file name, and description of the issue
- _Vui lòng bao gồm: số stage, tên file, và mô tả vấn đề_

### 2. Suggest Topics / Đề Xuất Chủ Đề

- Open a GitHub Discussion or Issue with the label `enhancement`
- _Mở GitHub Discussion hoặc Issue với nhãn `enhancement`_
- Topics must be relevant to production MySQL database engineering
- _Chủ đề phải liên quan đến kỹ thuật CSDL MySQL production_

### 3. Submit Pull Requests / Gửi Pull Request

```bash
# Fork and clone the repo / Fork và clone repo
git clone https://github.com/your-username/mysql-infra-engineering-roadmap
cd mysql-infra-engineering-roadmap

# Create a feature branch / Tạo nhánh tính năng
git checkout -b docs/stage-3-add-buffer-pool-examples

# Make your changes / Thực hiện thay đổi
# ...

# Commit with a clear message / Commit với thông điệp rõ ràng
git commit -m "docs(stage-3): add buffer pool eviction examples with diagrams"

# Push and open PR / Push và mở PR
git push origin docs/stage-3-add-buffer-pool-examples
```

---

## Documentation Standards / Tiêu Chuẩn Tài Liệu

All documentation must be **bilingual (English + Vietnamese)**.
_Tất cả tài liệu phải là **song ngữ (Tiếng Anh + Tiếng Việt)**._

### File Template / Mẫu File

```markdown
# Topic Name / Tên Chủ Đề

## Overview / Tổng Quan

English description here.
_Mô tả tiếng Việt ở đây._

## Section / Phần

English content.
_Nội dung tiếng Việt._

## Code Examples / Ví Dụ Code

SQL code với -- comments bằng tiếng Việt
```

### Guidelines / Hướng Dẫn

- Use clear, technical language — not marketing speak
- _Dùng ngôn ngữ kỹ thuật rõ ràng — không phải ngôn ngữ marketing_
- Vietnamese translations should be accurate and natural, not literal
- _Bản dịch tiếng Việt phải chính xác và tự nhiên, không phải dịch từng từ_
- Include working SQL examples wherever possible
- _Bao gồm ví dụ SQL hoạt động được ở bất cứ đâu có thể_
- Diagrams should use ASCII art or Mermaid syntax
- _Sơ đồ nên dùng ASCII art hoặc cú pháp Mermaid_

---

## SQL Code Standards / Tiêu Chuẩn Code SQL

```sql
-- Good / Tốt: clear intent, production-safe
SELECT 
    o.id,
    o.total_amount,
    c.email
FROM orders o
INNER JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'pending'
  AND o.created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
LIMIT 1000;

-- Include Vietnamese comments for complex logic
-- Bao gồm comment tiếng Việt cho logic phức tạp
```

---

## Code of Conduct / Quy Tắc Ứng Xử

- Be respectful and constructive / Tôn trọng và xây dựng
- Focus on technical accuracy / Tập trung vào độ chính xác kỹ thuật
- No self-promotion or spam / Không quảng cáo hay spam

---

## License / Giấy Phép

By contributing, you agree that your contributions will be licensed under the MIT License.
_Bằng cách đóng góp, bạn đồng ý rằng đóng góp của bạn sẽ được cấp phép theo Giấy phép MIT._

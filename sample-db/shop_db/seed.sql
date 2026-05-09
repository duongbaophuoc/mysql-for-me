-- =============================================================================
-- shop_db — Seed Data / Dữ Liệu Mẫu
-- Run AFTER schema.sql / Chạy SAU schema.sql
-- =============================================================================

USE shop_db;

-- =============================================================================
-- Categories / Danh mục
-- =============================================================================
INSERT INTO categories (id, parent_id, name, slug, lft, rgt, depth) VALUES
(1, NULL, 'Electronics',          'electronics',           1,  20, 0),
(2, 1,    'Smartphones',          'smartphones',           2,   7, 1),
(3, 2,    'Android Phones',       'android-phones',        3,   4, 2),
(4, 2,    'iPhones',              'iphones',               5,   6, 2),
(5, 1,    'Laptops',              'laptops',               8,  13, 1),
(6, 5,    'Gaming Laptops',       'gaming-laptops',        9,  10, 2),
(7, 5,    'Business Laptops',     'business-laptops',     11,  12, 2),
(8, 1,    'Accessories',          'accessories',          14,  19, 1),
(9, NULL, 'Fashion',              'fashion',              21,  30, 0),
(10, 9,   'Men\'s Clothing',      'mens-clothing',        22,  25, 1),
(11, 9,   'Women\'s Clothing',    'womens-clothing',      26,  29, 1);

-- =============================================================================
-- Products / Sản phẩm
-- =============================================================================
INSERT INTO products (id, sku, category_id, name, price, status, attributes) VALUES
(1,  'SAM-S24U-256',   3, 'Samsung Galaxy S24 Ultra 256GB',   29990000, 'active',
     JSON_OBJECT('color','Titanium Black','ram','12GB','storage','256GB','warranty_months',12)),
(2,  'IPH-15PM-256',   4, 'iPhone 15 Pro Max 256GB',          39990000, 'active',
     JSON_OBJECT('color','Natural Titanium','ram','8GB','storage','256GB','warranty_months',12)),
(3,  'XIA-14T-128',    3, 'Xiaomi 14T 128GB',                 13990000, 'active',
     JSON_OBJECT('color','Titan Gray','ram','12GB','storage','128GB','warranty_months',12)),
(4,  'ASUS-ROG-G16',   6, 'ASUS ROG Strix G16 2024 i9',       54990000, 'active',
     JSON_OBJECT('cpu','Intel Core i9-14900HX','gpu','RTX 4080','ram','32GB','storage','1TB')),
(5,  'DELL-XPS-15',    7, 'Dell XPS 15 9530 i7',              42990000, 'active',
     JSON_OBJECT('cpu','Intel Core i7-13700H','gpu','RTX 4060','ram','16GB','storage','512GB')),
(6,  'ANKER-USB-HUB',  8, 'Anker 10-in-1 USB-C Hub',          1290000, 'active',
     JSON_OBJECT('ports','10','usb_a',4,'hdmi',2,'sd_card',1)),
(7,  'UNIQLO-POLO-M',  10,'Uniqlo DRY-EX Polo Shirt Men M',   499000,  'active',
     JSON_OBJECT('size','M','color','Navy','material','100% Polyester'));

-- =============================================================================
-- Inventory / Tồn kho
-- =============================================================================
INSERT INTO inventory (product_id, warehouse_code, quantity_available, quantity_reserved, reorder_threshold) VALUES
(1, 'WH-HN-01', 145,  12,  20),
(2, 'WH-HN-01',  89,   5,  15),
(3, 'WH-HN-01', 203,   8,  30),
(4, 'WH-HN-01',  34,   2,  10),
(5, 'WH-HN-01',  56,   3,  10),
(6, 'WH-HN-01', 512,  20,  50),
(7, 'WH-HN-01', 890,  30, 100),
(1, 'WH-SGN-01', 78,   6,  15),
(2, 'WH-SGN-01', 45,   2,  10);

-- =============================================================================
-- Customers / Khách hàng
-- =============================================================================
INSERT INTO customers (id, uuid, email, phone, full_name, status) VALUES
(1, UUID(), 'nguyen.van.a@gmail.com',    '+84901234567', 'Nguyễn Văn A',   'active'),
(2, UUID(), 'tran.thi.b@gmail.com',      '+84912345678', 'Trần Thị B',     'active'),
(3, UUID(), 'le.van.c@company.vn',       '+84923456789', 'Lê Văn C',       'active'),
(4, UUID(), 'pham.thi.d@outlook.com',    '+84934567890', 'Phạm Thị D',     'active'),
(5, UUID(), 'hoang.van.e@yahoo.com',     '+84945678901', 'Hoàng Văn E',    'inactive'),
(6, UUID(), 'vuong.thi.f@gmail.com',     '+84956789012', 'Vương Thị F',    'active'),
(7, UUID(), 'dao.van.g@gmail.com',       '+84967890123', 'Đào Văn G',      'active');

-- =============================================================================
-- Customer Addresses / Địa chỉ
-- =============================================================================
INSERT INTO customer_addresses (customer_id, label, address, city, country, is_default) VALUES
(1, 'home',   '12 Lý Thường Kiệt, Hoàn Kiếm',    'Hà Nội',      'VN', 1),
(1, 'office', '1 Đại Cồ Việt, Hai Bà Trưng',      'Hà Nội',      'VN', 0),
(2, 'home',   '56 Nguyễn Huệ, Quận 1',            'Hồ Chí Minh', 'VN', 1),
(3, 'home',   '89 Trần Văn Kiểu, Ninh Kiều',      'Cần Thơ',     'VN', 1),
(4, 'home',   '23 Hùng Vương, Hải Châu',          'Đà Nẵng',     'VN', 1),
(6, 'home',   '101 Pasteur, Ninh Kiều',            'Cần Thơ',     'VN', 1),
(7, 'home',   '45 Nguyễn Chí Thanh, Đống Đa',     'Hà Nội',      'VN', 1);

-- =============================================================================
-- Orders / Đơn hàng
-- =============================================================================
INSERT INTO orders (id, uuid, customer_id, address_id, status, subtotal, discount_amount, tax_amount, shipping_amount, total_amount, source, created_at) VALUES
(1, UUID(), 1, 1, 'delivered',  29990000, 1000000, 2890000, 30000,  31910000, 'web',  '2024-11-15 09:23:00'),
(2, UUID(), 2, 3, 'delivered',  39990000,       0, 3999000, 30000,  44019000, 'app',  '2024-11-20 14:12:00'),
(3, UUID(), 3, 4, 'shipped',    54990000,  500000, 5449000, 50000,  59989000, 'web',  '2024-12-01 10:05:00'),
(4, UUID(), 1, 1, 'processing', 13990000,       0, 1399000, 30000,  15419000, 'app',  '2024-12-10 16:44:00'),
(5, UUID(), 4, 5, 'pending',     1290000,   50000,  124000, 15000,   1379000, 'web',  '2024-12-11 08:30:00'),
(6, UUID(), 6, 6, 'delivered',  42990000,       0, 4299000, 30000,  47319000, 'web',  '2024-12-05 11:15:00'),
(7, UUID(), 7, 7, 'cancelled',  29990000,       0, 2999000, 30000,  33019000, 'pos',  '2024-12-08 09:00:00');

-- =============================================================================
-- Order Items / Chi tiết đơn hàng
-- =============================================================================
INSERT INTO order_items (order_id, product_id, product_sku, product_name, unit_price, quantity, discount) VALUES
(1, 1, 'SAM-S24U-256',  'Samsung Galaxy S24 Ultra 256GB',   29990000, 1, 1000000),
(2, 2, 'IPH-15PM-256',  'iPhone 15 Pro Max 256GB',          39990000, 1, 0),
(3, 4, 'ASUS-ROG-G16',  'ASUS ROG Strix G16 2024 i9',       54990000, 1, 500000),
(4, 3, 'XIA-14T-128',   'Xiaomi 14T 128GB',                 13990000, 1, 0),
(5, 6, 'ANKER-USB-HUB', 'Anker 10-in-1 USB-C Hub',           1290000, 1, 50000),
(6, 5, 'DELL-XPS-15',   'Dell XPS 15 9530 i7',              42990000, 1, 0),
(7, 1, 'SAM-S24U-256',  'Samsung Galaxy S24 Ultra 256GB',   29990000, 1, 0);

-- =============================================================================
-- Payments / Thanh toán
-- =============================================================================
INSERT INTO payments (uuid, order_id, method, status, amount, gateway, gateway_txn_id, idempotency_key, processed_at) VALUES
(UUID(), 1, 'bank_transfer', 'completed', 31910000, 'vnpay',  'VNP-20241115-001', 'idem-order-1-pay-1', '2024-11-15 09:28:00'),
(UUID(), 2, 'card',          'completed', 44019000, 'stripe', 'pi_3OAbc123',       'idem-order-2-pay-1', '2024-11-20 14:15:00'),
(UUID(), 3, 'wallet',        'completed', 59989000, 'momo',   'MOMO-2024120001',   'idem-order-3-pay-1', '2024-12-01 10:08:00'),
(UUID(), 4, 'qr',            'processing',15419000, 'vnpay',  'VNP-20241210-004', 'idem-order-4-pay-1', NULL),
(UUID(), 5, 'cod',           'pending',    1379000,  NULL,     NULL,               'idem-order-5-pay-1', NULL),
(UUID(), 6, 'card',          'completed', 47319000, 'stripe', 'pi_3OBcd456',       'idem-order-6-pay-1', '2024-12-05 11:18:00'),
(UUID(), 7, 'bank_transfer', 'failed',    33019000, 'vnpay',  'VNP-20241208-007', 'idem-order-7-pay-1', '2024-12-08 09:05:00');

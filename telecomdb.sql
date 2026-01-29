-- ================================================
-- Telecommunications Provider Relational Database
-- ================================================

-- ====================================
-- Task 1.2 Create Database and Tables
-- ====================================
DROP DATABASE IF EXISTS telecom_db;
CREATE DATABASE telecom_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE telecom_db;

-- -------------------------
-- Reference / Master tables
-- -------------------------

CREATE TABLE technologies (
  technology_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  tech_name VARCHAR(40) NOT NULL,
  UNIQUE KEY uq_tech_name (tech_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE addresses (
  address_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  line1 VARCHAR(150) NOT NULL,
  line2 VARCHAR(150),
  city VARCHAR(80) NOT NULL,
  state_region VARCHAR(80),
  postal_code VARCHAR(20),
  country VARCHAR(80) NOT NULL DEFAULT 'Ghana'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE subscribers (
  subscriber_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(80) NOT NULL,
  last_name  VARCHAR(80) NOT NULL,
  email      VARCHAR(255) NOT NULL,
  phone_msisdn VARCHAR(20) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_subscriber_email (email),
  UNIQUE KEY uq_subscriber_msisdn (phone_msisdn),
  CONSTRAINT chk_subscriber_status CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- M:N: subscribers <-> addresses
CREATE TABLE subscriber_addresses (
  subscriber_id BIGINT NOT NULL,
  address_id BIGINT NOT NULL,
  address_type VARCHAR(20) NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (subscriber_id, address_id, address_type),
  CONSTRAINT fk_sa_sub FOREIGN KEY (subscriber_id) REFERENCES subscribers(subscriber_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_sa_addr FOREIGN KEY (address_id) REFERENCES addresses(address_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT chk_sa_type CHECK (address_type IN ('BILLING','RESIDENTIAL'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE plans (
  plan_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  plan_code VARCHAR(40) NOT NULL,
  plan_name VARCHAR(120) NOT NULL,
  plan_type VARCHAR(20) NOT NULL, -- PREPAID / POSTPAID
  monthly_fee DECIMAL(12,2) NOT NULL DEFAULT 0,
  voice_minutes_included INT NOT NULL DEFAULT 0,
  sms_included INT NOT NULL DEFAULT 0,
  data_gb_included DECIMAL(10,2) NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'GHS',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE KEY uq_plan_code (plan_code),
  CONSTRAINT chk_plan_type CHECK (plan_type IN ('PREPAID','POSTPAID')),
  CONSTRAINT chk_plan_fee CHECK (monthly_fee >= 0),
  CONSTRAINT chk_plan_currency CHECK (currency REGEXP '^[A-Z]{3}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE features (
  feature_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  feature_name VARCHAR(120) NOT NULL,
  UNIQUE KEY uq_feature_name (feature_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- M:N: plans <-> features
CREATE TABLE plan_features (
  plan_id BIGINT NOT NULL,
  feature_id BIGINT NOT NULL,
  PRIMARY KEY (plan_id, feature_id),
  CONSTRAINT fk_pf_plan FOREIGN KEY (plan_id) REFERENCES plans(plan_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_pf_feature FOREIGN KEY (feature_id) REFERENCES features(feature_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sim_cards (
  sim_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  iccid VARCHAR(25) NOT NULL,
  sim_status VARCHAR(20) NOT NULL DEFAULT 'IN_STOCK',
  issued_at DATETIME NULL,
  UNIQUE KEY uq_sim_iccid (iccid),
  CONSTRAINT chk_sim_status CHECK (sim_status IN ('IN_STOCK','ISSUED','SUSPENDED','RETIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- M:N: subscribers <-> sims (supports SIM swap history)
CREATE TABLE subscriber_sims (
  subscriber_id BIGINT NOT NULL,
  sim_id BIGINT NOT NULL,
  assigned_from DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  assigned_to DATETIME NULL,
  PRIMARY KEY (subscriber_id, sim_id, assigned_from),
  CONSTRAINT fk_ss_sub FOREIGN KEY (subscriber_id) REFERENCES subscribers(subscriber_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_ss_sim FOREIGN KEY (sim_id) REFERENCES sim_cards(sim_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Subscriber plan subscriptions (1 subscriber can have many subscriptions over time)
CREATE TABLE subscriptions (
  subscription_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  subscriber_id BIGINT NOT NULL,
  plan_id BIGINT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NULL,
  subscription_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  CONSTRAINT fk_subs_sub FOREIGN KEY (subscriber_id) REFERENCES subscribers(subscriber_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_subs_plan FOREIGN KEY (plan_id) REFERENCES plans(plan_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_subs_status CHECK (subscription_status IN ('ACTIVE','PAUSED','CANCELLED','EXPIRED')),
  KEY idx_subs_subscriber (subscriber_id, subscription_status, start_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Network towers and technology capability
CREATE TABLE towers (
  tower_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  tower_code VARCHAR(40) NOT NULL,
  city VARCHAR(80) NOT NULL,
  latitude DECIMAL(10,6),
  longitude DECIMAL(10,6),
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  UNIQUE KEY uq_tower_code (tower_code),
  CONSTRAINT chk_tower_status CHECK (status IN ('ACTIVE','MAINTENANCE','DECOMMISSIONED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- M:N: towers <-> technologies
CREATE TABLE tower_technologies (
  tower_id BIGINT NOT NULL,
  technology_id BIGINT NOT NULL,
  PRIMARY KEY (tower_id, technology_id),
  CONSTRAINT fk_tt_tower FOREIGN KEY (tower_id) REFERENCES towers(tower_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_tt_tech FOREIGN KEY (technology_id) REFERENCES technologies(technology_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Usage records (CDR-like simplified)
CREATE TABLE usage_records (
  usage_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  subscriber_id BIGINT NOT NULL,
  tower_id BIGINT NOT NULL,
  usage_datetime DATETIME NOT NULL,
  usage_type VARCHAR(20) NOT NULL, -- DATA/VOICE/SMS
  units DECIMAL(12,2) NOT NULL,    -- MB for DATA, minutes for VOICE, count for SMS
  CONSTRAINT fk_ur_sub FOREIGN KEY (subscriber_id) REFERENCES subscribers(subscriber_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_ur_tower FOREIGN KEY (tower_id) REFERENCES towers(tower_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_usage_type CHECK (usage_type IN ('DATA','VOICE','SMS')),
  CONSTRAINT chk_units CHECK (units >= 0),
  KEY idx_usage_sub_time (subscriber_id, usage_datetime),
  KEY idx_usage_tower_time (tower_id, usage_datetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Billing: invoices and invoice items
CREATE TABLE invoices (
  invoice_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  subscriber_id BIGINT NOT NULL,
  billing_month DATE NOT NULL, -- store as first day of month
  invoice_status VARCHAR(20) NOT NULL DEFAULT 'ISSUED',
  issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  due_date DATE NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'GHS',
  UNIQUE KEY uq_invoice_sub_month (subscriber_id, billing_month),
  CONSTRAINT fk_inv_sub FOREIGN KEY (subscriber_id) REFERENCES subscribers(subscriber_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_inv_status CHECK (invoice_status IN ('ISSUED','PAID','OVERDUE','CANCELLED')),
  CONSTRAINT chk_inv_currency CHECK (currency REGEXP '^[A-Z]{3}$'),
  KEY idx_invoice_status_due (invoice_status, due_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE invoice_items (
  invoice_item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  invoice_id BIGINT NOT NULL,
  item_type VARCHAR(30) NOT NULL, -- PLAN_FEE, OVERAGE, ADDON, TAX, ADJUSTMENT
  description VARCHAR(200) NOT NULL,
  quantity DECIMAL(12,2) NOT NULL DEFAULT 1,
  unit_price DECIMAL(12,2) NOT NULL DEFAULT 0,
  line_discount DECIMAL(12,2) NOT NULL DEFAULT 0,
  CONSTRAINT fk_ii_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT chk_ii_qty CHECK (quantity > 0),
  CONSTRAINT chk_ii_prices CHECK (unit_price >= 0 AND line_discount >= 0),
  KEY idx_invoice_items_invoice (invoice_id, item_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE promotions (
  promotion_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  promo_code VARCHAR(40) NOT NULL,
  description VARCHAR(200),
  discount_type VARCHAR(20) NOT NULL, -- PERCENT/AMOUNT
  discount_value DECIMAL(12,2) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE KEY uq_promo_code (promo_code),
  CONSTRAINT chk_promo_type CHECK (discount_type IN ('PERCENT','AMOUNT')),
  CONSTRAINT chk_promo_value CHECK (discount_value >= 0),
  CONSTRAINT chk_promo_dates CHECK (end_date >= start_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- M:N: invoices <-> promotions
CREATE TABLE invoice_promotions (
  invoice_id BIGINT NOT NULL,
  promotion_id BIGINT NOT NULL,
  applied_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (invoice_id, promotion_id),
  CONSTRAINT fk_ip_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_ip_promo FOREIGN KEY (promotion_id) REFERENCES promotions(promotion_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_ip_applied CHECK (applied_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payments (
  payment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  invoice_id BIGINT NOT NULL,
  payment_method VARCHAR(20) NOT NULL, -- CARD, MOMO, BANK_TRANSFER, CASH
  payment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  amount DECIMAL(12,2) NOT NULL,
  paid_at DATETIME NULL,
  transaction_ref VARCHAR(80) UNIQUE,
  CONSTRAINT fk_pay_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT chk_pay_method CHECK (payment_method IN ('CARD','MOMO','BANK_TRANSFER','CASH')),
  CONSTRAINT chk_pay_status CHECK (payment_status IN ('PENDING','SUCCESS','FAILED','REFUNDED')),
  CONSTRAINT chk_pay_amount CHECK (amount >= 0),
  KEY idx_pay_invoice_status (invoice_id, payment_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ===========================================
-- Task 2.1 Sample Data (5-10 rows per table)
-- ===========================================

INSERT INTO technologies (tech_name) VALUES
('2G'),('3G'),('4G'),('5G'),('LTE');

INSERT INTO addresses (line1, line2, city, state_region, postal_code, country) VALUES
('14 Ring Road', 'Osu', 'Accra', 'Greater Accra', 'GA-101', 'Ghana'),
('22 Liberation Rd', NULL, 'Accra', 'Greater Accra', 'GA-102', 'Ghana'),
('5 Kejetia Ave', NULL, 'Kumasi', 'Ashanti', 'AS-201', 'Ghana'),
('8 Tech Junction', NULL, 'Kumasi', 'Ashanti', 'AS-202', 'Ghana'),
('3 Castle Rd', NULL, 'Cape Coast', 'Central', 'CR-301', 'Ghana'),
('9 University Ln', NULL, 'Cape Coast', 'Central', 'CR-302', 'Ghana'),
('17 Stadium Rd', NULL, 'Tamale', 'Northern', 'NR-401', 'Ghana'),
('21 Market St', NULL, 'Ho', 'Volta', 'VR-501', 'Ghana'),
('2 Airport Res', NULL, 'Accra', 'Greater Accra', 'GA-103', 'Ghana'),
('11 Adum High St', NULL, 'Kumasi', 'Ashanti', 'AS-203', 'Ghana');

INSERT INTO subscribers (first_name, last_name, email, phone_msisdn, status) VALUES
('Ama', 'Mensah', 'ama.mensah@example.com', '+233200111111', 'ACTIVE'),
('Kojo', 'Owusu', 'kojo.owusu@example.com', '+233200222222', 'ACTIVE'),
('Esi', 'Arthur', 'esi.arthur@example.com', '+233200333333', 'ACTIVE'),
('Yaw', 'Boateng', 'yaw.boateng@example.com', '+233200444444', 'SUSPENDED'),
('Afia', 'Addo', 'afia.addo@example.com', '+233200555555', 'ACTIVE'),
('Kwaku', 'Asante', 'kwaku.asante@example.com', '+233200666666', 'ACTIVE');

INSERT INTO subscriber_addresses (subscriber_id, address_id, address_type, is_default) VALUES
(1, 1, 'RESIDENTIAL', TRUE),
(1, 2, 'BILLING', TRUE),
(2, 3, 'RESIDENTIAL', TRUE),
(2, 3, 'BILLING', TRUE),
(3, 5, 'RESIDENTIAL', TRUE),
(3, 6, 'BILLING', TRUE),
(5, 9, 'RESIDENTIAL', TRUE),
(6, 10,'RESIDENTIAL', TRUE);

INSERT INTO plans (plan_code, plan_name, plan_type, monthly_fee, voice_minutes_included, sms_included, data_gb_included, currency) VALUES
('P-START', 'Prepaid Starter', 'PREPAID', 10.00, 30, 50, 1.00, 'GHS'),
('P-PLUS',  'Prepaid Plus',    'PREPAID', 25.00, 120, 200, 5.00, 'GHS'),
('P-MAX',   'Prepaid Max',     'PREPAID', 45.00, 300, 500, 15.00,'GHS'),
('POST-BIZ','Postpaid Business','POSTPAID',120.00, 800, 1000, 50.00,'GHS'),
('POST-ULT','Postpaid Ultra',  'POSTPAID',220.00, 2000, 2000, 150.00,'GHS');

INSERT INTO features (feature_name) VALUES
('Roaming Enabled'),
('Family Sharing'),
('Unlimited Night Data'),
('Priority Support'),
('International Calls');

INSERT INTO plan_features (plan_id, feature_id) VALUES
(2, 1),
(3, 1),
(3, 3),
(4, 4),
(5, 4),
(5, 5),
(4, 5),
(2, 2);

INSERT INTO sim_cards (iccid, sim_status, issued_at) VALUES
('8992330000000000001','ISSUED','2025-10-01 09:00:00'),
('8992330000000000002','ISSUED','2025-10-02 10:00:00'),
('8992330000000000003','ISSUED','2025-10-03 11:00:00'),
('8992330000000000004','IN_STOCK',NULL),
('8992330000000000005','IN_STOCK',NULL),
('8992330000000000006','ISSUED','2025-11-01 08:30:00');

INSERT INTO subscriber_sims (subscriber_id, sim_id, assigned_from, assigned_to) VALUES
(1, 1, '2025-10-01 09:10:00', NULL),
(2, 2, '2025-10-02 10:10:00', NULL),
(3, 3, '2025-10-03 11:10:00', NULL),
(5, 6, '2025-11-01 08:40:00', NULL),
(6, 4, '2026-01-02 12:00:00', '2026-01-05 12:00:00'),
(6, 5, '2026-01-05 12:10:00', NULL);

INSERT INTO subscriptions (subscriber_id, plan_id, start_date, end_date, subscription_status) VALUES
(1, 2, '2025-10-01', NULL, 'ACTIVE'),
(2, 4, '2025-11-01', NULL, 'ACTIVE'),
(3, 3, '2025-12-01', NULL, 'ACTIVE'),
(4, 1, '2025-09-15', '2025-12-15', 'CANCELLED'),
(5, 2, '2025-12-10', NULL, 'ACTIVE'),
(6, 5, '2026-01-01', NULL, 'ACTIVE');

INSERT INTO towers (tower_code, city, latitude, longitude, status) VALUES
('ACC-TS-001','Accra', 5.603717, -0.186964, 'ACTIVE'),
('ACC-TS-002','Accra', 5.614818, -0.205874, 'MAINTENANCE'),
('KSI-TS-001','Kumasi',6.688480, -1.624430, 'ACTIVE'),
('CC-TS-001', 'Cape Coast',5.105350, -1.246600, 'ACTIVE'),
('TML-TS-001','Tamale',9.407000, -0.853000, 'ACTIVE');

INSERT INTO tower_technologies (tower_id, technology_id) VALUES
(1, 3), (1, 4),
(2, 3),
(3, 3), (3, 5),
(4, 2),
(5, 3);

INSERT INTO promotions (promo_code, description, discount_type, discount_value, start_date, end_date, is_active) VALUES
('WELCOME10', '10% off first month plan fee', 'PERCENT', 10.00, '2025-01-01', '2026-12-31', TRUE),
('DATA20', 'GHS 20 off data add-ons', 'AMOUNT', 20.00, '2025-06-01', '2026-06-30', TRUE),
('BIZ15', '15% off business plan for 3 months', 'PERCENT', 15.00, '2025-08-01', '2026-03-31', TRUE),
('LOYAL5', '5% loyalty discount', 'PERCENT', 5.00, '2025-01-01', '2026-12-31', TRUE),
('ROAM30', 'GHS 30 off roaming pack', 'AMOUNT', 30.00, '2025-09-01', '2026-02-28', TRUE);

INSERT INTO invoices (subscriber_id, billing_month, invoice_status, issued_at, due_date, currency) VALUES
(1, '2025-10-01', 'PAID',    '2025-10-02 08:00:00', '2025-10-15', 'GHS'),
(2, '2025-11-01', 'PAID',    '2025-11-02 08:00:00', '2025-11-15', 'GHS'),
(3, '2025-12-01', 'ISSUED',  '2025-12-02 08:00:00', '2025-12-15', 'GHS'),
(5, '2025-12-01', 'PAID',    '2025-12-12 08:00:00', '2025-12-25', 'GHS'),
(6, '2026-01-01', 'ISSUED',  '2026-01-02 08:00:00', '2026-01-15', 'GHS');

INSERT INTO invoice_items (invoice_id, item_type, description, quantity, unit_price, line_discount) VALUES
(1, 'PLAN_FEE', 'Prepaid Plus monthly fee', 1, 25.00, 2.50),
(1, 'ADDON', 'Extra 2GB data add-on', 1, 10.00, 0.00),
(2, 'PLAN_FEE', 'Postpaid Business monthly fee', 1, 120.00, 18.00),
(2, 'OVERAGE', 'Data overage (1.5GB)', 1.5, 8.00, 0.00),
(3, 'PLAN_FEE', 'Prepaid Max monthly fee', 1, 45.00, 4.50),
(3, 'TAX', 'Telecom VAT', 1, 3.50, 0.00),
(4, 'PLAN_FEE', 'Prepaid Plus monthly fee', 1, 25.00, 1.25),
(4, 'ADDON', 'Roaming pack', 1, 30.00, 0.00),
(5, 'PLAN_FEE', 'Postpaid Ultra monthly fee', 1, 220.00, 11.00),
(5, 'ADJUSTMENT', 'Service credit', 1, 0.00, 5.00);

INSERT INTO invoice_promotions (invoice_id, promotion_id, applied_amount) VALUES
(1, 1, 2.50),
(2, 3, 18.00),
(3, 1, 4.50),
(4, 4, 1.25),
(5, 4, 11.00);

INSERT INTO payments (invoice_id, payment_method, payment_status, amount, paid_at, transaction_ref) VALUES
(1, 'MOMO', 'SUCCESS', 32.50, '2025-10-05 10:00:00', 'PAY-ACC-0001'),
(2, 'BANK_TRANSFER', 'SUCCESS', 114.00,'2025-11-06 12:00:00', 'PAY-ACC-0002'),
(4, 'CARD', 'SUCCESS', 53.75, '2025-12-20 09:00:00', 'PAY-CC-0003'),
(3, 'MOMO', 'PENDING', 44.00, NULL, 'PAY-CC-0004'),
(5, 'CARD', 'PENDING', 204.00, NULL, 'PAY-ACC-0005');

INSERT INTO usage_records (subscriber_id, tower_id, usage_datetime, usage_type, units) VALUES
(1, 1, '2025-10-10 08:10:00', 'DATA', 850.00),
(1, 1, '2025-10-10 09:15:00', 'VOICE', 12.00),
(2, 3, '2025-11-12 18:00:00', 'DATA', 1200.00),
(2, 3, '2025-11-13 10:00:00', 'SMS', 10.00),
(3, 4, '2025-12-05 12:00:00', 'DATA', 3400.00),
(3, 4, '2025-12-06 12:00:00', 'VOICE', 45.00),
(5, 1, '2025-12-20 19:30:00', 'DATA', 900.00),
(6, 2, '2026-01-05 08:30:00', 'DATA', 5000.00),
(6, 2, '2026-01-06 09:30:00', 'SMS', 25.00),
(6, 5, '2026-01-07 21:00:00', 'VOICE', 60.00);

-- =======================
-- Task 2.2 View Creation
-- =======================

-- View 1
CREATE OR REPLACE VIEW vw_monthly_billing_summary AS
SELECT
  DATE_FORMAT(i.billing_month, '%Y-%m-01') AS month_start,
  COUNT(*) AS invoices_issued,
  SUM(
    (SELECT COALESCE(SUM((ii.unit_price * ii.quantity) - ii.line_discount), 0)
     FROM invoice_items ii
     WHERE ii.invoice_id = i.invoice_id)
  ) AS gross_amount,
  SUM(COALESCE(paid.total_paid, 0)) AS total_paid,
  SUM(
    (SELECT COALESCE(SUM(ip.applied_amount), 0)
     FROM invoice_promotions ip
     WHERE ip.invoice_id = i.invoice_id)
  ) AS total_promo_discounts
FROM invoices i
LEFT JOIN (
  SELECT invoice_id, SUM(amount) AS total_paid
  FROM payments
  WHERE payment_status = 'SUCCESS'
  GROUP BY invoice_id
) paid ON paid.invoice_id = i.invoice_id
GROUP BY DATE_FORMAT(i.billing_month, '%Y-%m-01');

SELECT * FROM vw_monthly_billing_summary ORDER BY month_start;

-- View 2
CREATE OR REPLACE VIEW vw_monthly_data_usage_trend AS
SELECT
  DATE_FORMAT(usage_datetime, '%Y-%m-01') AS month_start,
  subscriber_id,
  ROUND(SUM(CASE WHEN usage_type='DATA' THEN units ELSE 0 END) / 1024, 2) AS data_gb_used,
  SUM(CASE WHEN usage_type='VOICE' THEN units ELSE 0 END) AS voice_minutes_used,
  SUM(CASE WHEN usage_type='SMS' THEN units ELSE 0 END) AS sms_used
FROM usage_records
GROUP BY DATE_FORMAT(usage_datetime, '%Y-%m-01'), subscriber_id;

SELECT *
FROM vw_monthly_data_usage_trend
ORDER BY month_start, voice_minutes_used DESC;

-- ===========================================
-- Task 3  Advanced SQL Queries for Analytics
-- ===========================================

-- =========================
-- Query 1. Stored Function
-- =========================

-- Purpose: Compute invoice net amount from invoice line items.
DELIMITER $$

CREATE FUNCTION fn_invoice_items_net(p_invoice_id BIGINT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_net DECIMAL(12,2);

  SELECT COALESCE(SUM((unit_price * quantity) - line_discount), 0.00)
    INTO v_net
  FROM invoice_items
  WHERE invoice_id = p_invoice_id;

  RETURN v_net;
END$$

DELIMITER ;

SELECT
  i.invoice_id,
  s.phone_msisdn,
  fn_invoice_items_net(i.invoice_id) AS invoice_net_amount
FROM invoices i
JOIN subscribers s ON s.subscriber_id = i.subscriber_id
ORDER BY i.invoice_id;

-- ==========================
-- Query 2. Stored Procedure
-- ==========================

-- Purpose: List invoices overdue as of a given date, including outstanding amount.
DELIMITER $$

CREATE PROCEDURE sp_overdue_invoices_report(IN p_as_of_date DATE)
BEGIN
  SELECT
    i.invoice_id,
    i.subscriber_id,
    CONCAT(s.first_name,' ',s.last_name) AS subscriber_name,
    s.phone_msisdn,
    i.billing_month,
    i.due_date,
    i.invoice_status,
    fn_invoice_items_net(i.invoice_id) AS invoice_net_amount,
    COALESCE(paid.total_paid, 0) AS total_paid,
    (fn_invoice_items_net(i.invoice_id) - COALESCE(paid.total_paid, 0)) AS outstanding_amount,
    CASE
      WHEN i.due_date < p_as_of_date
       AND (fn_invoice_items_net(i.invoice_id) - COALESCE(paid.total_paid, 0)) > 0
      THEN 'OVERDUE'
      ELSE 'NOT OVERDUE'
    END AS overdue_flag
  FROM invoices i
  JOIN subscribers s ON s.subscriber_id = i.subscriber_id
  LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS total_paid
    FROM payments
    WHERE payment_status = 'SUCCESS'
    GROUP BY invoice_id
  ) paid ON paid.invoice_id = i.invoice_id
  WHERE i.invoice_status IN ('ISSUED','OVERDUE')
    AND i.due_date <= p_as_of_date
  ORDER BY outstanding_amount DESC, i.due_date ASC;
END$$

DELIMITER ;

CALL sp_overdue_invoices_report('2026-01-15');



-- ---------------------------------------------------------------==========
-- Query 3 — Plan Performance (3+ Tables JOIN + Aggregation + HAVING + CASE)
-- =========================================================================

-- Analytical question: Which plans drive the most billing value and active subscribers?
SELECT
  p.plan_id,
  p.plan_code,
  p.plan_name,
  COUNT(DISTINCT sub.subscription_id) AS active_subscriptions,
  SUM(fn_invoice_items_net(i.invoice_id)) AS billed_amount,
  CASE
    WHEN COUNT(DISTINCT sub.subscription_id) >= 3 THEN 'High Adoption'
    WHEN COUNT(DISTINCT sub.subscription_id) >= 2 THEN 'Medium Adoption'
    ELSE 'Low Adoption'
  END AS adoption_band
FROM plans p
JOIN subscriptions sub
  ON sub.plan_id = p.plan_id
 AND sub.subscription_status = 'ACTIVE'
JOIN invoices i
  ON i.subscriber_id = sub.subscriber_id
WHERE i.invoice_status IN ('ISSUED','PAID','OVERDUE')
GROUP BY p.plan_id, p.plan_code, p.plan_name
HAVING billed_amount > 0
ORDER BY billed_amount DESC, active_subscriptions DESC;

-- ====================================================================
-- Query 4 — Promotion Effectiveness (Subquery + HAVING + Aggregation)
-- ====================================================================

-- Analytical question: Which promotions are used most and how much billing value they touch?
SELECT
  pr.promo_code,
  COUNT(DISTINCT ip.invoice_id) AS invoices_using_promo,
  SUM(ip.applied_amount) AS total_discount,
  ROUND(AVG(ip.applied_amount), 2) AS avg_discount,
  (
    SELECT SUM(fn_invoice_items_net(i.invoice_id))
    FROM invoices i
    WHERE i.invoice_id IN (
      SELECT ip2.invoice_id
      FROM invoice_promotions ip2
      WHERE ip2.promotion_id = pr.promotion_id
    )
    AND i.invoice_status IN ('ISSUED','PAID','OVERDUE')
  ) AS billed_on_promo_invoices
FROM promotions pr
JOIN invoice_promotions ip ON ip.promotion_id = pr.promotion_id
GROUP BY pr.promotion_id, pr.promo_code
HAVING invoices_using_promo >= 1
ORDER BY billed_on_promo_invoices DESC, total_discount DESC;

-- =========================================================================================
-- Query 5 — Tower Load & Technology Capability (Multi-Table JOIN + Conditional Aggregation)
-- =========================================================================================

-- Analytical question: Which towers and technologies carry the most demand in the last 30 days?
-- Query 5 — Tower Load & Technology Capability with Window Function

SELECT
  t.city,
  t.tower_code,
  tech.tech_name,
  COUNT(ur.usage_id) AS usage_events,
  ROUND(SUM(CASE WHEN ur.usage_type = 'DATA' THEN ur.units ELSE 0 END) / 1024, 2) AS data_gb,
  SUM(CASE WHEN ur.usage_type = 'VOICE' THEN ur.units ELSE 0 END) AS voice_minutes,
  RANK() OVER (
    ORDER BY
      ROUND(SUM(CASE WHEN ur.usage_type = 'DATA' THEN ur.units ELSE 0 END) / 1024, 2) DESC
  ) AS data_load_rank
FROM towers t
JOIN tower_technologies tt
  ON tt.tower_id = t.tower_id
JOIN technologies tech
  ON tech.technology_id = tt.technology_id
LEFT JOIN usage_records ur
  ON ur.tower_id = t.tower_id
 AND ur.usage_datetime >= (CURRENT_DATE - INTERVAL 30 DAY)
GROUP BY
  t.city,
  t.tower_code,
  tech.tech_name
ORDER BY
  data_gb DESC,
  usage_events DESC;



-- =================================================
-- Task 5.1 — Identify One Slow / Inefficient Query
-- =================================================

-- Slow query (correlated subquery per subscriber)

-- Analytical goal: For each subscriber, compute DATA usage (MB) in the last 60 days.
SELECT
  s.subscriber_id,
  s.phone_msisdn,
  CONCAT(s.first_name, ' ', s.last_name) AS subscriber_name,
  (
    SELECT COALESCE(SUM(CASE WHEN ur.usage_type = 'DATA' THEN ur.units ELSE 0 END), 0)
    FROM usage_records ur
    WHERE ur.subscriber_id = s.subscriber_id
      AND ur.usage_datetime >= (CURRENT_DATE - INTERVAL 60 DAY)
  ) AS data_mb_last_60d
FROM subscribers s
ORDER BY data_mb_last_60d DESC;


-- =============================================
-- Task 5.2 — Apply Two Optimization Strategies
-- =============================================

-- Strategy A — Add / Adjust Indexes

-- Indexes help MySQL filter and aggregate usage records faster.
CREATE INDEX idx_usage_time_type
ON usage_records (usage_datetime, usage_type);

EXPLAIN
SELECT
  subscriber_id,
  SUM(units) AS data_mb_last_60d
FROM usage_records
WHERE usage_datetime >= (CURRENT_DATE - INTERVAL 60 DAY)
  AND usage_type = 'DATA'
GROUP BY subscriber_id;

-- Strategy B — Rewrite Query to Remove Correlated Subquery

-- aggregate once, then join results to subscribers.
SELECT
  s.subscriber_id,
  s.phone_msisdn,
  CONCAT(s.first_name, ' ', s.last_name) AS subscriber_name,
  COALESCE(u.data_mb_last_60d, 0) AS data_mb_last_60d
FROM subscribers s
LEFT JOIN (
  SELECT
    subscriber_id,
    SUM(CASE WHEN usage_type = 'DATA' THEN units ELSE 0 END) AS data_mb_last_60d
  FROM usage_records
  WHERE usage_datetime >= (CURRENT_DATE - INTERVAL 60 DAY)
  GROUP BY subscriber_id
) u
  ON u.subscriber_id = s.subscriber_id
ORDER BY data_mb_last_60d DESC;



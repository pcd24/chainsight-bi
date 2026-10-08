-- 03_staging/03_staging_orders.sql
-- Order-to-cash: orders, order items, shipments, returns. Children are rejected if their parent was rejected.

-- ---- Orders
CREATE TEMP TABLE t_ord AS
SELECT btrim(o.order_id) AS order_id,
       COALESCE(m.customer_id, btrim(o.customer_id)) AS customer_id,
       staging.parse_date(o.order_date) AS order_date,
       staging.std_order_status(o.order_status) AS order_status,
       staging.clean_text(o.channel) AS channel,
       staging.std_payment(o.payment_method) AS payment_method,
       btrim(o.warehouse_id) AS warehouse_id,
       staging.parse_date(o.promised_delivery_date) AS promised_delivery_date,
       row_number() OVER (PARTITION BY btrim(o.order_id) ORDER BY o.order_date NULLS LAST) AS rn
FROM raw.orders o
LEFT JOIN staging.customer_map m ON m.source_customer_id = btrim(o.customer_id);

CREATE TEMP TABLE t_ord_chk AS
SELECT t.*, CASE
    WHEN t.rn > 1 THEN 'duplicate record removed'
    WHEN t.order_date IS NULL THEN 'missing or invalid order_date'
    WHEN c.customer_id IS NULL THEN 'orphan customer_id'
    WHEN w.warehouse_id IS NULL THEN 'orphan warehouse_id' END AS reject_reason
FROM t_ord t
LEFT JOIN staging.stg_customers c ON c.customer_id = t.customer_id
LEFT JOIN staging.stg_warehouses w ON w.warehouse_id = t.warehouse_id;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'orders', order_id, reject_reason FROM t_ord_chk WHERE reject_reason IS NOT NULL;

CREATE TABLE staging.stg_orders AS
SELECT order_id, customer_id, order_date, order_status, channel, payment_method, warehouse_id, promised_delivery_date
FROM t_ord_chk WHERE reject_reason IS NULL;
ALTER TABLE staging.stg_orders ADD PRIMARY KEY (order_id);

-- ---- Order items
CREATE TEMP TABLE t_oi AS
SELECT btrim(order_item_id) AS order_item_id, btrim(order_id) AS order_id, upper(btrim(product_id)) AS product_id,
       quantity::int AS quantity, unit_price::numeric AS unit_price, discount_pct::numeric AS discount_pct,
       staging.clean_text(promotion_id) AS promotion_id, unit_cost::numeric AS unit_cost,
       row_number() OVER (PARTITION BY btrim(order_item_id) ORDER BY order_item_id) AS rn
FROM raw.order_items;

CREATE TEMP TABLE t_oi_chk AS
SELECT t.*, CASE
    WHEN t.rn > 1 THEN 'duplicate record removed'
    WHEN t.quantity <= 0 THEN 'non-positive quantity'
    WHEN p.product_id IS NULL THEN 'unknown product_id'
    WHEN o.order_id IS NULL THEN 'parent order rejected or missing'
    WHEN t.unit_price <= 0 OR t.discount_pct NOT BETWEEN 0 AND 1 THEN 'invalid price or discount' END AS reject_reason
FROM t_oi t
LEFT JOIN staging.stg_products p ON p.product_id = t.product_id
LEFT JOIN staging.stg_orders o ON o.order_id = t.order_id;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'order_items', order_item_id, reject_reason FROM t_oi_chk WHERE reject_reason IS NOT NULL;

CREATE TABLE staging.stg_order_items AS
SELECT order_item_id, order_id, product_id, quantity, unit_price, discount_pct, promotion_id, unit_cost
FROM t_oi_chk WHERE reject_reason IS NULL;
ALTER TABLE staging.stg_order_items ADD PRIMARY KEY (order_item_id);

-- ---- Shipments
CREATE TEMP TABLE t_sh AS
SELECT btrim(shipment_id) AS shipment_id, btrim(order_id) AS order_id, upper(btrim(carrier_id)) AS carrier_id,
       btrim(warehouse_id) AS warehouse_id, staging.parse_date(ship_date) AS ship_date,
       staging.parse_date(promised_delivery_date) AS promised_delivery_date,
       staging.parse_date(delivered_date) AS delivered_date,
       shipping_cost::numeric AS shipping_cost, weight_kg::numeric AS weight_kg,
       initcap(lower(btrim(shipment_status))) AS shipment_status,
       row_number() OVER (PARTITION BY btrim(shipment_id) ORDER BY shipment_id) AS rn
FROM raw.shipments;

CREATE TEMP TABLE t_sh_chk AS
SELECT t.*, CASE
    WHEN t.rn > 1 THEN 'duplicate record removed'
    WHEN o.order_id IS NULL THEN 'parent order rejected or missing'
    WHEN c.carrier_id IS NULL THEN 'unknown carrier_id'
    WHEN t.ship_date IS NULL THEN 'missing ship_date'
    WHEN t.delivered_date < t.ship_date THEN 'delivered before shipped' END AS reject_reason
FROM t_sh t
LEFT JOIN staging.stg_orders o ON o.order_id = t.order_id
LEFT JOIN staging.stg_carriers c ON c.carrier_id = t.carrier_id;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'shipments', shipment_id, reject_reason FROM t_sh_chk WHERE reject_reason IS NOT NULL;

-- Rows with an unreadable delivered_date are KEPT (the shipment happened) but flagged; delivery KPIs exclude them.
CREATE TABLE staging.stg_shipments AS
SELECT shipment_id, order_id, carrier_id, warehouse_id, ship_date, promised_delivery_date, delivered_date,
       shipping_cost, weight_kg, shipment_status,
       (shipment_status = 'Delivered' AND delivered_date IS NULL) AS delivered_date_missing
FROM t_sh_chk WHERE reject_reason IS NULL;
ALTER TABLE staging.stg_shipments ADD PRIMARY KEY (shipment_id);

-- ---- Returns
CREATE TEMP TABLE t_ret AS
SELECT btrim(return_id) AS return_id, btrim(order_item_id) AS order_item_id, btrim(order_id) AS order_id,
       upper(btrim(product_id)) AS product_id, staging.parse_date(return_date) AS return_date,
       quantity_returned::int AS quantity_returned, initcap(lower(staging.clean_text(return_reason))) AS return_reason,
       refund_amount::numeric AS refund_amount, upper(btrim(restocked)) AS restocked,
       row_number() OVER (PARTITION BY btrim(return_id) ORDER BY return_id) AS rn
FROM raw.returns;

CREATE TEMP TABLE t_ret_chk AS
SELECT t.*, CASE
    WHEN t.rn > 1 THEN 'duplicate record removed'
    WHEN oi.order_item_id IS NULL THEN 'parent order item rejected or missing'
    WHEN t.return_date IS NULL THEN 'missing or invalid return_date'
    WHEN t.return_date < o.order_date THEN 'return_date before order_date'
    WHEN t.quantity_returned <= 0 THEN 'non-positive quantity' END AS reject_reason
FROM t_ret t
LEFT JOIN staging.stg_order_items oi ON oi.order_item_id = t.order_item_id
LEFT JOIN staging.stg_orders o ON o.order_id = oi.order_id;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'returns', return_id, reject_reason FROM t_ret_chk WHERE reject_reason IS NOT NULL;

CREATE TABLE staging.stg_returns AS
SELECT return_id, order_item_id, order_id, product_id, return_date, quantity_returned, return_reason, refund_amount, restocked
FROM t_ret_chk WHERE reject_reason IS NULL;
ALTER TABLE staging.stg_returns ADD PRIMARY KEY (return_id);

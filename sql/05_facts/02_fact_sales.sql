-- 05_facts/02_fact_sales.sql
-- Order-to-cash facts: fact_orders, fact_order_items, fact_shipments, fact_returns.
-- Revenue is "recognised" only for orders that were shipped (Delivered / In Transit).
-- Cancelled and Backordered orders keep their order value (net_amount) so we can measure revenue at risk / lost.

-- ================================================================ fact_orders
-- GRAIN: one row per customer order.
CREATE TABLE dw.fact_orders AS
WITH items AS (
    SELECT order_id, count(*) AS line_count, sum(quantity) AS units,
           -- built from the SAME per-line rounded values used in fact_order_items, so the two facts reconcile to the cent
           sum(round(quantity * unit_price, 2)) AS gross_amount,
           sum(round(quantity * unit_price, 2) - round(quantity * unit_price * (1 - discount_pct), 2)) AS discount_amount,
           sum(round(quantity * unit_price * (1 - discount_pct), 2)) AS net_amount,
           sum(round(quantity * unit_cost, 2)) AS cogs_amount
    FROM staging.stg_order_items GROUP BY order_id),
seq AS (
    SELECT order_id, row_number() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS customer_order_seq
    FROM staging.orders_resolved WHERE order_status <> 'Cancelled')
SELECT row_number() OVER (ORDER BY o.order_id)::bigint AS order_key,
       o.order_id,
       dw.date_key(o.order_date) AS order_date_key,
       dw.date_key(o.ship_date) AS ship_date_key,
       dw.date_key(o.promised_delivery_date) AS promised_date_key,
       c.customer_key, w.warehouse_key, st.order_status_key,
       o.channel, o.payment_method,
       1 AS order_count,
       i.line_count, i.units, i.gross_amount, i.discount_amount, i.net_amount, i.cogs_amount,
       i.net_amount - i.cogs_amount AS gross_profit_amount,
       CASE WHEN st.is_revenue_recognized THEN i.net_amount ELSE 0 END AS recognized_revenue,
       CASE WHEN st.is_revenue_recognized THEN i.cogs_amount ELSE 0 END AS recognized_cogs,
       CASE WHEN st.is_revenue_recognized THEN i.net_amount - i.cogs_amount ELSE 0 END AS recognized_gross_profit,
       (o.ship_date - o.order_date) AS days_to_ship,
       ((o.ship_date - o.order_date) > 2)::int AS fulfilment_delayed_flag,
       sq.customer_order_seq,
       CASE WHEN sq.customer_order_seq = 1 THEN 1 ELSE 0 END AS is_first_order,
       CASE WHEN sq.customer_order_seq IS NOT NULL
            THEN (EXTRACT(year FROM o.order_date) * 12 + EXTRACT(month FROM o.order_date))::int
                 - (EXTRACT(year FROM c.cohort_month) * 12 + EXTRACT(month FROM c.cohort_month))::int END AS months_since_first_order,
       o.status_inferred AS status_inferred_flag
FROM staging.orders_resolved o
JOIN items i ON i.order_id = o.order_id
JOIN dw.dim_customer c ON c.customer_id = o.customer_id
JOIN dw.dim_warehouse w ON w.warehouse_id = o.warehouse_id
JOIN dw.dim_order_status st ON st.order_status = o.order_status
LEFT JOIN seq sq ON sq.order_id = o.order_id;
ALTER TABLE dw.fact_orders ADD PRIMARY KEY (order_key);
ALTER TABLE dw.fact_orders ADD CONSTRAINT uq_fact_orders_grain UNIQUE (order_id);

-- ================================================================ fact_order_items
-- GRAIN: one row per product line within an order.
CREATE TABLE dw.fact_order_items AS
SELECT row_number() OVER (ORDER BY i.order_item_id)::bigint AS order_item_key,
       i.order_item_id, f.order_id, f.order_key,
       f.order_date_key, f.ship_date_key, f.customer_key, p.product_key, f.warehouse_key,
       COALESCE(pr.promotion_key, 0) AS promotion_key, f.order_status_key,
       i.quantity, i.unit_price, i.discount_pct,
       round(i.quantity * i.unit_price, 2) AS gross_amount,
       round(i.quantity * i.unit_price, 2) - round(i.quantity * i.unit_price * (1 - i.discount_pct), 2) AS discount_amount,
       round(i.quantity * i.unit_price * (1 - i.discount_pct), 2) AS net_amount,
       round(i.quantity * i.unit_cost, 2) AS cogs_amount,
       round(i.quantity * i.unit_price * (1 - i.discount_pct), 2) - round(i.quantity * i.unit_cost, 2) AS gross_profit_amount,
       CASE WHEN st.is_revenue_recognized THEN round(i.quantity * i.unit_price * (1 - i.discount_pct), 2) ELSE 0 END AS recognized_revenue,
       CASE WHEN st.is_revenue_recognized THEN round(i.quantity * i.unit_cost, 2) ELSE 0 END AS recognized_cogs,
       CASE WHEN st.is_revenue_recognized THEN round(i.quantity * i.unit_price * (1 - i.discount_pct), 2) - round(i.quantity * i.unit_cost, 2) ELSE 0 END AS recognized_gross_profit,
       f.days_to_ship, f.fulfilment_delayed_flag
FROM staging.stg_order_items i
JOIN dw.fact_orders f ON f.order_id = i.order_id
JOIN dw.dim_product p ON p.product_id = i.product_id
JOIN dw.dim_order_status st ON st.order_status_key = f.order_status_key
LEFT JOIN dw.dim_promotion pr ON pr.promotion_id = i.promotion_id;
ALTER TABLE dw.fact_order_items ADD PRIMARY KEY (order_item_key);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT uq_fact_order_items_grain UNIQUE (order_item_id);

-- ================================================================ fact_shipments
-- GRAIN: one row per shipment (one shipment per shipped order, from one warehouse, with one carrier).
CREATE TABLE dw.fact_shipments AS
SELECT row_number() OVER (ORDER BY s.shipment_id)::bigint AS shipment_key,
       s.shipment_id, s.order_id, fo.order_key,
       fo.order_date_key, dw.date_key(s.ship_date) AS ship_date_key,
       dw.date_key(s.promised_delivery_date) AS promised_date_key, dw.date_key(s.delivered_date) AS delivered_date_key,
       ca.carrier_key, w.warehouse_key, fo.customer_key, cu.location_key AS destination_location_key,
       1 AS shipment_count, s.shipping_cost, s.weight_kg,
       (s.ship_date - o.order_date) AS days_to_ship,
       (s.delivered_date - s.ship_date) AS transit_days,
       (s.delivered_date - o.order_date) AS order_to_delivery_days,
       (s.delivered_date - s.promised_delivery_date) AS days_late,
       CASE WHEN s.delivered_date IS NOT NULL THEN 1 ELSE 0 END AS delivered_flag,
       CASE WHEN s.delivered_date IS NULL THEN NULL WHEN s.delivered_date <= s.promised_delivery_date THEN 1 ELSE 0 END AS on_time_flag,
       CASE WHEN s.delivered_date > s.promised_delivery_date THEN 1 ELSE 0 END AS delayed_flag,
       s.delivered_date_missing AS delivered_date_unreadable_flag
FROM staging.stg_shipments s
JOIN staging.orders_resolved o ON o.order_id = s.order_id
JOIN dw.fact_orders fo ON fo.order_id = s.order_id
JOIN dw.dim_carrier ca ON ca.carrier_id = s.carrier_id
JOIN dw.dim_warehouse w ON w.warehouse_id = s.warehouse_id
JOIN dw.dim_customer cu ON cu.customer_key = fo.customer_key;
ALTER TABLE dw.fact_shipments ADD PRIMARY KEY (shipment_key);
ALTER TABLE dw.fact_shipments ADD CONSTRAINT uq_fact_shipments_grain UNIQUE (shipment_id);

-- ================================================================ fact_returns
-- GRAIN: one row per return record (a return of some quantity of one order line).
CREATE TABLE dw.fact_returns AS
SELECT row_number() OVER (ORDER BY r.return_id)::bigint AS return_key,
       r.return_id, r.order_item_id, oi.order_item_key, oi.order_id,
       dw.date_key(r.return_date) AS return_date_key, oi.order_date_key,
       oi.product_key, oi.customer_key, oi.warehouse_key, rr.return_reason_key,
       r.quantity_returned, r.refund_amount,
       (r.return_date - o.order_date) AS days_to_return,
       CASE WHEN r.restocked = 'Y' THEN 1 ELSE 0 END AS restocked_flag
FROM staging.stg_returns r
JOIN dw.fact_order_items oi ON oi.order_item_id = r.order_item_id
JOIN staging.orders_resolved o ON o.order_id = oi.order_id
JOIN dw.dim_return_reason rr ON rr.return_reason = r.return_reason;
ALTER TABLE dw.fact_returns ADD PRIMARY KEY (return_key);
ALTER TABLE dw.fact_returns ADD CONSTRAINT uq_fact_returns_grain UNIQUE (return_id);

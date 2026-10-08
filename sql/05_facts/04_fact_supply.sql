-- 05_facts/04_fact_supply.sql
-- Procure-to-pay facts: purchases (PO lines) and supplier deliveries (receipts).

-- ================================================================ fact_purchases
-- GRAIN: one row per purchase-order line (one material, one supplier, one plant).
CREATE TABLE dw.fact_purchases AS
WITH rec AS (
    SELECT po_line_id, sum(qty_received) AS qty_received, sum(qty_rejected) AS qty_rejected, min(received_date) AS first_received_date
    FROM staging.stg_supplier_deliveries GROUP BY po_line_id)
SELECT row_number() OVER (ORDER BY po.po_line_id)::bigint AS purchase_key,
       po.po_line_id, po.po_number,
       dw.date_key(po.order_date) AS order_date_key, dw.date_key(po.promised_date) AS promised_date_key,
       dw.date_key(rec.first_received_date) AS first_received_date_key,
       pl.plant_key, s.supplier_key, mt.material_key,
       po.quantity_ordered, po.unit_price,
       round(po.quantity_ordered * po.unit_price, 2) AS ordered_amount,
       round(po.quantity_ordered * mt.standard_cost, 2) AS standard_amount,
       round(po.quantity_ordered * (po.unit_price - mt.standard_cost), 2) AS price_variance_amount,
       (po.promised_date - po.order_date) AS promised_lead_days,
       COALESCE(rec.qty_received, 0) AS qty_received, COALESCE(rec.qty_rejected, 0) AS qty_rejected,
       CASE WHEN rec.po_line_id IS NULL THEN 0 ELSE 1 END AS received_flag,
       CASE WHEN po.supplier_missing THEN 1 ELSE 0 END AS supplier_missing_flag
FROM staging.stg_purchase_orders po
JOIN dw.dim_plant pl ON pl.plant_id = po.plant_id
JOIN dw.dim_supplier s ON s.supplier_id = po.supplier_id
JOIN dw.dim_material mt ON mt.material_id = po.material_id
LEFT JOIN rec ON rec.po_line_id = po.po_line_id;
ALTER TABLE dw.fact_purchases ADD PRIMARY KEY (purchase_key);
ALTER TABLE dw.fact_purchases ADD CONSTRAINT uq_fact_purchases_grain UNIQUE (po_line_id);

-- ================================================================ fact_supplier_deliveries
-- GRAIN: one row per delivery receipt against a purchase-order line.
CREATE TABLE dw.fact_supplier_deliveries AS
SELECT row_number() OVER (ORDER BY d.receipt_id)::bigint AS delivery_key,
       d.receipt_id, fp.purchase_key, fp.po_line_id, fp.po_number,
       dw.date_key(d.received_date) AS received_date_key, fp.order_date_key, fp.promised_date_key,
       fp.plant_key, fp.supplier_key, fp.material_key,
       1 AS delivery_count,
       fp.quantity_ordered, d.qty_received, d.qty_rejected, d.qty_received - d.qty_rejected AS qty_accepted,
       round(d.qty_received * fp.unit_price, 2) AS received_value,
       round(d.qty_rejected * fp.unit_price, 2) AS rejected_value,
       fp.promised_lead_days,
       (d.received_date - po.order_date) AS actual_lead_days,
       (d.received_date - po.promised_date) AS days_late,
       CASE WHEN d.received_date <= po.promised_date THEN 1 ELSE 0 END AS on_time_flag,
       CASE WHEN d.received_date > po.promised_date THEN 1 ELSE 0 END AS late_flag,
       CASE WHEN d.qty_received >= fp.quantity_ordered THEN 1 ELSE 0 END AS in_full_flag
FROM staging.stg_supplier_deliveries d
JOIN staging.stg_purchase_orders po ON po.po_line_id = d.po_line_id
JOIN dw.fact_purchases fp ON fp.po_line_id = d.po_line_id;
ALTER TABLE dw.fact_supplier_deliveries ADD PRIMARY KEY (delivery_key);
ALTER TABLE dw.fact_supplier_deliveries ADD CONSTRAINT uq_fact_supplier_deliveries_grain UNIQUE (receipt_id);

-- 03_staging/04_staging_supply.sql
-- Inventory snapshots, purchase orders and supplier deliveries.

-- ---- Finished-goods inventory snapshots (weekly, per product per warehouse)
CREATE TEMP TABLE t_inv AS
SELECT staging.parse_date(snapshot_date) AS snapshot_date, btrim(warehouse_id) AS warehouse_id,
       upper(btrim(product_id)) AS product_id, qty_on_hand::int AS qty_on_hand,
       qty_backordered::int AS qty_backordered, qty_in_transit::int AS qty_in_transit
FROM raw.inventory_snapshots;

CREATE TEMP TABLE t_inv_rank AS
SELECT t.*, row_number() OVER (PARTITION BY snapshot_date, warehouse_id, product_id ORDER BY qty_on_hand DESC) AS rn
FROM t_inv t;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'inventory_snapshots', snapshot_date || '|' || warehouse_id || '|' || product_id,
       CASE WHEN rn > 1 THEN 'duplicate record removed' WHEN qty_on_hand < 0 THEN 'negative qty_on_hand'
            WHEN snapshot_date IS NULL THEN 'invalid snapshot_date' ELSE 'orphan product or warehouse' END
FROM t_inv_rank r
WHERE rn > 1 OR qty_on_hand < 0 OR qty_backordered < 0 OR qty_in_transit < 0 OR snapshot_date IS NULL
   OR NOT EXISTS (SELECT 1 FROM staging.stg_products p WHERE p.product_id = r.product_id)
   OR NOT EXISTS (SELECT 1 FROM staging.stg_warehouses w WHERE w.warehouse_id = r.warehouse_id);

CREATE TABLE staging.stg_inventory_snapshots AS
SELECT snapshot_date, warehouse_id, product_id, qty_on_hand, qty_backordered, qty_in_transit
FROM t_inv_rank r
WHERE rn = 1 AND qty_on_hand >= 0 AND qty_backordered >= 0 AND qty_in_transit >= 0 AND snapshot_date IS NOT NULL
  AND EXISTS (SELECT 1 FROM staging.stg_products p WHERE p.product_id = r.product_id)
  AND EXISTS (SELECT 1 FROM staging.stg_warehouses w WHERE w.warehouse_id = r.warehouse_id);
ALTER TABLE staging.stg_inventory_snapshots ADD PRIMARY KEY (snapshot_date, warehouse_id, product_id);

CREATE TABLE staging.stg_material_inventory_snapshots AS
SELECT staging.parse_date(snapshot_date) AS snapshot_date, btrim(plant_id) AS plant_id, btrim(material_id) AS material_id,
       qty_on_hand::int AS qty_on_hand, qty_on_order::int AS qty_on_order
FROM raw.material_inventory_snapshots;
ALTER TABLE staging.stg_material_inventory_snapshots ADD PRIMARY KEY (snapshot_date, plant_id, material_id);

-- ---- Purchase orders (a missing supplier is kept and assigned to the 'S000 Unknown Supplier' member)
CREATE TEMP TABLE t_po AS
SELECT btrim(po_line_id) AS po_line_id, staging.clean_text(po_number) AS po_number,
       staging.parse_date(order_date) AS order_date, btrim(plant_id) AS plant_id,
       COALESCE(upper(btrim(supplier_id)), 'S000') AS supplier_id,
       (supplier_id IS NULL OR btrim(supplier_id) = '') AS supplier_missing,
       btrim(material_id) AS material_id, quantity_ordered::int AS quantity_ordered,
       unit_price::numeric AS unit_price, staging.parse_date(promised_date) AS promised_date,
       row_number() OVER (PARTITION BY btrim(po_line_id) ORDER BY po_line_id) AS rn
FROM raw.purchase_orders;

CREATE TEMP TABLE t_po_chk AS
SELECT t.*, CASE
    WHEN t.rn > 1 THEN 'duplicate record removed'
    WHEN t.quantity_ordered <= 0 THEN 'non-positive quantity_ordered'
    WHEN t.order_date IS NULL OR t.promised_date IS NULL OR t.promised_date < t.order_date THEN 'invalid PO dates'
    WHEN m.material_id IS NULL THEN 'unknown material_id'
    WHEN pl.plant_id IS NULL THEN 'unknown plant_id'
    WHEN t.supplier_id <> 'S000' AND s.supplier_id IS NULL THEN 'unknown supplier_id' END AS reject_reason
FROM t_po t
LEFT JOIN staging.stg_materials m ON m.material_id = t.material_id
LEFT JOIN staging.stg_plants pl ON pl.plant_id = t.plant_id
LEFT JOIN staging.stg_suppliers s ON s.supplier_id = t.supplier_id;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'purchase_orders', po_line_id, reject_reason FROM t_po_chk WHERE reject_reason IS NOT NULL;

CREATE TABLE staging.stg_purchase_orders AS
SELECT po_line_id, po_number, order_date, plant_id, supplier_id, supplier_missing, material_id, quantity_ordered,
       unit_price, promised_date
FROM t_po_chk WHERE reject_reason IS NULL;
ALTER TABLE staging.stg_purchase_orders ADD PRIMARY KEY (po_line_id);

-- ---- Supplier deliveries
CREATE TEMP TABLE t_del AS
SELECT btrim(receipt_id) AS receipt_id, btrim(po_line_id) AS po_line_id, staging.parse_date(received_date) AS received_date,
       qty_received::int AS qty_received, qty_rejected::int AS qty_rejected,
       row_number() OVER (PARTITION BY btrim(receipt_id) ORDER BY receipt_id) AS rn
FROM raw.supplier_deliveries;

CREATE TEMP TABLE t_del_chk AS
SELECT t.*, CASE
    WHEN t.rn > 1 THEN 'duplicate record removed'
    WHEN po.po_line_id IS NULL THEN 'parent purchase order rejected or missing'
    WHEN t.received_date IS NULL OR t.received_date < po.order_date THEN 'received_date before PO date or invalid'
    WHEN t.qty_received < 0 OR t.qty_rejected < 0 OR t.qty_rejected > t.qty_received THEN 'impossible quantities' END AS reject_reason
FROM t_del t LEFT JOIN staging.stg_purchase_orders po ON po.po_line_id = t.po_line_id;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'supplier_deliveries', receipt_id, reject_reason FROM t_del_chk WHERE reject_reason IS NOT NULL;

CREATE TABLE staging.stg_supplier_deliveries AS
SELECT receipt_id, po_line_id, received_date, qty_received, qty_rejected FROM t_del_chk WHERE reject_reason IS NULL;
ALTER TABLE staging.stg_supplier_deliveries ADD PRIMARY KEY (receipt_id);

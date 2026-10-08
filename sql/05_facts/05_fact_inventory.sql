-- 05_facts/05_fact_inventory.sql
-- Periodic snapshot facts. Snapshots are taken every Sunday (week-ending).

-- ================================================================ fact_inventory_snapshot
-- GRAIN: one row per product, per warehouse, per weekly snapshot date (finished goods).
-- Derived measures: trailing 4-week demand, days of cover, stock-out / low-stock / excess flags, days since last sale.
CREATE TABLE dw.fact_inventory_snapshot AS
WITH wk AS (   -- units ordered per product per warehouse in the week ending on that Sunday (cancelled orders excluded)
    SELECT o.warehouse_id, i.product_id, (o.order_date + (7 - EXTRACT(isodow FROM o.order_date)::int)) AS week_end,
           sum(i.quantity) AS units
    FROM staging.stg_order_items i JOIN staging.orders_resolved o ON o.order_id = i.order_id
    WHERE o.order_status <> 'Cancelled' GROUP BY 1, 2, 3),
base AS (
    SELECT s.snapshot_date, s.warehouse_id, s.product_id, s.qty_on_hand, s.qty_backordered, s.qty_in_transit,
           COALESCE(wk.units, 0) AS units_ordered_week
    FROM staging.stg_inventory_snapshots s
    LEFT JOIN wk ON wk.warehouse_id = s.warehouse_id AND wk.product_id = s.product_id AND wk.week_end = s.snapshot_date),
win AS (
    SELECT b.*,
           sum(units_ordered_week) OVER (PARTITION BY warehouse_id, product_id ORDER BY snapshot_date
                RANGE BETWEEN INTERVAL '21 days' PRECEDING AND CURRENT ROW) AS demand_4w,
           max(CASE WHEN units_ordered_week > 0 THEN snapshot_date END) OVER (PARTITION BY warehouse_id, product_id
                ORDER BY snapshot_date) AS last_sale_date
    FROM base b),
calc AS (
    SELECT w.*, p.product_key, wh.warehouse_key, sp.launch_date,
           (w.snapshot_date >= sp.launch_date + 30) AS is_active,
           CASE EXTRACT(year FROM w.snapshot_date)::int WHEN 2023 THEN sp.unit_cost_2023 WHEN 2024 THEN sp.unit_cost_2024
                ELSE sp.unit_cost_2025 END AS unit_cost,
           CASE WHEN w.demand_4w > 0 THEN w.qty_on_hand / (w.demand_4w / 28.0) END AS days_of_cover
    FROM win w
    JOIN dw.dim_product p ON p.product_id = w.product_id
    JOIN staging.stg_products sp ON sp.product_id = w.product_id
    JOIN dw.dim_warehouse wh ON wh.warehouse_id = w.warehouse_id)
SELECT row_number() OVER (ORDER BY snapshot_date, warehouse_key, product_key)::bigint AS inventory_key,
       dw.date_key(snapshot_date) AS snapshot_date_key, product_key, warehouse_key,
       qty_on_hand, qty_backordered, qty_in_transit,
       round(qty_on_hand * unit_cost, 2) AS inventory_value,
       units_ordered_week, COALESCE(demand_4w, 0) AS demand_4w,
       round(days_of_cover::numeric, 1) AS days_of_cover,
       (snapshot_date - last_sale_date) AS days_since_last_sale,
       CASE WHEN is_active THEN 1 ELSE 0 END AS active_sku_flag,
       CASE WHEN is_active AND qty_on_hand = 0 THEN 1 ELSE 0 END AS stockout_flag,
       CASE WHEN is_active AND qty_on_hand > 0 AND days_of_cover < 7 THEN 1 ELSE 0 END AS low_stock_flag,
       CASE WHEN is_active AND qty_on_hand >= 10 AND (COALESCE(demand_4w, 0) = 0 OR days_of_cover > 90) THEN 1 ELSE 0 END AS excess_flag,
       CASE WHEN is_active AND qty_on_hand >= 10 AND (COALESCE(demand_4w, 0) = 0 OR days_of_cover > 90)
            THEN GREATEST(0, qty_on_hand - ceil(COALESCE(demand_4w, 0) / 28.0 * 90)::int) ELSE 0 END AS excess_qty,
       round(unit_cost, 2) AS unit_cost,
       CASE WHEN is_active AND qty_on_hand >= 10 AND (COALESCE(demand_4w, 0) = 0 OR days_of_cover > 90)
            THEN round(GREATEST(0, qty_on_hand - ceil(COALESCE(demand_4w, 0) / 28.0 * 90)::int) * unit_cost, 2) ELSE 0 END AS excess_value
FROM calc;
ALTER TABLE dw.fact_inventory_snapshot ADD PRIMARY KEY (inventory_key);
ALTER TABLE dw.fact_inventory_snapshot ADD CONSTRAINT uq_fact_inventory_grain UNIQUE (snapshot_date_key, product_key, warehouse_key);

-- ================================================================ fact_material_inventory_snapshot
-- GRAIN: one row per material, per plant, per weekly snapshot date (raw material stock).
CREATE TABLE dw.fact_material_inventory_snapshot AS
WITH wk AS (
    SELECT fc.plant_key, fc.material_key, (d.full_date + (7 - d.day_of_week_num)) AS week_end, sum(fc.quantity_consumed) AS qty
    FROM dw.fact_material_consumption fc JOIN dw.dim_date d ON d.date_key = fc.date_key GROUP BY 1, 2, 3),
base AS (
    SELECT s.snapshot_date, pl.plant_key, mt.material_key, mt.standard_cost, s.qty_on_hand, s.qty_on_order,
           COALESCE(wk.qty, 0) AS qty_week
    FROM staging.stg_material_inventory_snapshots s
    JOIN dw.dim_plant pl ON pl.plant_id = s.plant_id JOIN dw.dim_material mt ON mt.material_id = s.material_id
    LEFT JOIN wk ON wk.plant_key = pl.plant_key AND wk.material_key = mt.material_key AND wk.week_end = s.snapshot_date),
win AS (
    SELECT b.*, sum(qty_week) OVER (PARTITION BY plant_key, material_key ORDER BY snapshot_date
                RANGE BETWEEN INTERVAL '21 days' PRECEDING AND CURRENT ROW) AS consumption_4w
    FROM base b)
SELECT row_number() OVER (ORDER BY snapshot_date, plant_key, material_key)::bigint AS material_inventory_key,
       dw.date_key(snapshot_date) AS snapshot_date_key, plant_key, material_key, qty_on_hand, qty_on_order,
       round(qty_on_hand * standard_cost, 2) AS inventory_value,
       round(consumption_4w, 1) AS consumption_4w,
       CASE WHEN consumption_4w > 0 THEN round(qty_on_hand / (consumption_4w / 28.0), 1) END AS days_of_supply,
       CASE WHEN consumption_4w > 0 AND qty_on_hand / (consumption_4w / 28.0) < 7 THEN 1 ELSE 0 END AS low_supply_flag
FROM win;
ALTER TABLE dw.fact_material_inventory_snapshot ADD PRIMARY KEY (material_inventory_key);
ALTER TABLE dw.fact_material_inventory_snapshot ADD CONSTRAINT uq_fact_material_inventory_grain UNIQUE (snapshot_date_key, plant_key, material_key);

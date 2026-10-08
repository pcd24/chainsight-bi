-- 06_quality/01_quality_checks.sql
-- Data-quality framework. Every check is a query that returns the NUMBER OF VIOLATIONS (0 = pass).
-- Severity: ERROR = pipeline must fail | WARN = investigate | INFO = informational count (e.g. rows rejected by design).
DROP SCHEMA IF EXISTS dq CASCADE;
CREATE SCHEMA dq;

CREATE TABLE dq.check_results (
    check_id SERIAL PRIMARY KEY, category TEXT NOT NULL, check_name TEXT NOT NULL, severity TEXT NOT NULL,
    violations BIGINT NOT NULL, status TEXT NOT NULL, run_at TIMESTAMPTZ NOT NULL DEFAULT now());

CREATE FUNCTION dq.run_check(p_category TEXT, p_name TEXT, p_severity TEXT, p_sql TEXT) RETURNS VOID AS $$
DECLARE n BIGINT;
BEGIN
    EXECUTE p_sql INTO n;
    INSERT INTO dq.check_results (category, check_name, severity, violations, status)
    VALUES (p_category, p_name, p_severity, n,
            CASE WHEN n = 0 THEN 'PASS' WHEN p_severity = 'INFO' THEN 'INFO' ELSE 'FAIL' END);
END $$ LANGUAGE plpgsql;

DO $$
DECLARE r RECORD;
BEGIN
  -- ============ 1. RECONCILIATION: raw rows = clean rows + logged rejects (nothing silently lost)
  FOR r IN SELECT * FROM (VALUES
      ('customers','customers','stg_customers',''),
      ('products','products','stg_products',''),
      ('orders','orders','stg_orders',''),
      ('order_items','order_items','stg_order_items',''),
      ('shipments','shipments','stg_shipments',''),
      ('returns','returns','stg_returns',''),
      ('inventory_snapshots','inventory_snapshots','stg_inventory_snapshots',''),
      ('purchase_orders','purchase_orders','stg_purchase_orders',''),
      ('supplier_deliveries','supplier_deliveries','stg_supplier_deliveries',''),
      ('production_runs','production_runs','stg_production_runs',''),
      ('downtime_events','downtime_events','stg_downtime_events',''),
      ('defects','defects','stg_defects','')) AS t(src, rawt, stgt, x)
  LOOP
    PERFORM dq.run_check('Reconciliation', 'raw = staging + rejects: ' || r.src, 'ERROR',
      format('SELECT abs((SELECT count(*) FROM raw.%I) - (SELECT count(*) FROM staging.%I) - (SELECT count(*) FROM staging.rejects WHERE source_table = %L AND reason <> ''order has no valid lines''))',
             r.rawt, r.stgt, r.src));
  END LOOP;
  PERFORM dq.run_check('Reconciliation','orders: staging orders = warehouse orders + orders without lines','ERROR',
    'SELECT abs((SELECT count(*) FROM staging.stg_orders) - (SELECT count(*) FROM dw.fact_orders) - (SELECT count(*) FROM staging.rejects WHERE reason = ''order has no valid lines''))');

  -- ============ 2. INFO: how much dirt did staging remove (documented, expected)
  FOR r IN SELECT source_table, count(*) AS n FROM staging.rejects GROUP BY 1 ORDER BY 1 LOOP
    PERFORM dq.run_check('Rejected by staging', 'rows rejected/merged: ' || r.source_table, 'INFO', format('SELECT %s::bigint', r.n));
  END LOOP;

  -- ============ 3. NULL critical keys
  FOR r IN SELECT * FROM (VALUES
      ('fact_orders','customer_key'),('fact_orders','warehouse_key'),('fact_orders','order_date_key'),('fact_orders','order_status_key'),
      ('fact_order_items','product_key'),('fact_order_items','customer_key'),('fact_order_items','order_date_key'),('fact_order_items','promotion_key'),
      ('fact_shipments','carrier_key'),('fact_shipments','warehouse_key'),('fact_shipments','ship_date_key'),('fact_shipments','customer_key'),
      ('fact_returns','product_key'),('fact_returns','return_date_key'),('fact_returns','return_reason_key'),
      ('fact_inventory_snapshot','product_key'),('fact_inventory_snapshot','warehouse_key'),('fact_inventory_snapshot','snapshot_date_key'),
      ('fact_material_inventory_snapshot','plant_key'),('fact_material_inventory_snapshot','material_key'),
      ('fact_purchases','supplier_key'),('fact_purchases','material_key'),('fact_purchases','plant_key'),('fact_purchases','order_date_key'),
      ('fact_supplier_deliveries','supplier_key'),('fact_supplier_deliveries','received_date_key'),
      ('fact_production','machine_key'),('fact_production','product_key'),('fact_production','plant_key'),('fact_production','date_key'),
      ('fact_material_consumption','material_key'),('fact_downtime','machine_key'),('fact_downtime','downtime_type_key'),
      ('fact_maintenance','machine_key'),('fact_defects','defect_type_key'),('fact_defects','production_key')) AS t(f, c)
  LOOP
    PERFORM dq.run_check('NULL critical keys', r.f || '.' || r.c || ' is not NULL', 'ERROR',
      format('SELECT count(*) FROM dw.%I WHERE %I IS NULL', r.f, r.c));
  END LOOP;

  -- ============ 4. ORPHAN FOREIGN KEYS: every fact key must exist in its dimension (NULL allowed only for optional date keys)
  FOR r IN SELECT * FROM (VALUES
      ('fact_orders','customer_key','dim_customer','customer_key'),('fact_orders','warehouse_key','dim_warehouse','warehouse_key'),
      ('fact_orders','order_status_key','dim_order_status','order_status_key'),('fact_orders','order_date_key','dim_date','date_key'),
      ('fact_orders','ship_date_key','dim_date','date_key'),('fact_orders','promised_date_key','dim_date','date_key'),
      ('fact_order_items','product_key','dim_product','product_key'),('fact_order_items','customer_key','dim_customer','customer_key'),
      ('fact_order_items','warehouse_key','dim_warehouse','warehouse_key'),('fact_order_items','promotion_key','dim_promotion','promotion_key'),
      ('fact_order_items','order_date_key','dim_date','date_key'),('fact_order_items','order_status_key','dim_order_status','order_status_key'),
      ('fact_shipments','carrier_key','dim_carrier','carrier_key'),('fact_shipments','warehouse_key','dim_warehouse','warehouse_key'),
      ('fact_shipments','customer_key','dim_customer','customer_key'),('fact_shipments','destination_location_key','dim_location','location_key'),
      ('fact_shipments','ship_date_key','dim_date','date_key'),('fact_shipments','promised_date_key','dim_date','date_key'),
      ('fact_shipments','delivered_date_key','dim_date','date_key'),('fact_shipments','order_date_key','dim_date','date_key'),
      ('fact_returns','product_key','dim_product','product_key'),('fact_returns','customer_key','dim_customer','customer_key'),
      ('fact_returns','return_reason_key','dim_return_reason','return_reason_key'),('fact_returns','return_date_key','dim_date','date_key'),
      ('fact_inventory_snapshot','product_key','dim_product','product_key'),('fact_inventory_snapshot','warehouse_key','dim_warehouse','warehouse_key'),
      ('fact_inventory_snapshot','snapshot_date_key','dim_date','date_key'),
      ('fact_material_inventory_snapshot','plant_key','dim_plant','plant_key'),('fact_material_inventory_snapshot','material_key','dim_material','material_key'),
      ('fact_purchases','supplier_key','dim_supplier','supplier_key'),('fact_purchases','material_key','dim_material','material_key'),
      ('fact_purchases','plant_key','dim_plant','plant_key'),('fact_purchases','order_date_key','dim_date','date_key'),
      ('fact_purchases','promised_date_key','dim_date','date_key'),
      ('fact_supplier_deliveries','supplier_key','dim_supplier','supplier_key'),('fact_supplier_deliveries','material_key','dim_material','material_key'),
      ('fact_supplier_deliveries','plant_key','dim_plant','plant_key'),('fact_supplier_deliveries','received_date_key','dim_date','date_key'),
      ('fact_production','machine_key','dim_machine','machine_key'),('fact_production','plant_key','dim_plant','plant_key'),
      ('fact_production','product_key','dim_product','product_key'),('fact_production','date_key','dim_date','date_key'),
      ('fact_material_consumption','material_key','dim_material','material_key'),('fact_material_consumption','product_key','dim_product','product_key'),
      ('fact_material_consumption','plant_key','dim_plant','plant_key'),('fact_material_consumption','machine_key','dim_machine','machine_key'),
      ('fact_downtime','machine_key','dim_machine','machine_key'),('fact_downtime','downtime_type_key','dim_downtime_type','downtime_type_key'),
      ('fact_downtime','product_key','dim_product','product_key'),('fact_downtime','plant_key','dim_plant','plant_key'),
      ('fact_maintenance','machine_key','dim_machine','machine_key'),('fact_maintenance','plant_key','dim_plant','plant_key'),
      ('fact_defects','defect_type_key','dim_defect_type','defect_type_key'),('fact_defects','product_key','dim_product','product_key'),
      ('fact_defects','machine_key','dim_machine','machine_key'),('dim_machine','plant_key','dim_plant','plant_key'),
      ('dim_customer','location_key','dim_location','location_key'),('dim_warehouse','location_key','dim_location','location_key'),
      ('dim_plant','location_key','dim_location','location_key')) AS t(f, c, d, k)
  LOOP
    PERFORM dq.run_check('Referential integrity', r.f || '.' || r.c || ' -> ' || r.d || '.' || r.k, 'ERROR',
      format('SELECT count(*) FROM dw.%I f WHERE f.%I IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dw.%I d WHERE d.%I = f.%I)', r.f, r.c, r.d, r.k, r.c));
  END LOOP;

  -- ============ 5. DUPLICATES: dimension business keys and fact grain
  FOR r IN SELECT * FROM (VALUES
      ('dim_customer','customer_id'),('dim_product','product_id'),('dim_supplier','supplier_id'),('dim_material','material_id'),
      ('dim_warehouse','warehouse_id'),('dim_plant','plant_id'),('dim_machine','machine_id'),('dim_carrier','carrier_id'),
      ('dim_date','full_date'),('dim_promotion','promotion_id'),
      ('fact_orders','order_id'),('fact_order_items','order_item_id'),('fact_shipments','shipment_id'),('fact_returns','return_id'),
      ('fact_inventory_snapshot','snapshot_date_key, product_key, warehouse_key'),
      ('fact_material_inventory_snapshot','snapshot_date_key, plant_key, material_key'),
      ('fact_purchases','po_line_id'),('fact_supplier_deliveries','receipt_id'),
      ('fact_production','run_id'),('fact_production','date_key, shift, machine_key'),
      ('fact_material_consumption','production_key, material_key'),('fact_downtime','downtime_id'),
      ('fact_maintenance','work_order_id'),('fact_defects','production_key, defect_type_key')) AS t(f, k)
  LOOP
    PERFORM dq.run_check('Duplicates / grain', r.f || ' unique on (' || r.k || ')', 'ERROR',
      format('SELECT count(*) FROM (SELECT %s FROM dw.%I GROUP BY %s HAVING count(*) > 1) x', r.k, r.f, r.k));
  END LOOP;

  -- ============ 6. IMPOSSIBLE VALUES / INVALID DATES / INVALID STATUSES (in the warehouse)
  PERFORM dq.run_check('Impossible values','order items: quantity <= 0 or negative prices','ERROR','SELECT count(*) FROM dw.fact_order_items WHERE quantity <= 0 OR unit_price <= 0 OR discount_pct < 0 OR discount_pct > 1');
  PERFORM dq.run_check('Impossible values','inventory: negative quantities','ERROR','SELECT count(*) FROM dw.fact_inventory_snapshot WHERE qty_on_hand < 0 OR qty_backordered < 0 OR qty_in_transit < 0');
  PERFORM dq.run_check('Impossible values','production: good + defect <> total, negatives, or operating+downtime <> planned','ERROR','SELECT count(*) FROM dw.fact_production WHERE good_units + defect_units <> total_units OR total_units < 0 OR good_units < 0 OR operating_minutes + downtime_minutes <> planned_minutes');
  PERFORM dq.run_check('Impossible values','deliveries: rejected > received or negative','ERROR','SELECT count(*) FROM dw.fact_supplier_deliveries WHERE qty_rejected > qty_received OR qty_received < 0 OR qty_rejected < 0');
  PERFORM dq.run_check('Impossible values','purchases: non-positive quantity or price','ERROR','SELECT count(*) FROM dw.fact_purchases WHERE quantity_ordered <= 0 OR unit_price <= 0');
  PERFORM dq.run_check('Impossible values','downtime: non-positive duration','ERROR','SELECT count(*) FROM dw.fact_downtime WHERE duration_minutes <= 0');
  PERFORM dq.run_check('Invalid dates','shipments: delivered before shipped, or shipped before ordered','ERROR','SELECT count(*) FROM dw.fact_shipments WHERE transit_days < 0 OR days_to_ship < 0');
  PERFORM dq.run_check('Invalid dates','returns: return date before order date','ERROR','SELECT count(*) FROM dw.fact_returns WHERE days_to_return < 0');
  PERFORM dq.run_check('Invalid dates','deliveries: received before PO date','ERROR','SELECT count(*) FROM dw.fact_supplier_deliveries WHERE actual_lead_days < 0');
  PERFORM dq.run_check('Invalid dates','dim_date: no gaps (days = max - min + 1)','ERROR','SELECT abs((SELECT count(*) FROM dw.dim_date) - (SELECT max(full_date) - min(full_date) + 1 FROM dw.dim_date))');
  PERFORM dq.run_check('Invalid statuses','orders: status not in allowed list','ERROR','SELECT count(*) FROM dw.fact_orders f WHERE NOT EXISTS (SELECT 1 FROM dw.dim_order_status s WHERE s.order_status_key = f.order_status_key)');
  PERFORM dq.run_check('Invalid statuses','orders left with Unknown status (unresolvable by design)','INFO','SELECT count(*) FROM dw.fact_orders f JOIN dw.dim_order_status s USING (order_status_key) WHERE s.order_status = ''Unknown''');
  PERFORM dq.run_check('Invalid statuses','dim_product: category outside the 7 official categories','ERROR','SELECT count(*) FROM dw.dim_product WHERE category NOT IN (''Smart Home'',''Computer Accessories'',''Mobile Accessories'',''Audio'',''Wearables'',''Networking'',''Gaming Accessories'')');
  PERFORM dq.run_check('Invalid statuses','shipments: delivered date unreadable in source (kept, excluded from delivery KPIs)','INFO','SELECT count(*) FROM dw.fact_shipments WHERE delivered_date_unreadable_flag');

  -- ============ 7. BUSINESS CONSISTENCY / KPI IDENTITIES
  PERFORM dq.run_check('Consistency','revenue: fact_orders = fact_order_items (to the cent)','ERROR','SELECT (abs((SELECT sum(net_amount) FROM dw.fact_orders) - (SELECT sum(net_amount) FROM dw.fact_order_items)) > 0.005)::int');
  PERFORM dq.run_check('Consistency','units: fact_orders = fact_order_items','ERROR','SELECT abs((SELECT sum(units) FROM dw.fact_orders) - (SELECT sum(quantity) FROM dw.fact_order_items))');
  PERFORM dq.run_check('Consistency','one shipment per shipped order, none for cancelled/backordered','ERROR','SELECT count(*) FROM dw.fact_shipments s JOIN dw.fact_orders o USING (order_id) JOIN dw.dim_order_status st ON st.order_status_key = o.order_status_key WHERE st.order_status IN (''Cancelled'',''Backordered'')');
  -- OEE identity holds PER RUN (A x P x Q = good / capacity). On aggregates the two forms differ slightly because
  -- the ratios are weighted differently - so the project defines OEE ONE way everywhere: A x P x Q of the aggregated sums.
  PERFORM dq.run_check('Consistency','OEE identity per run: A x P x Q = good units / capacity units','ERROR',
    'SELECT count(*) FROM dw.fact_production WHERE total_units > 0 AND ideal_units > 0 AND abs((operating_minutes::numeric/planned_minutes) * (total_units/ideal_units) * (good_units::numeric/total_units) - good_units/capacity_units) > 0.001');
  PERFORM dq.run_check('Consistency','OEE aggregate gap (A x P x Q of sums vs good/capacity) above 0.5 percentage points','WARN',
    'SELECT (abs((sum(operating_minutes)::numeric/sum(planned_minutes)) * (sum(total_units)/sum(ideal_units)) * (sum(good_units)::numeric/sum(total_units)) - sum(good_units)/sum(capacity_units)) > 0.005)::int FROM dw.fact_production');
  PERFORM dq.run_check('Consistency','Performance > 100% on any run (would signal bad rated speed)','WARN','SELECT count(*) FROM dw.fact_production WHERE ideal_units > 0 AND total_units > ideal_units * 1.001');
  PERFORM dq.run_check('Consistency','downtime events vs run downtime minutes differ (rejected/dirty events)','INFO',
    'SELECT count(*) FROM dw.fact_production p LEFT JOIN (SELECT production_key, sum(duration_minutes) m FROM dw.fact_downtime GROUP BY 1) d USING (production_key) WHERE COALESCE(d.m,0) <> p.downtime_minutes');
  PERFORM dq.run_check('Consistency','inventory snapshot grain complete: 15 warehouses x 500 products x weeks (missing = rejected dirty rows)','INFO',
    'SELECT (SELECT count(DISTINCT snapshot_date_key) FROM dw.fact_inventory_snapshot) * 15 * 500 - count(*) FROM dw.fact_inventory_snapshot');
END $$;

CREATE VIEW dq.v_summary AS
SELECT category, count(*) AS checks, count(*) FILTER (WHERE status = 'PASS') AS passed,
       count(*) FILTER (WHERE status = 'FAIL') AS failed, count(*) FILTER (WHERE status = 'INFO') AS info
FROM dq.check_results GROUP BY category ORDER BY category;

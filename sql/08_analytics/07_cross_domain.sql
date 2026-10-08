-- 08_analytics/07_cross_domain.sql   (Q68-Q81)
-- These queries connect stages of the chain. They show ASSOCIATION; the generated data contains deliberate cause-and-effect
-- patterns, but in a real project correlation here would only tell you where to investigate.

-- Q68 Supplier lateness vs material-shortage downtime, by month (CORR)
-- Business question: when suppliers deliver late, do plants lose time to missing material?
WITH s AS (SELECT d.month_year_sort, 100.0 * sum(late_flag) / count(*) AS late_pct FROM dw.fact_supplier_deliveries f JOIN dw.dim_date d ON d.date_key = f.received_date_key GROUP BY 1),
p AS (SELECT d.month_year_sort, d.month_year, sum(f.material_shortage_minutes) / 60.0 AS shortage_hours, 100.0 * sum(f.material_shortage_minutes) / sum(f.planned_minutes) AS shortage_pct_of_planned
      FROM dw.fact_production f JOIN dw.dim_date d ON d.date_key = f.date_key GROUP BY 1, 2)
SELECT p.month_year, round(s.late_pct, 1) AS supplier_late_pct, round(p.shortage_hours) AS material_shortage_hours, round(p.shortage_pct_of_planned, 2) AS shortage_pct_of_planned_time,
       round((SELECT corr(s2.late_pct, p2.shortage_pct_of_planned)::numeric FROM s s2 JOIN p p2 USING (month_year_sort)), 2) AS correlation_over_all_months
FROM s JOIN p USING (month_year_sort) ORDER BY month_year_sort;

-- Q69 Supplier S001 disruption (Jul-Nov 2024): lateness of S001 vs everyone else, and the effect on products using its main component
-- Business question: Investigation - what happened when one important supplier slipped?
WITH wm AS (SELECT material_key FROM dw.dim_material WHERE material_name = 'WiFi Module WM-200'),
dep AS (SELECT product_key FROM dw.bridge_product_material b JOIN wm USING (material_key))
SELECT d.month_year_sort, d.month_year,
       round(100.0 * avg(sd.late_flag) FILTER (WHERE s.supplier_id = 'S001'), 1) AS s001_late_pct,
       round(100.0 * avg(sd.late_flag) FILTER (WHERE s.supplier_id <> 'S001'), 1) AS other_suppliers_late_pct,
       round(avg(sd.days_late) FILTER (WHERE s.supplier_id = 'S001' AND sd.late_flag = 1), 1) AS s001_avg_days_late
FROM dw.fact_supplier_deliveries sd JOIN dw.dim_supplier s USING (supplier_key) JOIN dw.dim_date d ON d.date_key = sd.received_date_key
JOIN wm USING (material_key) WHERE d.year_num = 2024 GROUP BY 1, 2 ORDER BY 1;

-- Q70 Supplier problem to shelf: monthly material-shortage downtime and warehouse stockout rate for products that use the S001 component (WiFi Module WM-200), vs all other products
-- Business question: Scenario 1 - did the supplier slip reach production and then the warehouse shelf? (Mar 2024 - Mar 2025)
WITH wm AS (SELECT material_key FROM dw.dim_material WHERE material_name = 'WiFi Module WM-200'),
dep AS (SELECT DISTINCT product_key FROM dw.bridge_product_material WHERE material_key IN (SELECT material_key FROM wm)),
inv AS (
    SELECT d.month_year_sort, d.month_year,
           round(100.0 * sum(i.stockout_flag) FILTER (WHERE i.product_key IN (SELECT product_key FROM dep)) / sum(i.active_sku_flag) FILTER (WHERE i.product_key IN (SELECT product_key FROM dep)), 1) AS stockout_pct_dependent_products,
           round(100.0 * sum(i.stockout_flag) FILTER (WHERE i.product_key NOT IN (SELECT product_key FROM dep)) / sum(i.active_sku_flag) FILTER (WHERE i.product_key NOT IN (SELECT product_key FROM dep)), 1) AS stockout_pct_other_products
    FROM dw.fact_inventory_snapshot i JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key WHERE d.full_date BETWEEN DATE '2024-03-01' AND DATE '2025-03-31' GROUP BY 1, 2),
prd AS (
    SELECT d.month_year_sort,
           round(100.0 * sum(f.material_shortage_minutes) FILTER (WHERE f.product_key IN (SELECT product_key FROM dep)) / sum(f.planned_minutes) FILTER (WHERE f.product_key IN (SELECT product_key FROM dep)), 1) AS shortage_pct_planned_time_dependent,
           round(100.0 * sum(f.material_shortage_minutes) FILTER (WHERE f.product_key NOT IN (SELECT product_key FROM dep)) / sum(f.planned_minutes) FILTER (WHERE f.product_key NOT IN (SELECT product_key FROM dep)), 1) AS shortage_pct_planned_time_other
    FROM dw.fact_production f JOIN dw.dim_date d ON d.date_key = f.date_key GROUP BY 1)
SELECT inv.month_year, prd.shortage_pct_planned_time_dependent, prd.shortage_pct_planned_time_other, inv.stockout_pct_dependent_products, inv.stockout_pct_other_products
FROM inv JOIN prd USING (month_year_sort) ORDER BY month_year_sort;

-- Q71 Production vs demand by category and quarter (units made vs units ordered)
-- Business question: is production keeping pace with demand?
WITH prod AS (SELECT p.category, d.quarter_year_sort, d.quarter_year, sum(f.good_units) AS good_units FROM dw.fact_production f JOIN dw.dim_product p USING (product_key) JOIN dw.dim_date d ON d.date_key = f.date_key GROUP BY 1, 2, 3),
dem AS (SELECT p.category, d.quarter_year_sort, sum(oi.quantity) AS units_ordered FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key) JOIN dw.dim_date d ON d.date_key = oi.order_date_key JOIN dw.dim_order_status s USING (order_status_key) WHERE s.order_status <> 'Cancelled' GROUP BY 1, 2)
SELECT prod.category, prod.quarter_year, prod.good_units, dem.units_ordered, prod.good_units - dem.units_ordered AS production_minus_demand,
       round(100.0 * prod.good_units / dem.units_ordered, 1) AS production_pct_of_demand
FROM prod JOIN dem USING (category, quarter_year_sort) ORDER BY prod.category, prod.quarter_year_sort;

-- Q72 Inventory shortages vs fulfilment delay: warehouse-month stockout rate vs share of orders shipped late (CORR)
-- Business question: do stockouts translate into slower dispatch?
WITH inv AS (SELECT i.warehouse_key, d.month_year_sort, 100.0 * sum(stockout_flag) / sum(active_sku_flag) AS stockout_pct FROM dw.fact_inventory_snapshot i JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key GROUP BY 1, 2),
ful AS (SELECT f.warehouse_key, d.month_year_sort, 100.0 * avg(f.fulfilment_delayed_flag) FILTER (WHERE f.days_to_ship IS NOT NULL) AS delayed_dispatch_pct, avg(f.days_to_ship) AS avg_days_to_ship
        FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key GROUP BY 1, 2)
SELECT round(corr(inv.stockout_pct, ful.delayed_dispatch_pct)::numeric, 2) AS corr_stockout_vs_delayed_dispatch, round(corr(inv.stockout_pct, ful.avg_days_to_ship)::numeric, 2) AS corr_stockout_vs_days_to_ship,
       count(*) AS warehouse_months
FROM inv JOIN ful USING (warehouse_key, month_year_sort);

-- Q73 Machine downtime vs production loss: unplanned downtime hours vs output shortfall per machine (CORR)
-- Business question: does downtime really cost output?
WITH m AS (SELECT f.machine_key, sum(f.duration_hours) FILTER (WHERE f.is_planned_flag = 0) AS unplanned_hours, sum(f.lost_units_est) FILTER (WHERE f.is_planned_flag = 0) AS lost_units
           FROM dw.fact_downtime f GROUP BY 1),
o AS (SELECT machine_key, sum(total_units) AS output, sum(capacity_units) AS capacity FROM dw.fact_production GROUP BY 1)
SELECT round(corr(m.unplanned_hours, o.capacity - o.output)::numeric, 2) AS corr_downtime_hours_vs_capacity_gap, round(sum(m.lost_units)) AS est_units_lost_to_unplanned_downtime,
       round(100 * sum(m.lost_units) / sum(o.capacity), 1) AS pct_of_capacity
FROM m JOIN o USING (machine_key);

-- Q74 Manufacturing defects vs product returns: defect-rate quintile vs return rate (NTILE) - association only
-- Business question: do products that come off the line with more defects come back more often?
WITH d AS (SELECT product_key, sum(defect_units)::numeric / sum(total_units) AS defect_rate FROM dw.fact_production GROUP BY 1 HAVING sum(total_units) >= 1000),
s AS (SELECT oi.product_key, sum(oi.quantity) AS delivered_units FROM dw.fact_order_items oi JOIN dw.dim_order_status st USING (order_status_key) WHERE st.order_status = 'Delivered' GROUP BY 1),
r AS (SELECT product_key, sum(quantity_returned) AS returned, sum(quantity_returned) FILTER (WHERE rr.reason_group = 'Quality') AS returned_quality FROM dw.fact_returns f JOIN dw.dim_return_reason rr USING (return_reason_key) GROUP BY 1),
x AS (SELECT d.product_key, d.defect_rate, s.delivered_units, COALESCE(r.returned, 0) AS returned, COALESCE(r.returned_quality, 0) AS returned_quality, NTILE(5) OVER (ORDER BY d.defect_rate) AS defect_quintile
      FROM d JOIN s USING (product_key) LEFT JOIN r USING (product_key))
SELECT defect_quintile, count(*) AS products, round(100 * avg(defect_rate), 2) AS avg_defect_rate_pct, round(100.0 * sum(returned) / sum(delivered_units), 2) AS return_rate_pct,
       round(100.0 * sum(returned_quality) / sum(delivered_units), 2) AS quality_return_rate_pct, round((SELECT corr(defect_rate, returned::numeric / delivered_units)::numeric FROM x), 2) AS correlation_product_level
FROM x GROUP BY 1 ORDER BY 1;

-- Q75 Warehouse performance vs delivery: dispatch speed and delivery on-time by warehouse, 2025
-- Business question: do slower warehouses produce late deliveries?
SELECT w.warehouse_name, round(avg(f.days_to_ship), 2) AS avg_days_to_dispatch, round(100.0 * avg(f.on_time_flag), 1) AS on_time_pct, round(avg(f.order_to_delivery_days), 1) AS avg_days_order_to_delivery,
       count(*) AS shipments
FROM dw.fact_shipments f JOIN dw.dim_warehouse w USING (warehouse_key) JOIN dw.dim_date d ON d.date_key = f.order_date_key WHERE d.year_num = 2025 AND f.on_time_flag IS NOT NULL GROUP BY 1 ORDER BY on_time_pct;

-- Q76 Promotion demand vs inventory: products with the biggest promotion demand spikes and what happened to stock
-- Business question: Scenario 3 - which products ran into supply pressure during promotions?
WITH promo_days AS (SELECT DISTINCT d.date_key FROM dw.dim_promotion pr JOIN dw.dim_date d ON d.full_date BETWEEN pr.start_date AND pr.end_date WHERE pr.promotion_key <> 0 AND pr.promotion_type = 'Event' OR pr.promotion_name LIKE 'Summer Sale%'),
dem AS (SELECT oi.product_key, sum(oi.quantity) FILTER (WHERE oi.order_date_key IN (SELECT date_key FROM promo_days))::numeric / NULLIF(count(DISTINCT oi.order_date_key) FILTER (WHERE oi.order_date_key IN (SELECT date_key FROM promo_days)), 0) AS promo_units_per_day,
               sum(oi.quantity) FILTER (WHERE oi.order_date_key NOT IN (SELECT date_key FROM promo_days))::numeric / NULLIF(count(DISTINCT oi.order_date_key) FILTER (WHERE oi.order_date_key NOT IN (SELECT date_key FROM promo_days)), 0) AS normal_units_per_day
        FROM dw.fact_order_items oi JOIN dw.dim_order_status s USING (order_status_key) WHERE s.order_status <> 'Cancelled' GROUP BY 1),
stk AS (SELECT product_key, 100.0 * sum(stockout_flag) FILTER (WHERE snapshot_date_key IN (SELECT date_key FROM promo_days)) / NULLIF(sum(active_sku_flag) FILTER (WHERE snapshot_date_key IN (SELECT date_key FROM promo_days)), 0) AS stockout_pct_promo_weeks,
               100.0 * sum(stockout_flag) FILTER (WHERE snapshot_date_key NOT IN (SELECT date_key FROM promo_days)) / NULLIF(sum(active_sku_flag) FILTER (WHERE snapshot_date_key NOT IN (SELECT date_key FROM promo_days)), 0) AS stockout_pct_other_weeks
        FROM dw.fact_inventory_snapshot GROUP BY 1)
SELECT p.product_id, p.product_name, p.category, round(dem.promo_units_per_day, 1) AS promo_units_per_day, round(dem.normal_units_per_day, 1) AS normal_units_per_day,
       round(dem.promo_units_per_day / NULLIF(dem.normal_units_per_day, 0), 2) AS demand_uplift_x, round(stk.stockout_pct_promo_weeks, 1) AS stockout_pct_promo, round(stk.stockout_pct_other_weeks, 1) AS stockout_pct_other
FROM dem JOIN stk USING (product_key) JOIN dw.dim_product p USING (product_key) WHERE dem.normal_units_per_day >= 2 ORDER BY demand_uplift_x DESC LIMIT 15;

-- Q77 Demand vs production capacity by plant, 2025 (units ordered for products made there vs capacity and output)
-- Business question: which plants are being asked to make more than they can?
WITH dem AS (SELECT pl.plant_key, sum(oi.quantity) AS units_ordered FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key) JOIN dw.dim_plant pl ON pl.plant_name = p.primary_plant
             JOIN dw.dim_date d ON d.date_key = oi.order_date_key JOIN dw.dim_order_status s USING (order_status_key) WHERE d.year_num = 2025 AND s.order_status <> 'Cancelled' GROUP BY 1),
pr AS (SELECT f.plant_key, sum(f.capacity_units) AS capacity, sum(f.good_units) AS good_units, count(*) AS shifts_run FROM dw.fact_production f JOIN dw.dim_date d ON d.date_key = f.date_key WHERE d.year_num = 2025 GROUP BY 1)
SELECT pl.plant_name, dem.units_ordered, round(pr.capacity) AS scheduled_capacity_units, pr.good_units, round(100.0 * pr.good_units / dem.units_ordered, 1) AS good_output_pct_of_demand,
       (SELECT count(*) FROM dw.dim_machine m WHERE m.plant_key = pl.plant_key) AS machines, round(100.0 * pr.shifts_run / ((SELECT count(*) FROM dw.dim_machine m WHERE m.plant_key = pl.plant_key) * 2 * 365), 1) AS shift_utilisation_pct
FROM dem JOIN pr USING (plant_key) JOIN dw.dim_plant pl USING (plant_key) ORDER BY shift_utilisation_pct DESC;

-- Q78 Supply disruptions vs revenue impact: value of unfulfilled orders vs material-shortage hours by month
-- Business question: how much order value was lost or stuck while plants were short of material?
WITH l AS (SELECT d.month_year_sort, d.month_year, round(sum(f.net_amount) FILTER (WHERE s.order_status IN ('Cancelled', 'Backordered'))) AS value_unfulfilled, round(sum(f.recognized_revenue)) AS revenue
           FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key JOIN dw.dim_order_status s USING (order_status_key) GROUP BY 1, 2),
p AS (SELECT d.month_year_sort, round(sum(material_shortage_minutes) / 60.0) AS shortage_hours FROM dw.fact_production f JOIN dw.dim_date d ON d.date_key = f.date_key GROUP BY 1)
SELECT l.month_year, l.revenue, l.value_unfulfilled, round(100.0 * l.value_unfulfilled / (l.revenue + l.value_unfulfilled), 1) AS unfulfilled_pct, p.shortage_hours,
       round((SELECT corr(l2.value_unfulfilled, p2.shortage_hours)::numeric FROM l l2 JOIN p p2 USING (month_year_sort)), 2) AS correlation_all_months
FROM l JOIN p USING (month_year_sort) ORDER BY month_year_sort;

-- Q79 Scenario 1 drill path: why are deliveries delayed for one product? (picks the product with most unfulfilled/late order lines in 2025)
-- Business question: trace a delayed product through stock, production, material and supplier.
WITH target AS (
    SELECT oi.product_key, p.product_id, p.product_name, count(*) FILTER (WHERE s.order_status IN ('Cancelled', 'Backordered') OR oi.fulfilment_delayed_flag = 1) AS problem_lines, count(*) AS lines
    FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key) JOIN dw.dim_order_status s USING (order_status_key) JOIN dw.dim_date d ON d.date_key = oi.order_date_key
    WHERE d.year_num = 2025 GROUP BY 1, 2, 3 HAVING count(*) >= 300
    ORDER BY (count(*) FILTER (WHERE s.order_status IN ('Cancelled', 'Backordered') OR oi.fulfilment_delayed_flag = 1))::numeric / count(*) DESC LIMIT 1)
SELECT 'Step 1: order lines' AS step, t.product_name AS subject, round(100.0 * t.problem_lines / t.lines, 1)::text || '% of 2025 lines unfulfilled or dispatched late' AS finding FROM target t
UNION ALL
SELECT 'Step 2: warehouse stock', t.product_name, round(100.0 * sum(i.stockout_flag) / sum(i.active_sku_flag), 1)::text || '% of 2025 warehouse-weeks at zero stock' FROM target t JOIN dw.fact_inventory_snapshot i USING (product_key) JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key WHERE d.year_num = 2025 GROUP BY t.product_name
UNION ALL
SELECT 'Step 3: production', t.product_name, 'Plant ran ' || count(*) || ' shifts; ' || round(100.0 * sum(f.total_units) / sum(f.capacity_units), 1) || '% of capacity used; ' || round(sum(f.material_shortage_minutes) / 60.0) || ' h lost to material shortage; ' || round(sum(f.equipment_failure_minutes) / 60.0) || ' h to failures' FROM target t JOIN dw.fact_production f USING (product_key) JOIN dw.dim_date d ON d.date_key = f.date_key WHERE d.year_num = 2025 GROUP BY t.product_name
UNION ALL
(SELECT 'Step 4: supplier/component with most late deliveries', t.product_name, s.supplier_name || ' (' || m.material_name || '): ' || round(100.0 * sum(sd.late_flag) / count(*), 1) || '% of its 2025 deliveries late'
 FROM target t JOIN dw.bridge_product_material b USING (product_key) JOIN dw.dim_material m USING (material_key) JOIN dw.fact_supplier_deliveries sd USING (material_key)
 JOIN dw.dim_supplier s USING (supplier_key) JOIN dw.dim_date d ON d.date_key = sd.received_date_key
 WHERE d.year_num = 2025 GROUP BY t.product_name, s.supplier_name, m.material_name HAVING count(*) >= 10
 ORDER BY sum(sd.late_flag)::numeric / count(*) DESC LIMIT 1);

-- Q80 Scenario 4: fulfilment bottlenecks by plant - unfulfilled/late order lines for products made in each plant, with the plant's own loss drivers (2025)
-- Business question: which operational bottlenecks line up with fulfilment problems?
WITH ord AS (SELECT p.primary_plant AS plant_name, count(*) AS lines, count(*) FILTER (WHERE s.order_status IN ('Cancelled', 'Backordered')) AS unfulfilled, count(*) FILTER (WHERE oi.fulfilment_delayed_flag = 1) AS dispatched_late
             FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key) JOIN dw.dim_order_status s USING (order_status_key) JOIN dw.dim_date d ON d.date_key = oi.order_date_key WHERE d.year_num = 2025 GROUP BY 1),
pr AS (SELECT pl.plant_name, round(100.0 * sum(f.operating_minutes) / sum(f.planned_minutes), 1) AS availability_pct, round(sum(f.material_shortage_minutes) / 60.0) AS shortage_hours, round(sum(f.equipment_failure_minutes) / 60.0) AS failure_hours,
              round(100.0 * count(*) / ((SELECT count(*) FROM dw.dim_machine m WHERE m.plant_key = pl.plant_key) * 2 * 365), 1) AS shift_utilisation_pct
       FROM dw.fact_production f JOIN dw.dim_plant pl USING (plant_key) JOIN dw.dim_date d ON d.date_key = f.date_key WHERE d.year_num = 2025 GROUP BY pl.plant_name, pl.plant_key)
SELECT ord.plant_name, ord.lines, round(100.0 * ord.unfulfilled / ord.lines, 1) AS unfulfilled_pct, round(100.0 * ord.dispatched_late / ord.lines, 1) AS dispatched_late_pct,
       pr.availability_pct, pr.shortage_hours, pr.failure_hours, pr.shift_utilisation_pct
FROM ord JOIN pr USING (plant_name) ORDER BY unfulfilled_pct DESC;

-- Q81 Revenue at risk: order value cancelled or still backordered, by product (top 15), with current supply status
-- Business question: where is demand being lost to supply problems?
SELECT p.product_id, p.product_name, p.category, round(sum(oi.net_amount) FILTER (WHERE s.order_status = 'Cancelled')) AS cancelled_value,
       round(sum(oi.net_amount) FILTER (WHERE s.order_status = 'Backordered')) AS backordered_value, round(sum(oi.net_amount) FILTER (WHERE s.order_status IN ('Cancelled', 'Backordered'))) AS value_not_fulfilled,
       round(100.0 * sum(oi.net_amount) FILTER (WHERE s.order_status IN ('Cancelled', 'Backordered')) / sum(oi.net_amount), 1) AS pct_of_product_demand_value, v.supply_status
FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key) JOIN dw.dim_order_status s USING (order_status_key) JOIN analytics.v_demand_supply_status v USING (product_key)
GROUP BY p.product_id, p.product_name, p.category, v.supply_status ORDER BY value_not_fulfilled DESC LIMIT 15;

-- 08_analytics/00_views.sql
-- Reusable analytical views (created by the pipeline). Power BI imports dw.* tables directly; these views support SQL analysis
-- and the Demand & Supply page, whose logic is easier to express (and audit) in SQL as an "as of last data date" snapshot.
CREATE SCHEMA IF NOT EXISTS analytics;

-- ------------------------------------------------------------------ Demand vs supply position per product
-- As-of date = last inventory snapshot. Definitions (also in docs/kpis.md):
--   avg_daily_demand_90d     units ordered (non-cancelled) in the 90 days to the as-of date / 90
--   expected_demand_30d      same 30-day window one year earlier x company YoY growth (captures seasonality); falls back to 90d run-rate
--   incoming_supply_30d      in-transit stock + average monthly good output of the last 3 months (what the plants normally deliver)
--   demonstrated_capacity_30d  best calendar-month good output in the last 12 months (what the plants have PROVEN they can make)
--   supply_gap               on_hand + incoming - expected demand - backordered (negative = shortage)
CREATE OR REPLACE VIEW analytics.v_demand_supply_product AS
WITH asof AS (
    SELECT max(d.full_date) AS d, max(i.snapshot_date_key) AS k
    FROM dw.fact_inventory_snapshot i JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key),
inv AS (
    SELECT i.product_key, sum(qty_on_hand) AS on_hand, sum(qty_in_transit) AS in_transit, sum(qty_backordered) AS backordered,
           sum(inventory_value) AS inventory_value
    FROM dw.fact_inventory_snapshot i, asof WHERE i.snapshot_date_key = asof.k GROUP BY 1),
dem AS (
    SELECT oi.product_key,
           sum(oi.quantity) FILTER (WHERE d.full_date > asof.d - 90) AS units_90d,
           sum(oi.quantity) FILTER (WHERE d.full_date > asof.d - 365 AND d.full_date <= asof.d - 335) AS units_ly_window,
           sum(oi.quantity) FILTER (WHERE d.full_date > asof.d - 365) AS units_12m,
           sum(oi.quantity) FILTER (WHERE d.full_date <= asof.d - 365 AND d.full_date > asof.d - 730) AS units_prev_12m
    FROM dw.fact_order_items oi JOIN dw.dim_date d ON d.date_key = oi.order_date_key
    JOIN dw.dim_order_status s ON s.order_status_key = oi.order_status_key, asof
    WHERE s.order_status <> 'Cancelled' GROUP BY 1),
growth AS (SELECT sum(units_12m)::numeric / NULLIF(sum(units_prev_12m), 0) AS g FROM dem),
prod_m AS (
    SELECT fp.product_key, d.month_start_date, sum(fp.good_units) AS good
    FROM dw.fact_production fp JOIN dw.dim_date d ON d.date_key = fp.date_key, asof
    WHERE d.full_date > asof.d - 365 AND d.full_date <= asof.d GROUP BY 1, 2),
prod AS (
    SELECT pm.product_key, max(good) AS best_month,
           (SELECT sum(p2.good) FROM prod_m p2, asof WHERE p2.product_key = pm.product_key AND p2.month_start_date > asof.d - 92) / 3.0 AS avg_month_3m
    FROM prod_m pm GROUP BY 1)
SELECT p.product_key, p.product_id, p.product_name, p.category, p.sub_category,
       COALESCE(inv.on_hand, 0) AS on_hand, COALESCE(inv.in_transit, 0) AS in_transit, COALESCE(inv.backordered, 0) AS backordered,
       COALESCE(inv.inventory_value, 0) AS inventory_value,
       round(COALESCE(dem.units_90d, 0) / 90.0, 2) AS avg_daily_demand_90d,
       round(COALESCE(CASE WHEN p.launch_date < (SELECT d FROM asof) - 365 THEN dem.units_ly_window * growth.g END, dem.units_90d / 90.0 * 30), 0) AS expected_demand_30d,
       round(COALESCE(prod.avg_month_3m, 0)) AS avg_monthly_output_3m,
       round(COALESCE(inv.in_transit, 0) + COALESCE(prod.avg_month_3m, 0)) AS incoming_supply_30d,
       COALESCE(prod.best_month, 0) AS demonstrated_capacity_30d,
       round(COALESCE(inv.on_hand, 0) + COALESCE(inv.in_transit, 0) + COALESCE(prod.avg_month_3m, 0)
             - COALESCE(CASE WHEN p.launch_date < (SELECT d FROM asof) - 365 THEN dem.units_ly_window * growth.g END, dem.units_90d / 90.0 * 30)
             - COALESCE(inv.backordered, 0)) AS supply_gap,
       CASE WHEN COALESCE(dem.units_90d, 0) > 0 THEN round(COALESCE(inv.on_hand, 0) / (dem.units_90d / 90.0)) END AS days_of_cover
FROM dw.dim_product p
LEFT JOIN inv ON inv.product_key = p.product_key
LEFT JOIN dem ON dem.product_key = p.product_key
LEFT JOIN prod ON prod.product_key = p.product_key
CROSS JOIN growth;

CREATE OR REPLACE VIEW analytics.v_demand_supply_status AS
SELECT v.*,
       CASE WHEN supply_gap < 0 AND expected_demand_30d > 0.95 * demonstrated_capacity_30d THEN 'Capacity constrained'
            WHEN supply_gap < 0 THEN 'Shortage risk'
            WHEN on_hand >= 20 AND days_of_cover > 120 THEN 'Excess inventory'
            ELSE 'Balanced' END AS supply_status
FROM analytics.v_demand_supply_product v;

-- ------------------------------------------------------------------ Supplier scorecard (all-time)
CREATE OR REPLACE VIEW analytics.v_supplier_scorecard AS
SELECT s.supplier_key, s.supplier_id, s.supplier_name, s.country, s.supplier_tier,
       count(*) AS deliveries, round(sum(d.received_value)) AS spend,
       round(100.0 * avg(d.on_time_flag), 1) AS on_time_pct,
       round(avg(d.actual_lead_days), 1) AS avg_lead_days, round(avg(d.promised_lead_days), 1) AS avg_promised_days,
       round(avg(d.days_late) FILTER (WHERE d.late_flag = 1), 1) AS avg_days_late_when_late,
       round(100.0 * sum(d.qty_rejected) / NULLIF(sum(d.qty_received), 0), 2) AS defect_rate_pct
FROM dw.fact_supplier_deliveries d JOIN dw.dim_supplier s USING (supplier_key)
GROUP BY s.supplier_key, s.supplier_id, s.supplier_name, s.country, s.supplier_tier;

-- ------------------------------------------------------------------ Plant x month OEE
CREATE OR REPLACE VIEW analytics.v_plant_month_oee AS
SELECT pl.plant_name, d.month_start_date, d.month_year,
       sum(f.total_units) AS output, sum(f.good_units) AS good_units,
       round(sum(f.operating_minutes)::numeric / sum(f.planned_minutes), 4) AS availability,
       round(sum(f.total_units) / NULLIF(sum(f.ideal_units), 0), 4) AS performance,
       round(sum(f.good_units)::numeric / NULLIF(sum(f.total_units), 0), 4) AS quality,
       round(sum(f.operating_minutes)::numeric / sum(f.planned_minutes) * sum(f.total_units) / NULLIF(sum(f.ideal_units), 0)
             * sum(f.good_units)::numeric / NULLIF(sum(f.total_units), 0), 4) AS oee
FROM dw.fact_production f JOIN dw.dim_plant pl USING (plant_key) JOIN dw.dim_date d ON d.date_key = f.date_key
GROUP BY pl.plant_name, d.month_start_date, d.month_year;

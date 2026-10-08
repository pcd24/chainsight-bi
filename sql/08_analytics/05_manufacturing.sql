-- 08_analytics/05_manufacturing.sql   (Q48-Q61)
-- OEE is always Availability x Performance x Quality computed from AGGREGATED sums (never an average of run-level ratios).

-- Q48 Production volume by month and category (conditional aggregation)
-- Business question: how much are we making?
SELECT d.month_year_sort, d.month_year, sum(f.total_units) AS units_produced, sum(f.good_units) AS good_units,
       sum(f.good_units) FILTER (WHERE p.category = 'Audio') AS audio, sum(f.good_units) FILTER (WHERE p.category = 'Smart Home') AS smart_home,
       sum(f.good_units) FILTER (WHERE p.category = 'Wearables') AS wearables
FROM dw.fact_production f JOIN dw.dim_date d ON d.date_key = f.date_key JOIN dw.dim_product p USING (product_key) GROUP BY 1, 2 ORDER BY 1;

-- Q49 Capacity utilisation by plant, 2025: shift slots used / shift slots available (2 shifts x machines x days)
-- Business question: do plants have spare machine time?
SELECT pl.plant_name, count(DISTINCT m.machine_key) AS machines, count(*) AS shifts_run,
       count(DISTINCT m.machine_key) * 2 * 365 AS shifts_available, round(100.0 * count(*) / (count(DISTINCT m.machine_key) * 2 * 365), 1) AS capacity_utilisation_pct
FROM dw.fact_production f JOIN dw.dim_plant pl USING (plant_key) JOIN dw.dim_machine m USING (machine_key) JOIN dw.dim_date d ON d.date_key = f.date_key
WHERE d.year_num = 2025 GROUP BY 1 ORDER BY capacity_utilisation_pct DESC;

-- Q50 OEE by plant (Availability, Performance, Quality)
-- Business question: how efficient is each plant and which factor limits it?
SELECT pl.plant_name, sum(f.good_units) AS good_units,
       round(100.0 * sum(f.operating_minutes) / sum(f.planned_minutes), 1) AS availability_pct,
       round(100.0 * sum(f.total_units) / sum(f.ideal_units), 1) AS performance_pct,
       round(100.0 * sum(f.good_units) / sum(f.total_units), 1) AS quality_pct,
       round(100.0 * sum(f.operating_minutes) / sum(f.planned_minutes) * sum(f.total_units) / sum(f.ideal_units) * sum(f.good_units) / sum(f.total_units), 1) AS oee_pct
FROM dw.fact_production f JOIN dw.dim_plant pl USING (plant_key) GROUP BY 1 ORDER BY oee_pct DESC;

-- Q51 OEE trend with month-over-month change (LAG over the view)
-- Business question: is efficiency improving or slipping?
SELECT plant_name, month_year, round(100 * oee, 1) AS oee_pct, round(100 * (oee - LAG(oee) OVER (PARTITION BY plant_name ORDER BY month_start_date)), 1) AS change_pts,
       round(100 * AVG(oee) OVER (PARTITION BY plant_name ORDER BY month_start_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS oee_rolling_3m
FROM analytics.v_plant_month_oee ORDER BY plant_name, month_start_date;

-- Q52 Machine ranking by downtime hours within plant (RANK / PARTITION BY)
-- Business question: which machines lose the most time?
WITH d AS (SELECT m.machine_id, pl.plant_name, m.machine_type, round(sum(f.duration_hours)) AS downtime_hours,
                  round(sum(f.duration_hours) FILTER (WHERE f.is_planned_flag = 0)) AS unplanned_hours
           FROM dw.fact_downtime f JOIN dw.dim_machine m USING (machine_key) JOIN dw.dim_plant pl ON pl.plant_key = f.plant_key GROUP BY 1, 2, 3)
SELECT * FROM (SELECT d.*, RANK() OVER (PARTITION BY plant_name ORDER BY unplanned_hours DESC) AS rank_in_plant FROM d) x WHERE rank_in_plant <= 3 ORDER BY plant_name, rank_in_plant;

-- Q53 Downtime Pareto by cause with cumulative share (SUM OVER)
-- Business question: which few causes explain most lost time?
SELECT t.downtime_type, t.loss_category, round(sum(f.duration_hours)) AS hours, round(100 * sum(f.duration_hours) / sum(sum(f.duration_hours)) OVER (), 1) AS share_pct,
       round(100 * sum(sum(f.duration_hours)) OVER (ORDER BY sum(f.duration_hours) DESC) / sum(sum(f.duration_hours)) OVER (), 1) AS cumulative_pct
FROM dw.fact_downtime f JOIN dw.dim_downtime_type t USING (downtime_type_key) GROUP BY 1, 2 ORDER BY hours DESC;

-- Q54 Failure frequency: equipment failures per 1,000 operating hours, by machine (top 15)
-- Business question: which machines fail abnormally often?
WITH op AS (SELECT machine_key, sum(operating_minutes) / 60.0 AS op_hours FROM dw.fact_production GROUP BY 1),
fl AS (SELECT f.machine_key, count(*) AS failures, sum(f.duration_hours) AS fail_hours FROM dw.fact_downtime f JOIN dw.dim_downtime_type t USING (downtime_type_key) WHERE t.loss_category = 'Equipment failure' GROUP BY 1)
SELECT m.machine_id, pl.plant_name, m.machine_type, fl.failures, round(op.op_hours) AS operating_hours, round(fl.failures / op.op_hours * 1000, 1) AS failures_per_1000h,
       round(fl.fail_hours / fl.failures * 60) AS avg_minutes_per_failure,
       round((fl.failures / op.op_hours * 1000) / (avg(fl.failures / op.op_hours * 1000) OVER ()), 2) AS x_fleet_average
FROM fl JOIN op USING (machine_key) JOIN dw.dim_machine m USING (machine_key) JOIN dw.dim_plant pl USING (plant_key) ORDER BY failures_per_1000h DESC LIMIT 15;

-- Q55 Maintenance frequency and cost by plant: preventive vs corrective
-- Business question: how much maintenance do we do, and how much is reactive?
SELECT pl.plant_name, count(*) AS work_orders, sum(m.corrective_flag) AS corrective, count(*) - sum(m.corrective_flag) AS preventive,
       round(100.0 * sum(m.corrective_flag) / count(*), 1) AS corrective_pct, round(sum(m.cost)) AS recorded_cost, round(avg(m.cost) FILTER (WHERE m.corrective_flag = 1)) AS avg_corrective_cost,
       count(*) FILTER (WHERE m.cost IS NULL) AS orders_missing_cost
FROM dw.fact_maintenance m JOIN dw.dim_plant pl USING (plant_key) GROUP BY 1 ORDER BY corrective_pct DESC;

-- Q56 Defects by category and defect type (with share) and scrap cost
-- Business question: what kinds of defects do we make, and what do they cost?
SELECT p.category, t.defect_type, sum(f.defect_qty) AS defect_units, round(100.0 * sum(f.defect_qty) / sum(sum(f.defect_qty)) OVER (PARTITION BY p.category), 1) AS share_within_category_pct,
       round(sum(f.scrap_cost)) AS scrap_cost
FROM dw.fact_defects f JOIN dw.dim_product p USING (product_key) JOIN dw.dim_defect_type t USING (defect_type_key) GROUP BY 1, 2 ORDER BY 1, defect_units DESC;

-- Q57 Products with a defect rate above 2x their category average (min 1,500 units made)
-- Business question: which products have unusually high defect rates?
WITH pr AS (SELECT p.product_id, p.product_name, p.category, pl.plant_name, sum(f.total_units) AS made, sum(f.defect_units) AS defects FROM dw.fact_production f JOIN dw.dim_product p USING (product_key) JOIN dw.dim_plant pl USING (plant_key) GROUP BY 1, 2, 3, 4),
cat AS (SELECT category, sum(defects)::numeric / sum(made) AS cat_rate FROM pr GROUP BY 1)
SELECT pr.product_id, pr.product_name, pr.category, pr.plant_name, pr.made, round(100.0 * pr.defects / pr.made, 2) AS defect_rate_pct, round(100 * cat.cat_rate, 2) AS category_rate_pct,
       round((pr.defects::numeric / pr.made) / cat.cat_rate, 1) AS x_category
FROM pr JOIN cat USING (category) WHERE pr.made >= 1500 AND pr.defects::numeric / pr.made > 2 * cat.cat_rate ORDER BY x_category DESC;

-- Q58 Production loss from downtime: estimated units lost per machine (top 15)
-- Business question: how much output did downtime cost us? (minutes x rated speed)
SELECT m.machine_id, pl.plant_name, m.machine_type, round(sum(f.duration_hours)) AS downtime_hours, round(sum(f.lost_units_est)) AS est_units_lost,
       round(sum(f.lost_units_est) FILTER (WHERE t.loss_category = 'Equipment failure')) AS lost_to_failures,
       round(sum(f.lost_units_est) FILTER (WHERE t.loss_category = 'Supply')) AS lost_to_material_shortage
FROM dw.fact_downtime f JOIN dw.dim_machine m USING (machine_key) JOIN dw.dim_plant pl ON pl.plant_key = f.plant_key JOIN dw.dim_downtime_type t USING (downtime_type_key)
GROUP BY 1, 2, 3 ORDER BY est_units_lost DESC LIMIT 15;

-- Q59 Production vs capacity by plant and quarter (output as % of planned capacity)
-- Business question: how close to rated capacity do plants run?
SELECT pl.plant_name, d.quarter_year, d.quarter_year_sort, round(sum(f.capacity_units)) AS capacity_units, sum(f.total_units) AS output,
       round(100.0 * sum(f.total_units) / sum(f.capacity_units), 1) AS output_vs_capacity_pct
FROM dw.fact_production f JOIN dw.dim_plant pl USING (plant_key) JOIN dw.dim_date d ON d.date_key = f.date_key GROUP BY 1, 2, 3 ORDER BY 1, 3;

-- Q60 Preventive maintenance vs failures per machine: do machines with less PM fail more?
-- Business question: is maintenance discipline related to failure frequency? (correlation, not causation)
WITH pm AS (SELECT machine_key, count(*) FILTER (WHERE corrective_flag = 0) AS pm_orders FROM dw.fact_maintenance GROUP BY 1),
fl AS (SELECT f.machine_key, count(*) AS failures FROM dw.fact_downtime f JOIN dw.dim_downtime_type t USING (downtime_type_key) WHERE t.loss_category = 'Equipment failure' GROUP BY 1),
x AS (SELECT m.machine_key, COALESCE(pm.pm_orders, 0) AS pm_orders, COALESCE(fl.failures, 0) AS failures, NTILE(4) OVER (ORDER BY COALESCE(pm.pm_orders, 0)) AS pm_quartile
      FROM dw.dim_machine m LEFT JOIN pm USING (machine_key) LEFT JOIN fl USING (machine_key))
SELECT pm_quartile, count(*) AS machines, round(avg(pm_orders), 1) AS avg_pm_orders, round(avg(failures), 1) AS avg_failures,
       round((SELECT corr(pm_orders, failures)::numeric FROM x), 2) AS correlation_all_machines
FROM x GROUP BY 1 ORDER BY 1;

-- Q61 Plant OEE ranking within each year (RANK) and gap to the best plant of that year
-- Business question: how do plants compare year by year? (ordering by the OEE metric defined above)
WITH y AS (SELECT pl.plant_name, d.year_num, sum(f.operating_minutes)::numeric / sum(f.planned_minutes) * sum(f.total_units) / sum(f.ideal_units) * sum(f.good_units)::numeric / sum(f.total_units) AS oee
           FROM dw.fact_production f JOIN dw.dim_plant pl USING (plant_key) JOIN dw.dim_date d ON d.date_key = f.date_key GROUP BY 1, 2)
SELECT year_num, plant_name, round(100 * oee, 1) AS oee_pct, RANK() OVER (PARTITION BY year_num ORDER BY oee DESC) AS oee_rank,
       round(100 * (oee - max(oee) OVER (PARTITION BY year_num)), 1) AS gap_to_top_plant_pts
FROM y ORDER BY year_num, oee_rank;

-- 08_analytics/04_suppliers.sql   (Q39-Q47)
-- Supplier metrics use RECEIVED deliveries. On-time = received on or before the promised date.
-- Performance bands are NEUTRAL labels based on explicit thresholds, not "best/worst" rankings.

-- Q39 Supplier spend: top 15 suppliers and spend concentration
-- Business question: how much do we buy, and how concentrated is it?
SELECT s.supplier_name, s.country, round(sum(fp.ordered_amount)) AS spend, count(*) AS po_lines,
       round(100 * sum(fp.ordered_amount) / sum(sum(fp.ordered_amount)) OVER (), 1) AS spend_share_pct,
       round(100 * sum(sum(fp.ordered_amount)) OVER (ORDER BY sum(fp.ordered_amount) DESC) / sum(sum(fp.ordered_amount)) OVER (), 1) AS cumulative_share_pct
FROM dw.fact_purchases fp JOIN dw.dim_supplier s USING (supplier_key) GROUP BY 1, 2 ORDER BY spend DESC LIMIT 15;

-- Q40 Lead time: actual vs promised, by supplier (min 100 deliveries)
-- Business question: do suppliers deliver in the time they promise?
SELECT supplier_name, deliveries, avg_promised_days, avg_lead_days, round(avg_lead_days - avg_promised_days, 1) AS avg_gap_days
FROM analytics.v_supplier_scorecard WHERE deliveries >= 100 ORDER BY avg_gap_days DESC LIMIT 20;

-- Q41 On-time delivery distribution with neutral performance bands
-- Business question: how many suppliers fall in each delivery-reliability band?
SELECT CASE WHEN on_time_pct >= 90 THEN 'A: 90%+ on time' WHEN on_time_pct >= 80 THEN 'B: 80-90%' WHEN on_time_pct >= 65 THEN 'C: 65-80%' ELSE 'D: below 65%' END AS delivery_band,
       count(*) AS suppliers, sum(deliveries) AS deliveries, round(sum(spend)) AS spend
FROM analytics.v_supplier_scorecard WHERE deliveries >= 100 GROUP BY 1 ORDER BY 1;

-- Q42 Late deliveries by month: share late and average days late (conditional aggregation)
-- Business question: when did supplier reliability deteriorate?
SELECT d.month_year_sort, d.month_year, count(*) AS deliveries, sum(f.late_flag) AS late_deliveries,
       round(100.0 * sum(f.late_flag) / count(*), 1) AS late_pct, round(avg(f.days_late) FILTER (WHERE f.late_flag = 1), 1) AS avg_days_late
FROM dw.fact_supplier_deliveries f JOIN dw.dim_date d ON d.date_key = f.received_date_key GROUP BY 1, 2 ORDER BY 1;

-- Q43 Supplier defect rate: suppliers above 2x the overall rejection rate (HAVING with scalar subquery)
-- Business question: which suppliers send an unusual share of rejected material?
SELECT supplier_name, country, deliveries, defect_rate_pct,
       round((SELECT 100.0 * sum(qty_rejected) / sum(qty_received) FROM dw.fact_supplier_deliveries), 2) AS overall_rate_pct
FROM analytics.v_supplier_scorecard
WHERE deliveries >= 100 AND defect_rate_pct > 2 * (SELECT 100.0 * sum(qty_rejected) / sum(qty_received) FROM dw.fact_supplier_deliveries)
ORDER BY defect_rate_pct DESC;

-- Q44 Supplier risk matrix: delivery reliability vs quality (neutral quadrant labels)
-- Business question: which suppliers combine delivery and quality issues?
WITH m AS (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY on_time_pct) AS med_ot, percentile_cont(0.5) WITHIN GROUP (ORDER BY defect_rate_pct) AS med_def FROM analytics.v_supplier_scorecard WHERE deliveries >= 100)
SELECT CASE WHEN v.on_time_pct >= m.med_ot AND v.defect_rate_pct <= m.med_def THEN '1 Reliable delivery / low rejects'
            WHEN v.on_time_pct < m.med_ot AND v.defect_rate_pct <= m.med_def THEN '2 Delivery risk'
            WHEN v.on_time_pct >= m.med_ot AND v.defect_rate_pct > m.med_def THEN '3 Quality risk'
            ELSE '4 Delivery and quality risk' END AS risk_quadrant,
       count(*) AS suppliers, round(sum(v.spend)) AS spend, round(avg(v.on_time_pct), 1) AS avg_on_time_pct, round(avg(v.defect_rate_pct), 2) AS avg_defect_pct
FROM analytics.v_supplier_scorecard v, m WHERE v.deliveries >= 100 GROUP BY 1 ORDER BY 1;

-- Q45 Material dependency: materials where one supplier supplies 60%+ of spend
-- Business question: where are we exposed to a single supplier?
WITH s AS (SELECT fp.material_key, fp.supplier_key, sum(fp.ordered_amount) AS spend FROM dw.fact_purchases fp GROUP BY 1, 2),
r AS (SELECT *, spend / sum(spend) OVER (PARTITION BY material_key) AS share, ROW_NUMBER() OVER (PARTITION BY material_key ORDER BY spend DESC) AS rn FROM s)
SELECT m.material_name, m.material_family, sup.supplier_name AS main_supplier, round(100 * r.share, 1) AS main_supplier_share_pct,
       (SELECT count(*) FROM dw.bridge_product_material b WHERE b.material_key = r.material_key) AS products_using_material
FROM r JOIN dw.dim_material m USING (material_key) JOIN dw.dim_supplier sup USING (supplier_key)
WHERE r.rn = 1 AND r.share >= 0.60 ORDER BY products_using_material DESC, main_supplier_share_pct DESC LIMIT 20;

-- Q46 Supplier concentration (HHI) by material family
-- Business question: which material families depend on few suppliers? (HHI: <1500 diversified, 1500-2500 moderate, >2500 concentrated)
WITH s AS (SELECT m.material_family, fp.supplier_key, sum(fp.ordered_amount) AS spend FROM dw.fact_purchases fp JOIN dw.dim_material m USING (material_key) GROUP BY 1, 2),
sh AS (SELECT material_family, spend / sum(spend) OVER (PARTITION BY material_family) AS share FROM s)
SELECT material_family, count(*) AS suppliers, round(10000 * sum(share * share)) AS hhi,
       CASE WHEN 10000 * sum(share * share) > 2500 THEN 'Concentrated' WHEN 10000 * sum(share * share) > 1500 THEN 'Moderate' ELSE 'Diversified' END AS concentration
FROM sh GROUP BY 1 ORDER BY hhi DESC;

-- Q47 Purchase cost analysis: price paid vs standard cost by material family and year
-- Business question: is purchasing cost drifting from plan?
SELECT m.material_family, d.year_num, round(sum(fp.ordered_amount)) AS spend, round(sum(fp.price_variance_amount)) AS price_variance,
       round(100 * sum(fp.price_variance_amount) / sum(fp.standard_amount), 1) AS variance_pct
FROM dw.fact_purchases fp JOIN dw.dim_material m USING (material_key) JOIN dw.dim_date d ON d.date_key = fp.order_date_key GROUP BY 1, 2 ORDER BY 1, 2;

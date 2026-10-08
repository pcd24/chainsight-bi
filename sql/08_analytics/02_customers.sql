-- 08_analytics/02_customers.sql   (Q17-Q26)

-- Q17 New vs returning customers per month
-- Business question: is growth coming from acquisition or from existing customers?
SELECT d.month_year_sort, d.month_year,
       count(DISTINCT f.customer_key) AS active_customers,
       count(DISTINCT f.customer_key) FILTER (WHERE f.is_first_order = 1) AS new_customers,
       count(DISTINCT f.customer_key) FILTER (WHERE f.is_first_order = 0) AS returning_customers,
       round(100.0 * count(DISTINCT f.customer_key) FILTER (WHERE f.is_first_order = 0) / count(DISTINCT f.customer_key), 1) AS returning_pct
FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key
WHERE f.customer_order_seq IS NOT NULL GROUP BY 1, 2 ORDER BY 1;

-- Q18 Repeat purchase rate (share of buyers with 2+ orders), by first-order year
-- Business question: how many customers come back?
SELECT extract(year FROM first_order_date)::int AS first_order_year, count(*) AS buyers,
       count(*) FILTER (WHERE lifetime_orders >= 2) AS repeat_buyers,
       round(100.0 * count(*) FILTER (WHERE lifetime_orders >= 2) / count(*), 1) AS repeat_purchase_rate_pct
FROM dw.dim_customer WHERE first_order_date IS NOT NULL GROUP BY 1 ORDER BY 1;

-- Q19 Purchase frequency distribution
-- Business question: how many orders does a typical customer place?
SELECT CASE WHEN lifetime_orders >= 10 THEN '10+' ELSE lifetime_orders::text END AS orders_placed, count(*) AS customers,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct_of_buyers
FROM dw.dim_customer WHERE lifetime_orders > 0 GROUP BY 1, CASE WHEN lifetime_orders >= 10 THEN 10 ELSE lifetime_orders END
ORDER BY CASE WHEN lifetime_orders >= 10 THEN 10 ELSE lifetime_orders END;

-- Q20 Customer value: top 20 customers by lifetime revenue (DENSE_RANK) and value decile (NTILE)
-- Business question: who are the most valuable customers?
WITH v AS (
    SELECT c.customer_key, c.customer_id, c.full_name, c.region, c.customer_segment, count(*) FILTER (WHERE s.is_revenue_recognized) AS orders,
           sum(f.recognized_revenue) AS revenue, sum(f.recognized_gross_profit) AS profit
    FROM dw.fact_orders f JOIN dw.dim_customer c USING (customer_key) JOIN dw.dim_order_status s USING (order_status_key)
    GROUP BY 1, 2, 3, 4, 5 HAVING sum(f.recognized_revenue) > 0)
SELECT DENSE_RANK() OVER (ORDER BY revenue DESC) AS value_rank, NTILE(10) OVER (ORDER BY revenue DESC) AS value_decile,
       customer_id, full_name, region, customer_segment, orders, round(revenue) AS revenue, round(profit) AS gross_profit
FROM v ORDER BY value_rank LIMIT 20;

-- Q21 Customer segment summary
-- Business question: how big and how valuable is each segment? (segments defined in dim_customer, as of 2025-12-31)
SELECT c.customer_segment, count(DISTINCT c.customer_key) AS customers,
       round(sum(f.recognized_revenue)) AS revenue, round(sum(f.recognized_revenue) / count(DISTINCT c.customer_key), 2) AS revenue_per_customer,
       round(100 * sum(f.recognized_revenue) / sum(sum(f.recognized_revenue)) OVER (), 1) AS revenue_share_pct
FROM dw.dim_customer c LEFT JOIN dw.fact_orders f USING (customer_key) GROUP BY 1 ORDER BY revenue DESC NULLS LAST;

-- Q22 Cohort retention: % of each monthly cohort ordering again N months later
-- Business question: do customers stay? (shown for 2024 cohorts, months 0-12)
WITH act AS (
    SELECT c.cohort_month, f.months_since_first_order AS m, count(DISTINCT f.customer_key) AS active
    FROM dw.fact_orders f JOIN dw.dim_customer c USING (customer_key)
    WHERE f.customer_order_seq IS NOT NULL AND c.cohort_month BETWEEN DATE '2024-01-01' AND DATE '2024-12-01' GROUP BY 1, 2),
size AS (SELECT cohort_month, active AS cohort_size FROM act WHERE m = 0)
SELECT to_char(a.cohort_month, 'YYYY-MM') AS cohort, s.cohort_size,
       max(round(100.0 * a.active / s.cohort_size, 1)) FILTER (WHERE a.m = 0) AS m0,
       max(round(100.0 * a.active / s.cohort_size, 1)) FILTER (WHERE a.m = 1) AS m1,
       max(round(100.0 * a.active / s.cohort_size, 1)) FILTER (WHERE a.m = 2) AS m2,
       max(round(100.0 * a.active / s.cohort_size, 1)) FILTER (WHERE a.m = 3) AS m3,
       max(round(100.0 * a.active / s.cohort_size, 1)) FILTER (WHERE a.m = 6) AS m6,
       max(round(100.0 * a.active / s.cohort_size, 1)) FILTER (WHERE a.m = 12) AS m12
FROM act a JOIN size s USING (cohort_month) GROUP BY 1, 2 ORDER BY 1;

-- Q23 Inactive customers: bought 2+ times but nothing in the last 180 days (win-back list)
-- Business question: which valuable customers have gone quiet?
SELECT c.customer_id, c.full_name, c.region, c.lifetime_orders, c.last_order_date, DATE '2025-12-31' - c.last_order_date AS days_inactive,
       round(sum(f.recognized_revenue)) AS lifetime_revenue
FROM dw.dim_customer c JOIN dw.fact_orders f USING (customer_key)
WHERE c.lifetime_orders >= 2 AND DATE '2025-12-31' - c.last_order_date > 180
GROUP BY 1, 2, 3, 4, 5 ORDER BY lifetime_revenue DESC LIMIT 25;

-- Q24 Customers who return products frequently (HAVING + correlated rate)
-- Business question: is there a group of habitual returners?
WITH o AS (SELECT customer_key, sum(quantity) AS units FROM dw.fact_order_items oi JOIN dw.dim_order_status s USING (order_status_key) WHERE s.order_status = 'Delivered' GROUP BY 1),
r AS (SELECT customer_key, sum(quantity_returned) AS returned, count(*) AS return_events FROM dw.fact_returns GROUP BY 1)
SELECT c.customer_id, c.full_name, c.region, o.units AS units_received, r.returned AS units_returned, round(100.0 * r.returned / o.units, 1) AS return_rate_pct
FROM o JOIN r USING (customer_key) JOIN dw.dim_customer c USING (customer_key)
WHERE o.units >= 8 AND r.returned::numeric / o.units >= 0.30 ORDER BY return_rate_pct DESC, units_received DESC LIMIT 25;

-- Q25 Revenue concentration: share of revenue from top 10% / 20% of customers (NTILE)
-- Business question: how dependent are we on a few customers?
WITH v AS (SELECT customer_key, sum(recognized_revenue) AS revenue FROM dw.fact_orders GROUP BY 1 HAVING sum(recognized_revenue) > 0),
t AS (SELECT revenue, NTILE(10) OVER (ORDER BY revenue DESC) AS decile FROM v)
SELECT decile, count(*) AS customers, round(sum(revenue)) AS revenue, round(100 * sum(revenue) / sum(sum(revenue)) OVER (), 1) AS revenue_share_pct,
       round(100 * sum(sum(revenue)) OVER (ORDER BY decile) / sum(sum(revenue)) OVER (), 1) AS cumulative_share_pct
FROM t GROUP BY decile ORDER BY decile;

-- Q26 Days between consecutive orders (LAG) by segment
-- Business question: how often do repeat customers reorder?
WITH g AS (
    SELECT f.customer_key, (d.full_date - LAG(d.full_date) OVER (PARTITION BY f.customer_key ORDER BY d.full_date, f.order_id)) AS gap_days
    FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key WHERE f.customer_order_seq IS NOT NULL)
SELECT c.customer_segment, count(*) AS reorders, round(avg(g.gap_days), 1) AS avg_days_between_orders,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY g.gap_days) AS median_days
FROM g JOIN dw.dim_customer c USING (customer_key) WHERE g.gap_days IS NOT NULL GROUP BY 1 ORDER BY 3;

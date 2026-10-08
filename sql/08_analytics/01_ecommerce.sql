-- 08_analytics/01_ecommerce.sql   (Q01-Q16)
-- Convention: "revenue" = recognised revenue (shipped orders). Cancelled/backordered orders are analysed separately.

-- Q01 Monthly revenue, orders, units, profit and margin
-- Business question: how is the business trending month by month?
SELECT d.month_year_sort, d.month_year,
       count(*) FILTER (WHERE s.is_revenue_recognized) AS shipped_orders,
       count(*) AS orders_placed,
       sum(f.units) FILTER (WHERE s.is_revenue_recognized) AS units_sold,
       round(sum(f.recognized_revenue), 0) AS revenue,
       round(sum(f.recognized_gross_profit), 0) AS gross_profit,
       round(100 * sum(f.recognized_gross_profit) / NULLIF(sum(f.recognized_revenue), 0), 1) AS gross_margin_pct
FROM dw.fact_orders f
JOIN dw.dim_date d ON d.date_key = f.order_date_key
JOIN dw.dim_order_status s USING (order_status_key)
GROUP BY d.month_year_sort, d.month_year ORDER BY d.month_year_sort;

-- Q02 Month-over-month growth in orders and revenue (LAG)
-- Business question: which months grew or shrank versus the month before?
WITH m AS (
    SELECT d.month_year_sort, d.month_year, count(*) AS orders, sum(f.recognized_revenue) AS revenue
    FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key GROUP BY 1, 2)
SELECT month_year, orders, round(revenue) AS revenue,
       round(100.0 * (orders - LAG(orders) OVER w) / NULLIF(LAG(orders) OVER w, 0), 1) AS orders_mom_pct,
       round(100.0 * (revenue - LAG(revenue) OVER w) / NULLIF(LAG(revenue) OVER w, 0), 1) AS revenue_mom_pct
FROM m WINDOW w AS (ORDER BY month_year_sort) ORDER BY month_year_sort;

-- Q03 Year-over-year growth by month (LAG 12)
-- Business question: after removing seasonality, is the business growing?
WITH m AS (
    SELECT d.month_year_sort, d.month_year, sum(f.recognized_revenue) AS revenue, count(*) AS orders
    FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key GROUP BY 1, 2)
SELECT month_year, round(revenue) AS revenue, round(LAG(revenue, 12) OVER w) AS revenue_prev_year,
       round(100.0 * (revenue / NULLIF(LAG(revenue, 12) OVER w, 0) - 1), 1) AS revenue_yoy_pct,
       round(100.0 * (orders::numeric / NULLIF(LAG(orders, 12) OVER w, 0) - 1), 1) AS orders_yoy_pct
FROM m WINDOW w AS (ORDER BY month_year_sort) ORDER BY month_year_sort;

-- Q04 Average order value by year and quarter
-- Business question: are customers spending more per order?
SELECT d.year_num, d.quarter_year, count(*) AS shipped_orders,
       round(sum(f.recognized_revenue) / count(*), 2) AS avg_order_value,
       round(sum(f.units)::numeric / count(*), 2) AS units_per_order
FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key JOIN dw.dim_order_status s USING (order_status_key)
WHERE s.is_revenue_recognized
GROUP BY d.year_num, d.quarter_year, d.quarter_year_sort ORDER BY d.quarter_year_sort;

-- Q05 Top 20 products by revenue (RANK) with margin
-- Business question: which products drive revenue?
SELECT RANK() OVER (ORDER BY sum(oi.recognized_revenue) DESC) AS revenue_rank, p.product_id, p.product_name, p.category,
       sum(oi.quantity) FILTER (WHERE oi.recognized_revenue > 0) AS units, round(sum(oi.recognized_revenue)) AS revenue,
       round(100 * sum(oi.recognized_gross_profit) / NULLIF(sum(oi.recognized_revenue), 0), 1) AS margin_pct
FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key)
GROUP BY p.product_id, p.product_name, p.category ORDER BY revenue_rank LIMIT 20;

-- Q06 Category performance with share of revenue (SUM OVER)
-- Business question: which categories drive revenue and profit, and how healthy are their margins?
SELECT p.category, round(sum(oi.recognized_revenue)) AS revenue,
       round(100 * sum(oi.recognized_revenue) / sum(sum(oi.recognized_revenue)) OVER (), 1) AS revenue_share_pct,
       round(sum(oi.recognized_gross_profit)) AS gross_profit,
       round(100 * sum(oi.recognized_gross_profit) / sum(oi.recognized_revenue), 1) AS margin_pct,
       round(100 * sum(oi.recognized_gross_profit) / sum(sum(oi.recognized_gross_profit)) OVER (), 1) AS profit_share_pct
FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key)
GROUP BY p.category ORDER BY revenue DESC;

-- Q07 Regional sales (customer region) with order value and share
-- Business question: where are we selling?
SELECT c.region, count(*) FILTER (WHERE s.is_revenue_recognized) AS shipped_orders, count(DISTINCT f.customer_key) AS customers,
       round(sum(f.recognized_revenue)) AS revenue, round(sum(f.recognized_revenue) / NULLIF(count(*) FILTER (WHERE s.is_revenue_recognized), 0), 2) AS aov,
       round(100 * sum(f.recognized_gross_profit) / sum(f.recognized_revenue), 1) AS margin_pct,
       round(100 * sum(f.recognized_revenue) / sum(sum(f.recognized_revenue)) OVER (), 1) AS revenue_share_pct
FROM dw.fact_orders f JOIN dw.dim_customer c USING (customer_key) JOIN dw.dim_order_status s USING (order_status_key)
GROUP BY c.region ORDER BY revenue DESC;

-- Q08 Discount vs profitability (CASE bands)
-- Business question: do deeper discounts still make money?
SELECT CASE WHEN discount_pct = 0 THEN '0% (full price)' WHEN discount_pct <= 0.10 THEN '1-10%' WHEN discount_pct <= 0.20 THEN '11-20%' ELSE '21%+' END AS discount_band,
       sum(quantity) AS units, round(sum(recognized_revenue)) AS revenue,
       round(100 * sum(recognized_gross_profit) / NULLIF(sum(recognized_revenue), 0), 1) AS margin_pct,
       round(sum(recognized_gross_profit) / NULLIF(sum(quantity) FILTER (WHERE recognized_revenue > 0), 0), 2) AS profit_per_unit
FROM dw.fact_order_items GROUP BY 1 ORDER BY min(discount_pct);

-- Q09 Return rate by category (returned units / delivered units) and refund value
-- Business question: which categories come back?
WITH sold AS (
    SELECT p.category, sum(oi.quantity) AS units_delivered, sum(oi.net_amount) AS delivered_value
    FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key) JOIN dw.dim_order_status s USING (order_status_key)
    WHERE s.order_status = 'Delivered' GROUP BY 1),
ret AS (
    SELECT p.category, sum(r.quantity_returned) AS units_returned, sum(r.refund_amount) AS refunds
    FROM dw.fact_returns r JOIN dw.dim_product p USING (product_key) GROUP BY 1)
SELECT s.category, s.units_delivered, r.units_returned, round(100.0 * r.units_returned / s.units_delivered, 2) AS return_rate_pct,
       round(r.refunds) AS refund_value, round(100 * r.refunds / s.delivered_value, 2) AS refund_pct_of_revenue
FROM sold s JOIN ret r USING (category) ORDER BY return_rate_pct DESC;

-- Q10 Cancellation and backorder rate by month
-- Business question: how much demand do we lose, and when?
SELECT d.month_year_sort, d.month_year, count(*) AS orders,
       round(100.0 * count(*) FILTER (WHERE s.order_status = 'Cancelled') / count(*), 1) AS cancel_rate_pct,
       round(100.0 * count(*) FILTER (WHERE s.order_status = 'Backordered') / count(*), 1) AS backorder_rate_pct,
       round(sum(f.net_amount) FILTER (WHERE s.order_status IN ('Cancelled', 'Backordered'))) AS value_not_fulfilled
FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key JOIN dw.dim_order_status s USING (order_status_key)
GROUP BY 1, 2 ORDER BY 1;

-- Q11 Revenue contribution by product with cumulative share and ABC class (SUM OVER, running)
-- Business question: how concentrated is revenue? (Pareto)
WITH r AS (
    SELECT p.product_id, p.product_name, p.category, sum(oi.recognized_revenue) AS revenue
    FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key) GROUP BY 1, 2, 3),
c AS (
    SELECT *, sum(revenue) OVER (ORDER BY revenue DESC, product_id) / sum(revenue) OVER () AS cum_share FROM r)
SELECT product_id, product_name, category, round(revenue) AS revenue, round(100 * cum_share, 1) AS cumulative_share_pct,
       CASE WHEN cum_share <= 0.70 THEN 'A (top 70% of revenue)' WHEN cum_share <= 0.90 THEN 'B (next 20%)' ELSE 'C (last 10%)' END AS abc_class
FROM c ORDER BY revenue DESC LIMIT 60;

-- Q12 Promotion effectiveness: revenue, units, margin and discount cost per promotion (conditional aggregation)
-- Business question: do promotions create profitable volume?
SELECT pr.promotion_name, pr.promotion_type, pr.discount_pct AS headline_discount,
       sum(oi.quantity) AS units, round(sum(oi.recognized_revenue)) AS revenue,
       round(sum(oi.discount_amount)) AS discount_given,
       round(100 * sum(oi.recognized_gross_profit) / NULLIF(sum(oi.recognized_revenue), 0), 1) AS margin_pct,
       round(100.0 * count(*) FILTER (WHERE s.order_status IN ('Cancelled', 'Backordered')) / count(*), 1) AS unfulfilled_line_pct
FROM dw.fact_order_items oi JOIN dw.dim_promotion pr USING (promotion_key) JOIN dw.dim_order_status s USING (order_status_key)
WHERE pr.promotion_key <> 0 GROUP BY 1, 2, 3 ORDER BY revenue DESC;

-- Q13 Order status mix by year
-- Business question: how many orders end up delivered, cancelled or still waiting?
SELECT d.year_num, s.order_status, count(*) AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY d.year_num), 1) AS pct_of_year
FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key JOIN dw.dim_order_status s USING (order_status_key)
GROUP BY 1, s.order_status, s.status_sort ORDER BY 1, s.status_sort;

-- Q14 Channel and payment method performance
-- Business question: does channel or payment method change order value or cancellations?
SELECT f.channel, f.payment_method, count(*) AS orders, round(avg(f.net_amount), 2) AS avg_order_value,
       round(100.0 * count(*) FILTER (WHERE s.order_status = 'Cancelled') / count(*), 1) AS cancel_rate_pct
FROM dw.fact_orders f JOIN dw.dim_order_status s USING (order_status_key) GROUP BY 1, 2 ORDER BY 1, orders DESC;

-- Q15 Why did revenue grow while margin fell? Category revenue and margin 2024 vs 2025 (conditional aggregation)
-- Business question: Investigation Scenario 2 - where did margin go?
WITH x AS (
SELECT p.category,
       round(sum(oi.recognized_revenue) FILTER (WHERE d.year_num = 2024)) AS revenue_2024,
       round(sum(oi.recognized_revenue) FILTER (WHERE d.year_num = 2025)) AS revenue_2025,
       round(100 * (sum(oi.recognized_revenue) FILTER (WHERE d.year_num = 2025) / sum(oi.recognized_revenue) FILTER (WHERE d.year_num = 2024) - 1), 1) AS revenue_growth_pct,
       round(100 * sum(oi.recognized_gross_profit) FILTER (WHERE d.year_num = 2024) / sum(oi.recognized_revenue) FILTER (WHERE d.year_num = 2024), 1) AS margin_2024,
       round(100 * sum(oi.recognized_gross_profit) FILTER (WHERE d.year_num = 2025) / sum(oi.recognized_revenue) FILTER (WHERE d.year_num = 2025), 1) AS margin_2025,
       round(100 * (sum(oi.discount_amount) FILTER (WHERE d.year_num = 2025) / sum(oi.gross_amount) FILTER (WHERE d.year_num = 2025)), 1) AS discount_rate_2025,
       round(100 * (sum(oi.discount_amount) FILTER (WHERE d.year_num = 2024) / sum(oi.gross_amount) FILTER (WHERE d.year_num = 2024)), 1) AS discount_rate_2024
FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key) JOIN dw.dim_date d ON d.date_key = oi.order_date_key
GROUP BY p.category)
SELECT *, round(margin_2025 - margin_2024, 1) AS margin_change_pts FROM x ORDER BY margin_change_pts;

-- Q16 Average selling price vs list price, and unit cost trend by category and year
-- Business question: is price realisation or cost inflation squeezing margin?
SELECT d.year_num, p.category, round(avg(oi.unit_price * (1 - oi.discount_pct)), 2) AS avg_selling_price,
       round(avg(oi.unit_price), 2) AS avg_list_price, round(avg(oi.cogs_amount / oi.quantity), 2) AS avg_unit_cost,
       round(100 * (1 - avg(oi.cogs_amount / oi.quantity) / avg(oi.unit_price * (1 - oi.discount_pct))), 1) AS approx_margin_pct
FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key) JOIN dw.dim_date d ON d.date_key = oi.order_date_key
GROUP BY 1, 2 ORDER BY 2, 1;

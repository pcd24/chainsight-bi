-- 08_analytics/03_inventory.sql   (Q27-Q38)
-- Snapshots are weekly (Sundays). "Stockout rate" = share of ACTIVE product-warehouse-weeks with zero stock.

-- Q27 Inventory value trend (last snapshot of each month)
-- Business question: how much cash is tied up in finished goods over time?
WITH ms AS (SELECT d.month_year_sort, d.month_year, max(i.snapshot_date_key) AS last_snap FROM dw.fact_inventory_snapshot i JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key GROUP BY 1, 2)
SELECT ms.month_year, sum(i.inventory_value)::numeric(14,0) AS inventory_value, sum(i.qty_on_hand) AS units_on_hand, sum(i.qty_backordered) AS units_backordered
FROM ms JOIN dw.fact_inventory_snapshot i ON i.snapshot_date_key = ms.last_snap GROUP BY ms.month_year_sort, ms.month_year ORDER BY ms.month_year_sort;

-- Q28 Inventory turnover by category, 2025 (COGS / average inventory value)
-- Business question: how quickly does stock turn into sales?
WITH cogs AS (
    SELECT p.category, sum(oi.recognized_cogs) AS cogs FROM dw.fact_order_items oi JOIN dw.dim_product p USING (product_key)
    JOIN dw.dim_date d ON d.date_key = oi.order_date_key WHERE d.year_num = 2025 GROUP BY 1),
inv AS (
    SELECT category, avg(total_value) AS avg_inventory_value FROM (
        SELECT p.category, i.snapshot_date_key, sum(i.inventory_value) AS total_value FROM dw.fact_inventory_snapshot i
        JOIN dw.dim_product p USING (product_key) JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key WHERE d.year_num = 2025 GROUP BY 1, 2) x GROUP BY 1)
SELECT c.category, round(c.cogs) AS cogs_2025, round(i.avg_inventory_value) AS avg_inventory_value, round(c.cogs / i.avg_inventory_value, 1) AS inventory_turnover,
       round(365 / (c.cogs / i.avg_inventory_value)) AS days_of_inventory
FROM cogs c JOIN inv i USING (category) ORDER BY inventory_turnover DESC;

-- Q29 Days of inventory by warehouse, 2025
-- Business question: which warehouses hold the most stock relative to sales?
WITH cogs AS (SELECT w.warehouse_name, sum(oi.recognized_cogs) AS cogs FROM dw.fact_order_items oi JOIN dw.dim_warehouse w USING (warehouse_key) JOIN dw.dim_date d ON d.date_key = oi.order_date_key WHERE d.year_num = 2025 GROUP BY 1),
inv AS (SELECT warehouse_name, avg(v) AS avg_value FROM (SELECT w.warehouse_name, i.snapshot_date_key, sum(i.inventory_value) AS v FROM dw.fact_inventory_snapshot i JOIN dw.dim_warehouse w USING (warehouse_key) JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key WHERE d.year_num = 2025 GROUP BY 1, 2) x GROUP BY 1)
SELECT c.warehouse_name, round(i.avg_value) AS avg_inventory_value, round(c.cogs) AS cogs_2025, round(i.avg_value / (c.cogs / 365)) AS days_of_inventory
FROM cogs c JOIN inv i USING (warehouse_name) ORDER BY days_of_inventory DESC;

-- Q30 Stockout rate by warehouse, by year (conditional aggregation)
-- Business question: which warehouses run out of stock most often?
SELECT w.warehouse_name, w.region,
       round(100.0 * sum(i.stockout_flag) FILTER (WHERE d.year_num = 2023) / sum(i.active_sku_flag) FILTER (WHERE d.year_num = 2023), 1) AS stockout_pct_2023,
       round(100.0 * sum(i.stockout_flag) FILTER (WHERE d.year_num = 2024) / sum(i.active_sku_flag) FILTER (WHERE d.year_num = 2024), 1) AS stockout_pct_2024,
       round(100.0 * sum(i.stockout_flag) FILTER (WHERE d.year_num = 2025) / sum(i.active_sku_flag) FILTER (WHERE d.year_num = 2025), 1) AS stockout_pct_2025,
       round(100.0 * sum(i.stockout_flag) / sum(i.active_sku_flag), 1) AS stockout_pct_all
FROM dw.fact_inventory_snapshot i JOIN dw.dim_warehouse w USING (warehouse_key) JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key
GROUP BY 1, 2 ORDER BY stockout_pct_all DESC;

-- Q31 Stockout rate by category and quarter
-- Business question: is the stockout problem getting worse, and where?
SELECT d.quarter_year, d.quarter_year_sort, p.category, round(100.0 * sum(i.stockout_flag) / sum(i.active_sku_flag), 1) AS stockout_pct
FROM dw.fact_inventory_snapshot i JOIN dw.dim_product p USING (product_key) JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key
GROUP BY 1, 2, 3 ORDER BY 2, 3;

-- Q32 Low-stock products right now (latest snapshot, under 7 days of cover) with backorders
-- Business question: what should planners expedite today?
WITH last AS (SELECT max(snapshot_date_key) k FROM dw.fact_inventory_snapshot)
SELECT p.product_id, p.product_name, p.category, sum(i.qty_on_hand) AS on_hand, sum(i.qty_in_transit) AS in_transit, sum(i.qty_backordered) AS backordered,
       sum(i.demand_4w) AS demand_last_4w, round(sum(i.qty_on_hand) / NULLIF(sum(i.demand_4w) / 28.0, 0), 1) AS days_of_cover
FROM dw.fact_inventory_snapshot i JOIN dw.dim_product p USING (product_key), last
WHERE i.snapshot_date_key = last.k GROUP BY 1, 2, 3 HAVING sum(i.demand_4w) >= 20 AND sum(i.qty_on_hand) / NULLIF(sum(i.demand_4w) / 28.0, 0) < 7
ORDER BY backordered DESC, days_of_cover LIMIT 25;

-- Q33 Excess inventory by warehouse and category (latest snapshot)
-- Business question: where is stock piling up beyond 90 days of demand?
WITH last AS (SELECT max(snapshot_date_key) k FROM dw.fact_inventory_snapshot)
SELECT w.warehouse_name, p.category, sum(i.excess_qty) AS excess_units, round(sum(i.excess_qty * i.unit_cost)) AS excess_value,
       count(*) FILTER (WHERE i.excess_flag = 1) AS products_in_excess
FROM dw.fact_inventory_snapshot i JOIN dw.dim_warehouse w USING (warehouse_key) JOIN dw.dim_product p USING (product_key), last
WHERE i.snapshot_date_key = last.k AND i.excess_flag = 1 GROUP BY 1, 2 ORDER BY excess_value DESC LIMIT 20;

-- Q34 Inventory aging proxy: days since last sale for stock on hand (latest snapshot)
-- Business question: how much stock has not sold for a long time? (true lot-level age is not in the source data)
WITH last AS (SELECT max(snapshot_date_key) k FROM dw.fact_inventory_snapshot)
SELECT CASE WHEN i.days_since_last_sale IS NULL THEN 'No sale yet' WHEN i.days_since_last_sale <= 30 THEN '0-30 days' WHEN i.days_since_last_sale <= 60 THEN '31-60 days'
            WHEN i.days_since_last_sale <= 90 THEN '61-90 days' WHEN i.days_since_last_sale <= 180 THEN '91-180 days' ELSE '180+ days' END AS age_bucket,
       count(*) AS product_warehouse_rows, sum(i.qty_on_hand) AS units, round(sum(i.inventory_value)) AS value,
       round(100 * sum(i.inventory_value) / sum(sum(i.inventory_value)) OVER (), 1) AS value_share_pct
FROM dw.fact_inventory_snapshot i, last WHERE i.snapshot_date_key = last.k AND i.qty_on_hand > 0 GROUP BY 1 ORDER BY min(COALESCE(i.days_since_last_sale, 9999));

-- Q35 Warehouse scorecard (stockout, low stock, excess, fulfilment speed, delivery on time)
-- Business question: how do the warehouses compare overall in 2025?
WITH inv AS (
    SELECT i.warehouse_key, round(100.0 * sum(stockout_flag) / sum(active_sku_flag), 1) AS stockout_pct, round(100.0 * sum(low_stock_flag) / sum(active_sku_flag), 1) AS low_stock_pct,
           round(100.0 * sum(excess_flag) / sum(active_sku_flag), 1) AS excess_pct, round(sum(inventory_value) / count(DISTINCT snapshot_date_key)) AS avg_inventory_value
    FROM dw.fact_inventory_snapshot i JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key WHERE d.year_num = 2025 GROUP BY 1),
ful AS (
    SELECT f.warehouse_key, round(avg(f.days_to_ship), 2) AS avg_days_to_ship, round(100.0 * count(*) FILTER (WHERE s.order_status IN ('Cancelled', 'Backordered')) / count(*), 1) AS unfulfilled_pct
    FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key JOIN dw.dim_order_status s USING (order_status_key) WHERE d.year_num = 2025 GROUP BY 1)
SELECT w.warehouse_name, w.region, inv.avg_inventory_value, inv.stockout_pct, inv.low_stock_pct, inv.excess_pct, ful.avg_days_to_ship, ful.unfulfilled_pct
FROM dw.dim_warehouse w JOIN inv USING (warehouse_key) JOIN ful USING (warehouse_key) ORDER BY w.warehouse_name;

-- Q36 Product demand vs inventory: products ranked by demand with current cover (uses analytics view)
-- Business question: do the best sellers have enough stock?
SELECT product_id, product_name, category, avg_daily_demand_90d, on_hand, in_transit, backordered, days_of_cover
FROM analytics.v_demand_supply_status ORDER BY avg_daily_demand_90d DESC LIMIT 20;

-- Q37 Supply position summary (view): how many products are balanced, at risk, constrained or in excess?
SELECT supply_status, count(*) AS products, sum(on_hand) AS units_on_hand, round(sum(inventory_value)) AS inventory_value, sum(backordered) AS backordered_units
FROM analytics.v_demand_supply_status GROUP BY 1 ORDER BY products DESC;

-- Q38 Inventory risk matrix: category x warehouse stockout rate vs excess rate in 2025, with a quadrant label
-- Business question: which category-warehouse combinations are in trouble and what kind of trouble?
WITH m AS (
    SELECT w.warehouse_name, p.category, round(100.0 * sum(i.stockout_flag) / sum(i.active_sku_flag), 1) AS stockout_pct, round(100.0 * sum(i.excess_flag) / sum(i.active_sku_flag), 1) AS excess_pct
    FROM dw.fact_inventory_snapshot i JOIN dw.dim_warehouse w USING (warehouse_key) JOIN dw.dim_product p USING (product_key) JOIN dw.dim_date d ON d.date_key = i.snapshot_date_key
    WHERE d.year_num = 2025 GROUP BY 1, 2)
SELECT *, CASE WHEN stockout_pct >= 15 AND excess_pct >= 3 THEN 'Mixed: shortages and excess'
               WHEN stockout_pct >= 15 THEN 'Shortage risk' WHEN excess_pct >= 3 THEN 'Excess risk' ELSE 'Within tolerance' END AS risk_quadrant
FROM m ORDER BY stockout_pct DESC LIMIT 25;

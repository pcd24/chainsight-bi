-- 08_analytics/06_logistics.sql   (Q62-Q67)
-- On-time = delivered on or before the delivery date promised at checkout. Shipments with unreadable delivery dates
-- and shipments still in transit are excluded from on-time and transit-time metrics.

-- Q62 Shipment volume, shipping cost and cost per shipment by month
-- Business question: what does outbound logistics cost us?
SELECT d.month_year_sort, d.month_year, count(*) AS shipments, round(sum(f.shipping_cost)) AS shipping_cost, round(avg(f.shipping_cost), 2) AS cost_per_shipment,
       round(sum(f.shipping_cost) / NULLIF(sum(o.recognized_revenue), 0) * 100, 2) AS cost_pct_of_revenue
FROM dw.fact_shipments f JOIN dw.dim_date d ON d.date_key = f.ship_date_key JOIN dw.fact_orders o USING (order_key) GROUP BY 1, 2 ORDER BY 1;

-- Q63 Carrier performance: on-time %, transit days, cost per kg
-- Business question: how do carriers compare on speed, reliability and cost?
SELECT c.carrier_name, c.service_level, count(*) AS shipments, round(100.0 * avg(f.on_time_flag), 1) AS on_time_pct, round(avg(f.transit_days), 2) AS avg_transit_days,
       round(avg(f.days_late) FILTER (WHERE f.delayed_flag = 1), 1) AS avg_days_late_when_late, round(sum(f.shipping_cost) / sum(f.weight_kg), 2) AS cost_per_kg
FROM dw.fact_shipments f JOIN dw.dim_carrier c USING (carrier_key) GROUP BY 1, 2 ORDER BY on_time_pct DESC;

-- Q64 Regional delivery performance (destination region)
-- Business question: where do customers wait longest?
SELECT l.region, count(*) AS shipments, round(avg(f.order_to_delivery_days), 1) AS avg_days_order_to_delivery, round(avg(f.transit_days), 1) AS avg_transit_days,
       round(100.0 * avg(f.on_time_flag), 1) AS on_time_pct, round(avg(f.days_to_ship), 1) AS avg_days_to_ship
FROM dw.fact_shipments f JOIN dw.dim_location l ON l.location_key = f.destination_location_key GROUP BY 1 ORDER BY on_time_pct;

-- Q65 Delivery time distribution (order date to delivery date)
-- Business question: how long does an order take end to end?
SELECT CASE WHEN order_to_delivery_days <= 3 THEN '1-3 days' WHEN order_to_delivery_days <= 5 THEN '4-5 days' WHEN order_to_delivery_days <= 7 THEN '6-7 days'
            WHEN order_to_delivery_days <= 10 THEN '8-10 days' WHEN order_to_delivery_days <= 14 THEN '11-14 days' ELSE '15+ days' END AS delivery_time_band,
       count(*) AS shipments, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct_of_shipments
FROM dw.fact_shipments WHERE order_to_delivery_days IS NOT NULL GROUP BY 1, CASE WHEN order_to_delivery_days <= 3 THEN 1 WHEN order_to_delivery_days <= 5 THEN 2 WHEN order_to_delivery_days <= 7 THEN 3 WHEN order_to_delivery_days <= 10 THEN 4 WHEN order_to_delivery_days <= 14 THEN 5 ELSE 6 END ORDER BY CASE WHEN order_to_delivery_days <= 3 THEN 1 WHEN order_to_delivery_days <= 5 THEN 2 WHEN order_to_delivery_days <= 7 THEN 3 WHEN order_to_delivery_days <= 10 THEN 4 WHEN order_to_delivery_days <= 14 THEN 5 ELSE 6 END;

-- Q66 Delayed shipments by warehouse and by cause (delay before dispatch vs delay in transit)
-- Business question: are late deliveries a warehouse problem or a carrier problem?
SELECT w.warehouse_name, count(*) FILTER (WHERE f.delayed_flag = 1) AS delayed_shipments, round(100.0 * avg(f.delayed_flag), 1) AS delayed_pct,
       round(avg(f.days_to_ship) FILTER (WHERE f.delayed_flag = 1), 1) AS avg_days_to_dispatch_when_delayed,
       round(avg(f.days_to_ship) FILTER (WHERE f.delayed_flag = 0), 1) AS avg_days_to_dispatch_when_on_time,
       round(avg(f.transit_days) FILTER (WHERE f.delayed_flag = 1), 1) AS avg_transit_when_delayed
FROM dw.fact_shipments f JOIN dw.dim_warehouse w USING (warehouse_key) WHERE f.delivered_flag = 1 AND f.on_time_flag IS NOT NULL GROUP BY 1 ORDER BY delayed_pct DESC;

-- Q67 Shipping cost per kg by carrier and destination region
-- Business question: where is shipping expensive?
SELECT c.carrier_name, l.region, count(*) AS shipments, round(sum(f.shipping_cost) / sum(f.weight_kg), 2) AS cost_per_kg, round(avg(f.shipping_cost), 2) AS avg_cost
FROM dw.fact_shipments f JOIN dw.dim_carrier c USING (carrier_key) JOIN dw.dim_location l ON l.location_key = f.destination_location_key GROUP BY 1, 2 ORDER BY 2, cost_per_kg;

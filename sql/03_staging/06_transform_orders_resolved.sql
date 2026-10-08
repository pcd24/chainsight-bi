-- 03_staging/06_transform_orders_resolved.sql
-- TRANSFORM step: resolve order status. Source rows with an invalid status ('???', 'N/A', ...) become 'Unknown' in staging.
-- If the order has a shipment we can infer the true status from the shipment; otherwise it stays 'Unknown'
-- (we never guess between Cancelled and Backordered).
DELETE FROM staging.rejects WHERE reason = 'order has no valid lines';   -- keeps this script re-runnable
DROP TABLE IF EXISTS staging.orders_resolved;
CREATE TABLE staging.orders_resolved AS
SELECT o.order_id, o.customer_id, o.order_date, o.channel, o.payment_method, o.warehouse_id, o.promised_delivery_date,
       o.order_status AS source_status,
       CASE WHEN o.order_status = 'Unknown' AND s.shipment_id IS NOT NULL
                 THEN CASE WHEN s.shipment_status = 'Delivered' THEN 'Delivered' ELSE 'In Transit' END
            ELSE o.order_status END AS order_status,
       (o.order_status = 'Unknown' AND s.shipment_id IS NOT NULL) AS status_inferred,
       s.shipment_id, s.ship_date
FROM staging.stg_orders o
LEFT JOIN staging.stg_shipments s ON s.order_id = o.order_id
WHERE EXISTS (SELECT 1 FROM staging.stg_order_items i WHERE i.order_id = o.order_id);

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'orders', o.order_id, 'order has no valid lines'
FROM staging.stg_orders o WHERE NOT EXISTS (SELECT 1 FROM staging.stg_order_items i WHERE i.order_id = o.order_id);
ALTER TABLE staging.orders_resolved ADD PRIMARY KEY (order_id);

-- 07_indexes/01_indexes.sql
-- Indexing strategy. The warehouse is READ-HEAVY and loaded in bulk, so indexes are created AFTER loading (faster load)
-- and only where a real query pattern needs them. Primary keys and grain UNIQUE constraints already create indexes.
-- Dimension business keys already have unique indexes (ux_dim_*). We do NOT index every foreign key.

-- Time filters/range scans on the largest fact tables (monthly trends, YTD, date-sliced reports)
CREATE INDEX ix_fo_order_date   ON dw.fact_orders (order_date_key) INCLUDE (customer_key, recognized_revenue);
CREATE INDEX ix_foi_order_date  ON dw.fact_order_items (order_date_key, product_key);          -- revenue by product over time
CREATE INDEX ix_foi_product     ON dw.fact_order_items (product_key, warehouse_key);           -- product/warehouse demand lookups
CREATE INDEX ix_fo_customer     ON dw.fact_orders (customer_key, order_date_key);              -- customer history, repeat purchase, cohort
CREATE INDEX ix_fs_ship_date    ON dw.fact_shipments (ship_date_key, carrier_key);             -- carrier/delivery trends
CREATE INDEX ix_fr_product      ON dw.fact_returns (product_key, return_date_key);             -- return rate by product
-- Inventory snapshot is the biggest table (1.2M rows): grain UNIQUE index is (date, product, warehouse); add the
-- two other access paths: "history of one product in one warehouse" and "latest snapshot per product".
CREATE INDEX ix_fis_prod_wh     ON dw.fact_inventory_snapshot (product_key, warehouse_key, snapshot_date_key);
-- Manufacturing and supply
CREATE INDEX ix_fp_date_machine ON dw.fact_production (date_key, machine_key);
CREATE INDEX ix_fp_product      ON dw.fact_production (product_key, date_key);
CREATE INDEX ix_fp_plant        ON dw.fact_production (plant_key, date_key);
CREATE INDEX ix_fd_machine      ON dw.fact_downtime (machine_key, date_key);
CREATE INDEX ix_fd_production   ON dw.fact_downtime (production_key);                         -- join back to the production run
CREATE INDEX ix_fdef_prod       ON dw.fact_defects (product_key, date_key);
CREATE INDEX ix_fmc_material    ON dw.fact_material_consumption (material_key, date_key);
CREATE INDEX ix_fpu_supplier    ON dw.fact_purchases (supplier_key, order_date_key);
CREATE INDEX ix_fpu_material    ON dw.fact_purchases (material_key, plant_key);
CREATE INDEX ix_fsd_supplier    ON dw.fact_supplier_deliveries (supplier_key, received_date_key);
CREATE INDEX ix_fsd_purchase    ON dw.fact_supplier_deliveries (purchase_key);
CREATE INDEX ix_fm_machine      ON dw.fact_maintenance (machine_key, date_key);
-- Partial index: the "problem rows" analyses (stock-outs) touch only ~10% of the snapshot table
CREATE INDEX ix_fis_stockout    ON dw.fact_inventory_snapshot (snapshot_date_key, warehouse_key) WHERE stockout_flag = 1;
ANALYZE;

-- 05_facts/06_table_comments.sql
-- Table comments hold the purpose and GRAIN of every warehouse table. scripts/generate_data_dictionary.py reads them
-- to build docs/data_dictionary.md, so the documentation can never drift from the database.
COMMENT ON TABLE dw.dim_date IS 'Calendar dimension, one row per day 2023-01-01..2026-12-31 (promised delivery dates run into 2026). Used by every fact (role-playing).';
COMMENT ON TABLE dw.dim_location IS 'City/country/region. Conformed: referenced by customers, warehouses and plants.';
COMMENT ON TABLE dw.dim_customer IS 'One row per real customer (duplicates merged in staging). Includes first-order cohort and as-of-2025-12-31 segment.';
COMMENT ON TABLE dw.dim_product IS 'One row per finished product. Category and sub-category live here (star schema, no separate category table).';
COMMENT ON TABLE dw.dim_supplier IS 'One row per raw-material supplier, plus S000 for purchase orders whose supplier was missing in the source.';
COMMENT ON TABLE dw.dim_material IS 'One row per raw material / component bought from suppliers.';
COMMENT ON TABLE dw.dim_warehouse IS 'One row per finished-goods warehouse (distribution centre).';
COMMENT ON TABLE dw.dim_plant IS 'One row per manufacturing plant.';
COMMENT ON TABLE dw.dim_machine IS 'One row per machine; belongs to one plant and one production line.';
COMMENT ON TABLE dw.dim_carrier IS 'One row per logistics carrier.';
COMMENT ON TABLE dw.dim_promotion IS 'One row per promotion; key 0 = No Promotion.';
COMMENT ON TABLE dw.dim_order_status IS 'Order status with an is_revenue_recognized flag (Delivered, In Transit = TRUE).';
COMMENT ON TABLE dw.dim_return_reason IS 'Return reasons with a reason group (Quality / Fulfilment / Customer Choice).';
COMMENT ON TABLE dw.dim_defect_type IS 'Manufacturing defect types.';
COMMENT ON TABLE dw.dim_downtime_type IS 'Machine downtime causes with planned/unplanned and loss category.';
COMMENT ON TABLE dw.bridge_product_material IS 'Bill of materials: which materials a product uses and how many per unit. Many-to-many bridge.';

COMMENT ON TABLE dw.fact_orders IS 'GRAIN: one row per customer order. Process: order-to-cash. Revenue is recognised only for shipped orders.';
COMMENT ON TABLE dw.fact_order_items IS 'GRAIN: one row per product line within an order. Process: order-to-cash (product-level revenue, margin, discount).';
COMMENT ON TABLE dw.fact_shipments IS 'GRAIN: one row per shipment (one per shipped order). Process: outbound logistics.';
COMMENT ON TABLE dw.fact_returns IS 'GRAIN: one row per return record against one order line. Process: returns.';
COMMENT ON TABLE dw.fact_inventory_snapshot IS 'GRAIN: one row per product, per warehouse, per weekly (Sunday) snapshot. Periodic snapshot of finished goods. Semi-additive over time.';
COMMENT ON TABLE dw.fact_material_inventory_snapshot IS 'GRAIN: one row per material, per plant, per weekly snapshot. Periodic snapshot of raw material stock. Semi-additive over time.';
COMMENT ON TABLE dw.fact_purchases IS 'GRAIN: one row per purchase-order line (one material, one supplier, one plant). Process: procurement.';
COMMENT ON TABLE dw.fact_supplier_deliveries IS 'GRAIN: one row per delivery receipt against a purchase-order line. Process: supplier delivery / goods receipt.';
COMMENT ON TABLE dw.fact_production IS 'GRAIN: one row per production run = one product on one machine in one shift on one date. Process: manufacturing.';
COMMENT ON TABLE dw.fact_material_consumption IS 'GRAIN: one row per material consumed by one production run (units made x bill of materials). Derived fact.';
COMMENT ON TABLE dw.fact_downtime IS 'GRAIN: one row per downtime event (one cause within one production run). Process: machine downtime.';
COMMENT ON TABLE dw.fact_maintenance IS 'GRAIN: one row per maintenance work order on one machine. Process: maintenance.';
COMMENT ON TABLE dw.fact_defects IS 'GRAIN: one row per defect type recorded within one production run. Process: quality inspection.';

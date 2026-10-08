-- 04_dimensions/02_dim_business.sql
-- Business dimensions. Type-1 (overwrite) throughout; see docs/dimensional_model.md for the SCD2 discussion.

CREATE TABLE dw.dim_product AS
SELECT row_number() OVER (ORDER BY p.product_id)::int AS product_key,
       p.product_id, p.sku, p.product_name,
       p.category, p.sub_category,                         -- category hierarchy kept INSIDE the dimension (star, not snowflake)
       p.list_price, p.unit_cost_2025 AS current_unit_cost, p.weight_kg, p.launch_date,
       CASE WHEN p.list_price < 25 THEN 'Budget' WHEN p.list_price < 80 THEN 'Mid' ELSE 'Premium' END AS price_tier,
       pl.plant_name AS primary_plant
FROM staging.stg_products p LEFT JOIN staging.stg_plants pl ON pl.plant_id = p.manufacturing_plant_id;
ALTER TABLE dw.dim_product ADD PRIMARY KEY (product_key);
CREATE UNIQUE INDEX ux_dim_product_id ON dw.dim_product (product_id);

CREATE TABLE dw.dim_supplier AS
SELECT row_number() OVER (ORDER BY supplier_id)::int AS supplier_key, supplier_id, supplier_name, country,
       supplier_tier, payment_terms_days, quoted_lead_time_days
FROM (SELECT * FROM staging.stg_suppliers
      UNION ALL SELECT 'S000', 'Unknown Supplier (missing in source)', 'Unknown', 'Unknown', NULL, NULL) s;
ALTER TABLE dw.dim_supplier ADD PRIMARY KEY (supplier_key);
CREATE UNIQUE INDEX ux_dim_supplier_id ON dw.dim_supplier (supplier_id);

CREATE TABLE dw.dim_material AS
SELECT row_number() OVER (ORDER BY material_id)::int AS material_key, material_id, material_name, material_family,
       standard_cost, unit_of_measure
FROM staging.stg_materials;
ALTER TABLE dw.dim_material ADD PRIMARY KEY (material_key);
CREATE UNIQUE INDEX ux_dim_material_id ON dw.dim_material (material_id);

CREATE TABLE dw.dim_warehouse AS
SELECT row_number() OVER (ORDER BY w.warehouse_id)::int AS warehouse_key, w.warehouse_id, w.warehouse_name,
       l.location_key, l.city, l.country, w.region, w.capacity_units
FROM staging.stg_warehouses w JOIN dw.dim_location l ON l.location_id = w.location_id;
ALTER TABLE dw.dim_warehouse ADD PRIMARY KEY (warehouse_key);
CREATE UNIQUE INDEX ux_dim_warehouse_id ON dw.dim_warehouse (warehouse_id);

CREATE TABLE dw.dim_plant AS
SELECT row_number() OVER (ORDER BY p.plant_id)::int AS plant_key, p.plant_id, p.plant_name,
       l.location_key, l.city, l.country, l.region, p.opened_year
FROM staging.stg_plants p JOIN dw.dim_location l ON l.location_id = p.location_id;
ALTER TABLE dw.dim_plant ADD PRIMARY KEY (plant_key);
CREATE UNIQUE INDEX ux_dim_plant_id ON dw.dim_plant (plant_id);

CREATE TABLE dw.dim_machine AS
SELECT row_number() OVER (ORDER BY m.machine_id)::int AS machine_key, m.machine_id, p.plant_key, p.plant_name,
       m.production_line, m.machine_type, m.install_year, m.manufacturer,
       p.plant_name || ' / ' || m.production_line AS plant_line     -- hierarchy helper: Plant > Line > Machine
FROM staging.stg_machines m JOIN dw.dim_plant p ON p.plant_id = m.plant_id;
ALTER TABLE dw.dim_machine ADD PRIMARY KEY (machine_key);
CREATE UNIQUE INDEX ux_dim_machine_id ON dw.dim_machine (machine_id);

CREATE TABLE dw.dim_carrier AS
SELECT row_number() OVER (ORDER BY carrier_id)::int AS carrier_key, carrier_id, carrier_name, service_level
FROM staging.stg_carriers;
ALTER TABLE dw.dim_carrier ADD PRIMARY KEY (carrier_key);
CREATE UNIQUE INDEX ux_dim_carrier_id ON dw.dim_carrier (carrier_id);

-- key 0 = "No Promotion" so every order line has a valid promotion_key (no NULL foreign keys)
CREATE TABLE dw.dim_promotion AS
SELECT 0 AS promotion_key, 'NONE' AS promotion_id, 'No Promotion' AS promotion_name, 'None' AS promotion_type,
       0::numeric AS discount_pct, NULL::date AS start_date, NULL::date AS end_date, 'None' AS category_scope
UNION ALL
SELECT row_number() OVER (ORDER BY promotion_id)::int, promotion_id, promotion_name, promotion_type, discount_pct,
       start_date, end_date, category_scope
FROM staging.stg_promotions;
ALTER TABLE dw.dim_promotion ADD PRIMARY KEY (promotion_key);
CREATE UNIQUE INDEX ux_dim_promotion_id ON dw.dim_promotion (promotion_id);

-- Customers: attributes from staging + behavioural attributes derived from the order history.
-- first_order / cohort are used by New vs Returning and cohort retention. Segment is "as of" the last data date.
CREATE TABLE dw.dim_customer AS
WITH hist AS (
    SELECT customer_id, min(order_date) AS first_order_date, max(order_date) AS last_order_date, count(*) AS lifetime_orders
    FROM staging.orders_resolved WHERE order_status <> 'Cancelled' GROUP BY customer_id)   -- same order set as fact_orders
SELECT row_number() OVER (ORDER BY c.customer_id)::int AS customer_key, c.customer_id,
       c.first_name, c.last_name, c.first_name || ' ' || c.last_name AS full_name, c.email,
       c.marketing_opt_in, c.signup_date, l.location_key, l.city, l.country, l.region,
       h.first_order_date, date_trunc('month', h.first_order_date)::date AS cohort_month,
       h.last_order_date, COALESCE(h.lifetime_orders, 0) AS lifetime_orders,
       CASE WHEN h.customer_id IS NULL THEN 'No Purchase'
            WHEN DATE '2025-12-31' - h.last_order_date > 365 THEN 'Lost'
            WHEN DATE '2025-12-31' - h.last_order_date > 180 THEN 'At Risk'
            WHEN h.lifetime_orders >= 5 AND DATE '2025-12-31' - h.last_order_date <= 90 THEN 'Champion'
            WHEN h.lifetime_orders >= 3 THEN 'Loyal'
            WHEN h.lifetime_orders = 1 AND DATE '2025-12-31' - h.first_order_date <= 90 THEN 'New'
            WHEN h.lifetime_orders = 1 THEN 'One-time'
            ELSE 'Repeat' END AS customer_segment
FROM staging.stg_customers c
JOIN dw.dim_location l ON l.location_id = c.location_id
LEFT JOIN hist h ON h.customer_id = c.customer_id;
ALTER TABLE dw.dim_customer ADD PRIMARY KEY (customer_key);
CREATE UNIQUE INDEX ux_dim_customer_id ON dw.dim_customer (customer_id);

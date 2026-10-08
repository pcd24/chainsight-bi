-- 03_staging/02_staging_masters.sql
-- Master data: locations, customers (with duplicate merge), products, suppliers, materials, plants, etc.

CREATE TABLE staging.stg_locations AS
SELECT staging.clean_text(location_id) AS location_id, staging.clean_text(city) AS city,
       staging.clean_text(state_province) AS state_province, staging.clean_text(country) AS country,
       staging.clean_text(region) AS region
FROM raw.locations;
ALTER TABLE staging.stg_locations ADD PRIMARY KEY (location_id);

-- ---- Customers: standardise text, then merge duplicate people (same e-mail) into one survivor.
CREATE TEMP TABLE t_cust AS
WITH c AS (
    SELECT btrim(customer_id) AS customer_id,
           initcap(staging.clean_text(first_name)) AS first_name,
           initcap(staging.clean_text(last_name))  AS last_name,
           lower(staging.clean_text(email))        AS email,
           staging.clean_text(phone)               AS phone,
           staging.clean_text(location_id)         AS location_id,
           staging.parse_date(signup_date)         AS signup_date,
           upper(btrim(marketing_opt_in))          AS marketing_opt_in
    FROM raw.customers)
SELECT c.*,
       row_number() OVER w AS rn,
       first_value(customer_id) OVER w AS survivor_id
FROM c
WINDOW w AS (PARTITION BY COALESCE(email, customer_id) ORDER BY (customer_id LIKE 'C9%'), customer_id);

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'customers', customer_id, 'duplicate customer merged into survivor id' FROM t_cust WHERE rn > 1;

CREATE TABLE staging.customer_map AS            -- every source id -> the surviving id
SELECT customer_id AS source_customer_id, survivor_id AS customer_id FROM t_cust;
ALTER TABLE staging.customer_map ADD PRIMARY KEY (source_customer_id);

CREATE TABLE staging.stg_customers AS
SELECT customer_id, first_name, last_name, email, phone, location_id, signup_date, marketing_opt_in
FROM t_cust WHERE rn = 1;
ALTER TABLE staging.stg_customers ADD PRIMARY KEY (customer_id);

-- ---- Products: standardise category labels, drop repeated rows.
CREATE TEMP TABLE t_prod AS
SELECT btrim(product_id) AS product_id, staging.clean_text(sku) AS sku, staging.clean_text(product_name) AS product_name,
       staging.std_category(category) AS category, staging.clean_text(sub_category) AS sub_category,
       list_price::numeric AS list_price, unit_cost_2023::numeric AS unit_cost_2023,
       unit_cost_2024::numeric AS unit_cost_2024, unit_cost_2025::numeric AS unit_cost_2025,
       weight_kg::numeric AS weight_kg, staging.parse_date(launch_date) AS launch_date,
       staging.clean_text(manufacturing_plant_id) AS manufacturing_plant_id,
       row_number() OVER (PARTITION BY btrim(product_id) ORDER BY product_id) AS rn
FROM raw.products;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'products', product_id, CASE WHEN rn > 1 THEN 'duplicate record removed' ELSE 'unrecognised category' END
FROM t_prod WHERE rn > 1 OR category IS NULL;

CREATE TABLE staging.stg_products AS
SELECT product_id, sku, product_name, category, sub_category, list_price, unit_cost_2023, unit_cost_2024,
       unit_cost_2025, weight_kg, launch_date, manufacturing_plant_id
FROM t_prod WHERE rn = 1 AND category IS NOT NULL;
ALTER TABLE staging.stg_products ADD PRIMARY KEY (product_id);

-- ---- Simple masters (typed copies; whitespace/case fixed)
CREATE TABLE staging.stg_suppliers AS
SELECT staging.clean_text(supplier_id) AS supplier_id, staging.clean_text(supplier_name) AS supplier_name,
       initcap(staging.clean_text(country)) AS country, staging.clean_text(supplier_tier) AS supplier_tier,
       payment_terms_days::int AS payment_terms_days, quoted_lead_time_days::int AS quoted_lead_time_days
FROM raw.suppliers;
ALTER TABLE staging.stg_suppliers ADD PRIMARY KEY (supplier_id);

CREATE TABLE staging.stg_materials AS
SELECT staging.clean_text(material_id) AS material_id, staging.clean_text(material_name) AS material_name,
       staging.clean_text(material_family) AS material_family, standard_cost::numeric AS standard_cost,
       staging.clean_text(unit_of_measure) AS unit_of_measure
FROM raw.materials;
ALTER TABLE staging.stg_materials ADD PRIMARY KEY (material_id);

CREATE TABLE staging.stg_bom AS
SELECT btrim(product_id) AS product_id, btrim(material_id) AS material_id, qty_per_unit::numeric AS qty_per_unit
FROM raw.bom;
ALTER TABLE staging.stg_bom ADD PRIMARY KEY (product_id, material_id);

CREATE TABLE staging.stg_supplier_materials AS
SELECT btrim(supplier_id) AS supplier_id, btrim(material_id) AS material_id, sourcing_share::numeric AS sourcing_share
FROM raw.supplier_materials;
ALTER TABLE staging.stg_supplier_materials ADD PRIMARY KEY (supplier_id, material_id);

CREATE TABLE staging.stg_warehouses AS
SELECT btrim(warehouse_id) AS warehouse_id, staging.clean_text(warehouse_name) AS warehouse_name,
       btrim(location_id) AS location_id, staging.clean_text(region) AS region, capacity_units::int AS capacity_units
FROM raw.warehouses;
ALTER TABLE staging.stg_warehouses ADD PRIMARY KEY (warehouse_id);

CREATE TABLE staging.stg_plants AS
SELECT btrim(plant_id) AS plant_id, staging.clean_text(plant_name) AS plant_name, btrim(location_id) AS location_id,
       opened_year::int AS opened_year
FROM raw.plants;
ALTER TABLE staging.stg_plants ADD PRIMARY KEY (plant_id);

CREATE TABLE staging.stg_machines AS
SELECT upper(btrim(machine_id)) AS machine_id, btrim(plant_id) AS plant_id, staging.clean_text(production_line) AS production_line,
       staging.clean_text(machine_type) AS machine_type, install_year::int AS install_year,
       staging.clean_text(manufacturer) AS manufacturer
FROM raw.machines;
ALTER TABLE staging.stg_machines ADD PRIMARY KEY (machine_id);

CREATE TABLE staging.stg_carriers AS
SELECT upper(btrim(carrier_id)) AS carrier_id, staging.clean_text(carrier_name) AS carrier_name,
       staging.clean_text(service_level) AS service_level
FROM raw.carriers;
ALTER TABLE staging.stg_carriers ADD PRIMARY KEY (carrier_id);

CREATE TABLE staging.stg_promotions AS
SELECT btrim(promotion_id) AS promotion_id, staging.clean_text(promotion_name) AS promotion_name,
       staging.clean_text(promotion_type) AS promotion_type, discount_pct::numeric AS discount_pct,
       staging.parse_date(start_date) AS start_date, staging.parse_date(end_date) AS end_date,
       staging.clean_text(category_scope) AS category_scope
FROM raw.promotions;
ALTER TABLE staging.stg_promotions ADD PRIMARY KEY (promotion_id);

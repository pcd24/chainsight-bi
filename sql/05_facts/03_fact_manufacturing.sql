-- 05_facts/03_fact_manufacturing.sql
-- Manufacturing facts: production, material consumption, downtime, maintenance, defects.

-- ================================================================ fact_production
-- GRAIN: one row per production run = one product on one machine in one shift on one date.
CREATE TABLE dw.fact_production AS
WITH dt AS (
    SELECT run_id,
           sum(duration_minutes) FILTER (WHERE downtime_type = 'Material Shortage') AS material_shortage_minutes,
           sum(duration_minutes) FILTER (WHERE downtime_type IN ('Mechanical Failure', 'Electrical Failure')) AS equipment_failure_minutes,
           sum(duration_minutes) FILTER (WHERE downtime_type = 'Changeover') AS changeover_minutes
    FROM staging.stg_downtime_events GROUP BY run_id)
SELECT row_number() OVER (ORDER BY r.run_id)::bigint AS production_key,
       r.run_id, dw.date_key(r.run_date) AS date_key, r.shift,
       pl.plant_key, m.machine_key, p.product_key,
       r.planned_minutes, r.downtime_minutes, r.operating_minutes,
       COALESCE(dt.material_shortage_minutes, 0) AS material_shortage_minutes,
       COALESCE(dt.equipment_failure_minutes, 0) AS equipment_failure_minutes,
       COALESCE(dt.changeover_minutes, 0) AS changeover_minutes,
       r.rated_units_per_min,
       round(r.rated_units_per_min * r.planned_minutes, 4)   AS capacity_units,   -- max output if the machine ran all planned time at rated speed
       round(r.rated_units_per_min * r.operating_minutes, 4) AS ideal_units,      -- max output for the time it actually ran
       r.total_units, r.good_units, r.defect_units
FROM staging.stg_production_runs r
JOIN dw.dim_machine m ON m.machine_id = r.machine_id
JOIN dw.dim_plant pl ON pl.plant_id = r.plant_id
JOIN dw.dim_product p ON p.product_id = r.product_id
LEFT JOIN dt ON dt.run_id = r.run_id;
ALTER TABLE dw.fact_production ADD PRIMARY KEY (production_key);
ALTER TABLE dw.fact_production ADD CONSTRAINT uq_fact_production_grain UNIQUE (run_id);
ALTER TABLE dw.fact_production ADD CONSTRAINT uq_fact_production_slot UNIQUE (date_key, shift, machine_key);

-- ================================================================ fact_material_consumption
-- GRAIN: one row per material consumed by one production run (production units x bill of materials).
CREATE TABLE dw.fact_material_consumption AS
SELECT row_number() OVER (ORDER BY fp.production_key, mt.material_key)::bigint AS consumption_key,
       fp.production_key, fp.date_key, fp.plant_key, fp.machine_key, fp.product_key, mt.material_key,
       round(fp.total_units * b.qty_per_unit, 2) AS quantity_consumed,
       round(fp.total_units * b.qty_per_unit * mt.standard_cost, 2) AS consumption_value
FROM dw.fact_production fp
JOIN dw.dim_product p ON p.product_key = fp.product_key
JOIN staging.stg_bom b ON b.product_id = p.product_id
JOIN dw.dim_material mt ON mt.material_id = b.material_id
WHERE fp.total_units > 0;
ALTER TABLE dw.fact_material_consumption ADD PRIMARY KEY (consumption_key);
ALTER TABLE dw.fact_material_consumption ADD CONSTRAINT uq_fact_material_consumption_grain UNIQUE (production_key, material_key);

-- ================================================================ fact_downtime
-- GRAIN: one row per downtime event (one cause within one production run).
CREATE TABLE dw.fact_downtime AS
SELECT row_number() OVER (ORDER BY d.downtime_id)::bigint AS downtime_key,
       d.downtime_id, d.run_id, fp.production_key,
       dw.date_key(d.event_date) AS date_key, fp.plant_key, fp.machine_key, fp.product_key, dtp.downtime_type_key,
       d.duration_minutes, round(d.duration_minutes / 60.0, 3) AS duration_hours,
       round(d.duration_minutes * fp.rated_units_per_min, 2) AS lost_units_est,    -- production that could have been made at rated speed
       CASE WHEN d.is_planned = 'Y' THEN 1 ELSE 0 END AS is_planned_flag
FROM staging.stg_downtime_events d
JOIN dw.fact_production fp ON fp.run_id = d.run_id
JOIN dw.dim_downtime_type dtp ON dtp.downtime_type = d.downtime_type;
ALTER TABLE dw.fact_downtime ADD PRIMARY KEY (downtime_key);
ALTER TABLE dw.fact_downtime ADD CONSTRAINT uq_fact_downtime_grain UNIQUE (downtime_id);

-- ================================================================ fact_maintenance
-- GRAIN: one row per maintenance work order (preventive or corrective) on one machine.
CREATE TABLE dw.fact_maintenance AS
SELECT row_number() OVER (ORDER BY w.work_order_id)::bigint AS maintenance_key,
       w.work_order_id, dw.date_key(w.work_order_date) AS date_key, m.plant_key, m.machine_key,
       w.maintenance_type, CASE WHEN w.maintenance_type = 'Corrective' THEN 1 ELSE 0 END AS corrective_flag,
       1 AS work_order_count, w.duration_hours, w.cost, w.triggered_by_run_id
FROM staging.stg_maintenance_orders w
JOIN dw.dim_machine m ON m.machine_id = w.machine_id;
ALTER TABLE dw.fact_maintenance ADD PRIMARY KEY (maintenance_key);
ALTER TABLE dw.fact_maintenance ADD CONSTRAINT uq_fact_maintenance_grain UNIQUE (work_order_id);

-- ================================================================ fact_defects
-- GRAIN: one row per defect type recorded within one production run.
CREATE TABLE dw.fact_defects AS
SELECT row_number() OVER (ORDER BY d.defect_id)::bigint AS defect_key,
       d.defect_id, fp.production_key, fp.date_key, fp.plant_key, fp.machine_key, fp.product_key, dty.defect_type_key,
       d.defect_qty, d.detection_stage, d.disposition,
       CASE WHEN d.disposition = 'Scrap'
            THEN round(d.defect_qty * (CASE substr(fp.date_key::text, 1, 4) WHEN '2023' THEN p.unit_cost_2023
                                           WHEN '2024' THEN p.unit_cost_2024 ELSE p.unit_cost_2025 END), 2)
            ELSE 0 END AS scrap_cost
FROM staging.stg_defects d
JOIN dw.fact_production fp ON fp.run_id = d.run_id
JOIN dw.dim_product dp ON dp.product_key = fp.product_key
JOIN staging.stg_products p ON p.product_id = dp.product_id
JOIN dw.dim_defect_type dty ON dty.defect_type = d.defect_type;
ALTER TABLE dw.fact_defects ADD PRIMARY KEY (defect_key);
ALTER TABLE dw.fact_defects ADD CONSTRAINT uq_fact_defects_grain UNIQUE (production_key, defect_type_key);

-- 03_staging/05_staging_manufacturing.sql
-- Production runs, downtime events, maintenance work orders, defects.

CREATE TEMP TABLE t_run AS
SELECT btrim(run_id) AS run_id, staging.parse_date(run_date) AS run_date, shift::int AS shift,
       upper(btrim(machine_id)) AS machine_id, btrim(plant_id) AS plant_id, upper(btrim(product_id)) AS product_id,
       planned_minutes::int AS planned_minutes, downtime_minutes::int AS downtime_minutes,
       operating_minutes::int AS operating_minutes, rated_units_per_min::numeric AS rated_units_per_min,
       planned_qty::numeric AS planned_qty, total_units::int AS total_units, good_units::int AS good_units,
       defect_units::int AS defect_units,
       row_number() OVER (PARTITION BY btrim(run_id) ORDER BY run_id) AS rn
FROM raw.production_runs;

CREATE TEMP TABLE t_run_chk AS
SELECT t.*, CASE
    WHEN t.rn > 1 THEN 'duplicate record removed'
    WHEN t.run_date IS NULL THEN 'invalid run_date'
    WHEN t.total_units < 0 OR t.good_units < 0 OR t.defect_units < 0 THEN 'negative units'
    WHEN t.good_units > t.total_units OR t.good_units + t.defect_units <> t.total_units THEN 'good + defect <> total units'
    WHEN m.machine_id IS NULL THEN 'unknown machine_id'
    WHEN p.product_id IS NULL THEN 'unknown product_id' END AS reject_reason
FROM t_run t
LEFT JOIN staging.stg_machines m ON m.machine_id = t.machine_id
LEFT JOIN staging.stg_products p ON p.product_id = t.product_id;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'production_runs', run_id, reject_reason FROM t_run_chk WHERE reject_reason IS NOT NULL;

CREATE TABLE staging.stg_production_runs AS
SELECT run_id, run_date, shift, machine_id, plant_id, product_id, planned_minutes, downtime_minutes, operating_minutes,
       rated_units_per_min, planned_qty, total_units, good_units, defect_units
FROM t_run_chk WHERE reject_reason IS NULL;
ALTER TABLE staging.stg_production_runs ADD PRIMARY KEY (run_id);

CREATE TEMP TABLE t_dt AS
SELECT btrim(downtime_id) AS downtime_id, btrim(run_id) AS run_id, staging.parse_date(event_date) AS event_date,
       upper(btrim(machine_id)) AS machine_id, btrim(plant_id) AS plant_id,
       staging.clean_text(downtime_type) AS downtime_type, duration_minutes::int AS duration_minutes,
       upper(btrim(is_planned)) AS is_planned,
       row_number() OVER (PARTITION BY btrim(downtime_id) ORDER BY downtime_id) AS rn
FROM raw.downtime_events;

CREATE TEMP TABLE t_dt_chk AS
SELECT t.*, CASE
    WHEN t.rn > 1 THEN 'duplicate record removed'
    WHEN t.duration_minutes <= 0 THEN 'non-positive duration'
    WHEN r.run_id IS NULL THEN 'parent production run rejected or missing'
    WHEN t.event_date IS NULL THEN 'invalid event_date' END AS reject_reason
FROM t_dt t LEFT JOIN staging.stg_production_runs r ON r.run_id = t.run_id;

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'downtime_events', downtime_id, reject_reason FROM t_dt_chk WHERE reject_reason IS NOT NULL;

CREATE TABLE staging.stg_downtime_events AS
SELECT downtime_id, run_id, event_date, machine_id, plant_id, downtime_type, duration_minutes, is_planned
FROM t_dt_chk WHERE reject_reason IS NULL;
ALTER TABLE staging.stg_downtime_events ADD PRIMARY KEY (downtime_id);

-- Maintenance: missing cost is kept as NULL (not guessed) and excluded from cost averages.
CREATE TABLE staging.stg_maintenance_orders AS
SELECT btrim(work_order_id) AS work_order_id, upper(btrim(machine_id)) AS machine_id, btrim(plant_id) AS plant_id,
       staging.parse_date(work_order_date) AS work_order_date, staging.clean_text(maintenance_type) AS maintenance_type,
       duration_hours::numeric AS duration_hours, NULLIF(btrim(cost), '')::numeric AS cost,
       staging.clean_text(triggered_by_run_id) AS triggered_by_run_id
FROM raw.maintenance_orders;
ALTER TABLE staging.stg_maintenance_orders ADD PRIMARY KEY (work_order_id);

INSERT INTO staging.rejects (source_table, record_key, reason)
SELECT 'defects', btrim(d.defect_id), 'parent production run rejected or missing'
FROM raw.defects d WHERE NOT EXISTS (SELECT 1 FROM staging.stg_production_runs r WHERE r.run_id = btrim(d.run_id));

CREATE TABLE staging.stg_defects AS
SELECT btrim(d.defect_id) AS defect_id, btrim(d.run_id) AS run_id,
       initcap(lower(staging.clean_text(d.defect_type))) AS defect_type, d.defect_qty::int AS defect_qty,
       staging.clean_text(d.detection_stage) AS detection_stage, staging.clean_text(d.disposition) AS disposition
FROM raw.defects d
WHERE EXISTS (SELECT 1 FROM staging.stg_production_runs r WHERE r.run_id = btrim(d.run_id));
ALTER TABLE staging.stg_defects ADD PRIMARY KEY (defect_id);

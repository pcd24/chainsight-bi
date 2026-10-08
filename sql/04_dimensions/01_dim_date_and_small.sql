-- 04_dimensions/01_dim_date_and_small.sql
-- Rebuilds the dw schema from scratch. Surrogate keys are small integers; the date key is yyyymmdd (readable + sortable).
DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;

CREATE FUNCTION dw.date_key(d DATE) RETURNS INT AS $$ SELECT to_char(d, 'YYYYMMDD')::int $$ LANGUAGE sql IMMUTABLE;

-- ---------------------------------------------------------------- dim_date
-- One row per calendar day. Every text label has a numeric *_sort column so Power BI can sort
-- "Jan, Feb, Mar" chronologically instead of alphabetically (Sort By Column).
CREATE TABLE dw.dim_date AS
SELECT dw.date_key(d::date)                        AS date_key,
       d::date                                     AS full_date,
       EXTRACT(day FROM d)::int                    AS day_of_month,
       trim(to_char(d, 'Day'))                     AS day_name,
       EXTRACT(isodow FROM d)::int                 AS day_of_week_num,      -- 1 = Monday
       EXTRACT(week FROM d)::int                   AS iso_week,
       date_trunc('week', d)::date                 AS week_start_date,
       EXTRACT(month FROM d)::int                  AS month_num,
       trim(to_char(d, 'Month'))                   AS month_name,
       to_char(d, 'Mon')                           AS month_short,
       to_char(d, 'Mon YYYY')                      AS month_year,
       (EXTRACT(year FROM d) * 100 + EXTRACT(month FROM d))::int AS month_year_sort,   -- 202401
       date_trunc('month', d)::date                AS month_start_date,
       EXTRACT(quarter FROM d)::int                AS quarter_num,
       'Q' || EXTRACT(quarter FROM d) || ' ' || EXTRACT(year FROM d) AS quarter_year,
       (EXTRACT(year FROM d) * 10 + EXTRACT(quarter FROM d))::int    AS quarter_year_sort,
       EXTRACT(year FROM d)::int                   AS year_num,
       -- Fiscal year starts 1 April; FY2024 = Apr 2023 - Mar 2024
       (CASE WHEN EXTRACT(month FROM d) >= 4 THEN EXTRACT(year FROM d) + 1 ELSE EXTRACT(year FROM d) END)::int AS fiscal_year,
       (((EXTRACT(month FROM d)::int + 8) % 12) / 3 + 1)::int        AS fiscal_quarter,
       (EXTRACT(isodow FROM d) IN (6, 7))          AS is_weekend,
       (d = (date_trunc('month', d) + interval '1 month - 1 day')) AS is_month_end,
       (d <= DATE '2025-12-31')                    AS is_actuals                 -- FALSE for forward-looking dates (promised delivery dates run into 2026)
FROM generate_series('2023-01-01'::date, '2026-12-31'::date, interval '1 day') AS d;
ALTER TABLE dw.dim_date ADD PRIMARY KEY (date_key);
CREATE UNIQUE INDEX ux_dim_date_full_date ON dw.dim_date (full_date);

-- ---------------------------------------------------------------- dim_location (conformed: customer, warehouse, plant)
CREATE TABLE dw.dim_location AS
SELECT row_number() OVER (ORDER BY location_id)::int AS location_key, location_id, city, state_province, country, region
FROM staging.stg_locations;
ALTER TABLE dw.dim_location ADD PRIMARY KEY (location_key);

-- ---------------------------------------------------------------- tiny lookup dimensions
CREATE TABLE dw.dim_order_status (
    order_status_key INT PRIMARY KEY, order_status TEXT NOT NULL, is_revenue_recognized BOOLEAN NOT NULL,
    status_group TEXT NOT NULL, status_sort INT NOT NULL);
INSERT INTO dw.dim_order_status VALUES
 (1, 'Delivered',   TRUE,  'Fulfilled',   1),
 (2, 'In Transit',  TRUE,  'Fulfilled',   2),
 (3, 'Backordered', FALSE, 'Unfulfilled', 3),
 (4, 'Cancelled',   FALSE, 'Lost',        4),
 (5, 'Unknown',     FALSE, 'Unresolved',  5);

CREATE TABLE dw.dim_return_reason AS
SELECT row_number() OVER (ORDER BY return_reason)::int AS return_reason_key, return_reason,
       CASE WHEN return_reason IN ('Defective / Not Working') THEN 'Quality'
            WHEN return_reason IN ('Arrived Late', 'Wrong Item Shipped') THEN 'Fulfilment'
            ELSE 'Customer Choice / Expectation' END AS reason_group
FROM (SELECT DISTINCT return_reason FROM staging.stg_returns) r;
ALTER TABLE dw.dim_return_reason ADD PRIMARY KEY (return_reason_key);

CREATE TABLE dw.dim_defect_type AS
SELECT row_number() OVER (ORDER BY defect_type)::int AS defect_type_key, defect_type
FROM (SELECT DISTINCT defect_type FROM staging.stg_defects) d;
ALTER TABLE dw.dim_defect_type ADD PRIMARY KEY (defect_type_key);

CREATE TABLE dw.dim_downtime_type AS
SELECT row_number() OVER (ORDER BY downtime_type)::int AS downtime_type_key, downtime_type,
       CASE downtime_type WHEN 'Changeover' THEN 'Planned' ELSE 'Unplanned' END AS planned_category,
       CASE WHEN downtime_type IN ('Mechanical Failure', 'Electrical Failure') THEN 'Equipment failure'
            WHEN downtime_type = 'Material Shortage' THEN 'Supply'
            WHEN downtime_type = 'Changeover' THEN 'Changeover'
            ELSE 'Other losses' END AS loss_category
FROM (SELECT DISTINCT downtime_type FROM staging.stg_downtime_events) t;
ALTER TABLE dw.dim_downtime_type ADD PRIMARY KEY (downtime_type_key);

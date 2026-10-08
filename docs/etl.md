# ETL / ELT Process

The pipeline is **ELT**: files are loaded unchanged into PostgreSQL, then transformed with SQL. `python scripts/run_pipeline.py` runs every step; `--from <step>` restarts from a later step.

| Step | Script(s) | What it does |
|---|---|---|
| generate (optional) | `scripts/generate_data.py` | Simulates 3 years of the business and writes 24 dirty CSVs to `data/raw` plus `data/processed/generation_manifest.json` (counts of every injected problem) |
| setup | `sql/01_setup/01_schemas.sql` | Creates schemas raw, staging, dw, analytics, dq |
| raw | `sql/02_raw/01_raw_tables.sql` | One all-TEXT table per file |
| load | `scripts/load_data.py` | `COPY` each CSV (about 2.8 million rows) |
| staging | `sql/03_staging/01..06` | Cleaning functions, typed tables, dedupe, validation, `staging.rejects`, customer merge, order-status repair |
| dimensions | `sql/04_dimensions/01..03` | Date, lookups, business dimensions, BOM bridge |
| facts | `sql/05_facts/02..06` | 13 fact tables, table comments |
| quality | `sql/06_quality/01_quality_checks.sql` | 150+ checks into `dq.check_results` |
| indexes | `sql/07_indexes/01..02` | Indexes and foreign keys |
| analytics | `sql/08_analytics/00_views.sql` | Reporting views |

## Cleaning rules (what staging does with each problem)

| Problem injected in RAW | Example | Staging action |
|---|---|---|
| Whitespace, repeated spaces | `"Anna  "` | `clean_text()` trims and collapses |
| Inconsistent capitalisation | `last_name = "SMITH "`, `carrier = "cr3 "` | `initcap`, `upper`/`lower` per column rule |
| Inconsistent category labels | `Smart-Home`, `COMPUTER ACCESSORY` | `std_category()` maps to the 7 official labels; unmappable rows are rejected |
| Invalid / variant statuses | `delivrd`, `canceled`, `???` | `std_order_status()`; unknown becomes `Unknown`, then repaired from the shipment if one exists |
| Malformed dates | `15/03/2024`, `2024-02-30` | `parse_date()` accepts yyyy-mm-dd and dd/mm/yyyy; impossible dates become NULL |
| NULLs | missing phone, e-mail, delivered date, cost | Kept where the business can live without them (phone, cost); rejected where the row is unusable (order date) |
| Duplicate rows | repeated orders, items, shipments | `ROW_NUMBER() OVER (PARTITION BY key)`, keep the first, log the rest |
| Duplicate customers | same person under a new id with different case | Merged on lower-cased e-mail; `customer_map` repoints their orders |
| Invalid product ids | `P9999`, `" p0012"` | Case/space repaired; unknown ids rejected |
| Negative / impossible quantities | quantity -3, good units > total | Rejected with a reason |
| Missing foreign identifiers | PO with no supplier | Kept and assigned to dimension member `S000 Unknown Supplier` (spend still counts) |
| Child rows of rejected parents | items of a rejected order | Rejected with reason "parent ... rejected" |

Every removed or merged row is recorded in `staging.rejects (source_table, record_key, reason)`. Query it to audit the cleaning:

```sql
SELECT source_table, reason, count(*) FROM staging.rejects GROUP BY 1, 2 ORDER BY 1, 3 DESC;
```

## Reconciliation rule

For every cleaned table: **raw rows = staging rows + rejected rows**. The check is automated (`dq.check_results`, category *Reconciliation*) and fails the pipeline if any row is unaccounted for.

## Re-running

Each script drops and recreates what it owns (`DROP SCHEMA ... CASCADE` or `DROP TABLE IF EXISTS`), so every step is idempotent. A full run (generate + build) takes about 3 minutes for 250k orders on one CPU.

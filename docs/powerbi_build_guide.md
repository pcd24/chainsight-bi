# Power BI Build Guide

Power BI Desktop runs on Windows only and cannot be automated from here, so this guide plus `powerbi/` lets you recreate the report exactly. Budget about 6-8 hours for the first full build.

## 0. Prerequisites

1. The pipeline has finished (`python scripts/run_pipeline.py`) and PostgreSQL is running.
2. Power BI Desktop (current release). If it asks for the Npgsql provider, install it from the link Power BI shows (older versions need it).
3. Database user with read access to schemas `dw` and `analytics`. For a laptop demo, the pipeline user is fine; for real use, create a read-only role:
   `CREATE ROLE pbi_reader LOGIN PASSWORD '...'; GRANT USAGE ON SCHEMA dw, analytics TO pbi_reader; GRANT SELECT ON ALL TABLES IN SCHEMA dw, analytics TO pbi_reader;`

## 1. Connect and import (15 min)

1. *Home > Get data > PostgreSQL database*. Server `localhost:5432`, database `chainsight`, **Import** mode. Credentials: Database tab, your user and password.
2. Easier path: *Home > Transform data > New Source > Blank Query*, open *Advanced Editor* and paste each block from `powerbi/model/power_query_load.m.txt` (create parameters `pgServer` and `pgDatabase` first). Rename each query to the name in the block header (`Orders`, `Order Items`, ...). 30 queries in total.
3. *Close & Apply*. Loading about 3.1M rows takes a few minutes.
4. File > Options > Current File > Data Load: **turn off Auto date/time**.

## 2. Build the model (45 min)

Follow `powerbi/model/model_specification.md` section by section:

1. Model view: confirm the auto-detected relationships, delete wrong ones, and create the rest from the table in section 3. Set the 10 **inactive** date relationships to inactive (untick "Make this relationship active").
2. Every relationship: many-to-one, cross-filter **Single**. No bidirectional, no many-to-many.
3. `Date` table: *Table tools > Mark as date table* on `full_date`. Set *Sort by column* for `month_year`, `quarter_year`, `month_name`, `month_short`, `day_name` (see spec). Create the Calendar and Fiscal hierarchies.
4. Create the other hierarchies (Product, Machine, Customer, Warehouse, Supplier, Material).
5. Hide `*_key` columns and raw flag/amount columns that measures wrap; set *Summarization = Don't summarize* on numeric columns.
6. Create the empty `_Measures` table (*Enter data*, one blank column, load, hide the column).

## 3. Add the measures (60 min)

For each file in `powerbi/dax/` (in order 01 to 10): *Modeling > New measure* on `_Measures`, paste a block, set the display folder (Properties pane) and the format given in the `// Format:` comment. Do 01 (E-commerce) and 07 (time intelligence) first so you can test early.

**Checkpoint A (after file 01):** add a Card with `[Total Revenue]` and no filters. It must equal the reference in `docs/kpi_reference_values.md` ($56,640,403). Add a table with `Date[year_num]`, `[Total Revenue]`, `[Gross Margin %]`: 2025 must show $20,868,902 and 33.6%.

**Checkpoint B (after 05):** `[OEE]` = 68.38%, `[Availability]` = 85.42%.

If a number differs, the cause is almost always a missing relationship, an active/inactive mix-up, or a stray slicer.

## 4. Theme and page setup (10 min)

*View > Themes > Browse for themes* > `powerbi/theme/chainsight_theme.json`. Add 12 pages named as in `powerbi/dashboard_specs/README.md`. Set page size 1280 x 720 (*Format page > Canvas settings > Type: Custom*). Add the page filter `Date[is_actuals] = TRUE` on each content page.

## 5. Build the pages (about 5 hours)

Build in this order. Each page spec lists every visual with fields, size, position, conditional formatting and interactions.

| Order | Page | Time | Why this order |
|---|---|---|---|
| 1 | Page 2 E-Commerce | 45 min | Establishes the card, slicer and chart patterns you reuse |
| 2 | Page 3 Customers | 40 min | Introduces the cohort matrix |
| 3 | Page 4 Inventory & Warehouse | 40 min | Snapshot measures |
| 4 | Page 5 Suppliers | 40 min | Scatter and bands |
| 5 | Page 6 Manufacturing | 40 min | OEE |
| 6 | Page 7 Machine & Maintenance | 35 min | Pareto and hierarchy drill |
| 7 | Page 8 Logistics | 30 min | |
| 8 | Page 9 Demand & Supply | 30 min | Needs `Product Supply Position` relationship |
| 9 | Page 11 Investigate Product (drill-through) | 30 min | Needed before the control tower |
| 10 | Page 10 Control Tower | 40 min | Uses all RAG measures |
| 11 | Page 1 Executive | 35 min | Reuses the control-tower measures |
| 12 | Page 12 Tooltip pages, bookmarks, navigation buttons | 40 min | Last, once pages exist |

Drill-through setup: on page 11 drag `Product[product_name]` into *Drill through > Add drill-through fields*, keep *Keep all filters* ON, add a Back button. Right-click a product row on pages 2, 4, 9 and 10 to test.

## 6. Validation checklist

- [ ] Model view: no warnings, no bidirectional arrows, 10 inactive date relationships present.
- [ ] Cards with no slicers match `docs/kpi_reference_values.md` (revenue, margin, orders, OEE, on-time %).
- [ ] 2025 vs 2024 revenue YoY = +9.2%.
- [ ] Executive page: Alert Text lists the red stages (with 2025 data: warehouse dispatch and orders).
- [ ] Page 9: product counts per status = 438 / 46 / 15 / 1 (balanced / excess / shortage / constrained).
- [ ] Drill-through from page 10 problem table opens page 11 with the product's chart set.
- [ ] Cohort matrix is not affected by the date slicer.
- [ ] Every page has the navigation strip and a reset-filters bookmark.
- [ ] Take screenshots into `reports/` (the README has placeholders for them).

## 7. Troubleshooting

| Symptom | Likely cause |
|---|---|
| Revenue differs from the reference | A filter on `Date[is_actuals]` is fine; a leftover slicer or a wrong active relationship is not |
| Month names sort alphabetically | Sort By Column not set on `month_year` |
| "Ambiguous path" error when creating a relationship | You tried to link Plant to Machine; the spec avoids it |
| `[Inventory Value]` too high | Used `SUM` over all weeks; use the measure (last snapshot) |
| Blank `Return Rate` | `Returns` order-date relationship left active/inactive incorrectly; the measure uses `USERELATIONSHIP` and needs it present but inactive |
| Slow refresh | Load Inventory filtered to the last 12 months in Power Query while developing |

## 8. Refresh and sharing

Report is Import mode: *Refresh* re-reads PostgreSQL after you re-run the pipeline. To share without exposing the database, publish to a workspace and schedule refresh through a gateway, or export to PDF for the portfolio. Do not commit `.pbix` files with real credentials (`.pbix` is git-ignored).

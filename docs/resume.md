# Resume and Portfolio Material

## Project title (one line)

**ChainSight: E-Commerce, Supply Chain & Manufacturing BI Platform** (PostgreSQL, SQL, Power BI, DAX; synthetic data)

## Technology list

PostgreSQL 16, SQL (CTEs, window functions, conditional aggregation, views, indexing, EXPLAIN ANALYZE), dimensional modelling (star schema, fact/dimension design, surrogate keys, bridge tables), ELT, data quality testing, Python (pandas, NumPy, psycopg2) for synthetic data generation and pipeline orchestration, Power BI (data model, DAX, time intelligence, drill-through), Docker Compose, Graphviz, Markdown/Mermaid.

## Resume bullets (what was actually built)

* Designed and built a PostgreSQL data warehouse (raw, staging, dw, analytics layers) for a synthetic manufacturer-retailer: 13 fact tables and 15 dimensions in a star-schema constellation with documented grain, surrogate keys, 73 declared foreign keys and 166 automated data-quality checks; about 2.8M source rows reconciled to the cent (raw = staging + logged rejects).
* Wrote 81 analytical SQL queries (window functions, CTEs, cohort retention, Pareto, OEE, supplier and inventory risk) plus indexing with EXPLAIN ANALYZE evidence (product-history lookup 90 ms to 0.9 ms), and an automated one-command pipeline that rebuilds the warehouse in about 3 minutes.
* Specified a Power BI semantic model (single-direction relationships, role-playing dates, BOM bridge) with a library of about 200 DAX measures and detailed build specifications for a 10-page report with an end-to-end supply-chain control tower and drill-through; derived 23 evidence-based insights from the data, such as a 10-point Audio margin decline linked to deeper discounting.

*(Use "synthetic dataset" wherever you mention data. The Power BI report file itself is built from the specifications; screenshots belong in `reports/` after you build it.)*

## 60-second explanation

I built an end-to-end BI platform for a fictional manufacturer that sells online. A Python simulation generates three years of connected data: suppliers, purchase orders, machine runs, warehouse stock, orders, shipments and returns, with deliberate data-quality problems. I load it into PostgreSQL, clean it with SQL while logging every rejected row, and build a star schema with thirteen fact tables whose grain is enforced by constraints. Eighty-one SQL queries and a Power BI model with about two hundred DAX measures answer business questions from revenue and margin to OEE and supplier reliability. The signature piece is a control tower that follows a late order back through stock, production and materials to a supplier.

## 2-minute explanation

Add to the 60-second version: why the data is a simulation (so a supplier delay really propagates to shelves), the layered architecture and why raw is all text, the cleaning rules (dedupe with ROW_NUMBER, status repair from shipment evidence, date parsing that never fails), and the data-quality framework. Then give two findings with numbers: Audio revenue grew but margin fell from 31.8% to 21.7% as the discount rate rose from 4% to 12%; and 63% of machine downtime was waiting for material, peaking during a 2024 supplier disruption. Close with the honest limits: synthetic data, associations not causes, one simulation artefact in January 2023.

## 5-minute technical walkthrough

1. **Problem and scope (30 s):** a manufacturer-retailer cannot see how supply problems reach customers.
2. **Data (60 s):** simulation loop per day (orders consume stock, stock triggers production, production consumes materials, materials come from suppliers with differing reliability); fixed seed; scale parameter; 24 files; injected problems logged in a manifest.
3. **Pipeline (60 s):** raw (TEXT) -> staging (typed, trimmed, deduplicated, rejects) -> transform (customer merge, status repair) -> dw; `run_pipeline.py --from <step>`; reconciliation rule.
4. **Model (60 s):** constellation of stars; grains; periodic snapshots; revenue recognition columns; role-playing dates; BOM bridge; why category is inside the product dimension; Type 1 vs Type 2.
5. **SQL and performance (45 s):** examples (cohort retention, Pareto, LAG growth), partial and covering indexes, 90 ms to 0.9 ms.
6. **Power BI and DAX (45 s):** import, single-direction relationships, inactive dates with USERELATIONSHIP, last-snapshot pattern for stock, OEE from sums, RAG measures for the control tower, drill-through.
7. **Results and limits (40 s):** two or three insights; what is association versus cause; what I would do next (Type 2 history, incremental load, real lot-level ageing).

## Commit plan (recommended GitHub history)

1. `chore: repo skeleton, .gitignore, .env.example, docker-compose`
2. `feat(data): seeded simulation generator with injected data-quality problems`
3. `feat(sql): schemas, raw tables, loader`
4. `feat(sql): staging cleaning functions, rejects log, customer merge, order-status repair`
5. `feat(dw): date and business dimensions, BOM bridge`
6. `feat(dw): sales, manufacturing, supply and inventory facts with grain constraints`
7. `feat(quality): 166 data-quality checks and reconciliation`
8. `perf: indexes, foreign keys, EXPLAIN evidence`
9. `feat(analytics): 81 queries and reporting views`
10. `feat(powerbi): model specification, DAX library, theme`
11. `feat(powerbi): 12 page specifications and build guide`
12. `docs: data dictionary, dimensional model, KPIs, insights, management report`
13. `docs: interview guide, README, diagrams`
14. After you build the report: `docs: add dashboard screenshots`

Add GitHub topics: `postgresql`, `power-bi`, `dax`, `data-modeling`, `star-schema`, `sql`, `business-intelligence`, `supply-chain`.

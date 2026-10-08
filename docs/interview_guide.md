# Interview Guide

Sixty-eight questions with short answers drawn from this project. Learn the logic, not the wording. Numbers refer to the generated dataset (seed 42, scale 1.0). Query ids (Q01...) are in `sql/08_analytics`.


## A. Project overview and design decisions

**1. Explain this project in 30 seconds.**

ChainSight is a synthetic end-to-end BI project for a company that manufactures consumer electronics and sells online. I simulated three years of operations, loaded dirty source files into PostgreSQL, cleaned them with SQL, built a star-schema warehouse with 13 fact tables, wrote 81 analytical queries, and designed a Power BI model with about 200 DAX measures and 12 report pages. The key feature is a control tower that follows a problem from a late customer order back to a supplier delay.

**2. Explain this project in 1 minute.**

NovaTech buys components from suppliers, builds products in five plants, stores them in 15 warehouses and ships orders to customers. I generated the data with a day-by-day simulation so that events propagate: a supplier delay reduces raw-material stock, which makes machines wait, which empties warehouses, which delays and cancels orders. The data lands in PostgreSQL as raw text, then staging cleans and logs every rejected row, then I build 15 dimensions, one bridge table and 13 facts with documented grain, declared foreign keys and 166 automated quality checks. 81 SQL queries answer the business questions, and the Power BI layer has a clean star schema, a measure library, and ten pages plus a drill-through page. Everything is reproducible with one command.

**3. Explain this project in 3 minutes.**

Start with the business problem: leadership needs to know where the company loses money across commerce, supply chain and manufacturing. Then the architecture: Python generator, raw, staging, transform, dw, analytics, Power BI. Then three design choices I can defend: grain-first fact tables with UNIQUE constraints; revenue recognised at shipment so cancelled and backordered value is measured separately; and snapshot facts for inventory. Then the findings that the data supports, such as Audio margin falling 10 points in 2025 because of heavy discounting and cost, 63% of machine downtime being material shortage, and Chicago and Mumbai warehouses at 29% and 20% stockout. Close with limits: the data is synthetic, correlations are labelled as associations, and January 2023 is distorted by simulation start-up.

**4. Explain the architecture.**

Five layers inside PostgreSQL. raw: one TEXT-only table per file, never edited. staging: types, trimmed text, standard labels, duplicates removed, every rejected row logged with a reason. transform: business rules such as merging duplicate customers and repairing invalid order status from the shipment. dw: surrogate-keyed star schema. analytics: views and queries. A separate dq schema stores check results. Power BI imports dw plus one analytical view.

**5. What was the hardest technical challenge?**

Making the simulated data behave like a connected system without it collapsing. Early versions either had stock-outs everywhere or none, because production, replenishment and purchasing all depended on each other. I fixed it by calibrating each loop separately (capacity headroom for demand growth, a pull-based production rule that nets warehouse needs, and a purchasing rule based on demand rather than realised output), checking stockout and cancellation rates by year after each change, and only then adding the deliberate scenarios.

**6. Why a synthetic dataset, and how do you stop it looking random?**

Real data with this breadth is not public, and a synthetic set lets me plant known patterns and then check my analysis finds them. To avoid independent random columns, the generator is a stateful simulation: orders consume stock, stock triggers production, production consumes materials, materials come from suppliers with their own reliability. I am explicit that findings are properties of the simulation, not of a real company.

**7. What would you change if this were a real company?**

Use Type 2 history for product price and customer region; load incrementally with change data capture; add real lot-level inventory (for true ageing) and operator data (DimEmployee); put the warehouse behind a read-only reporting role with scheduled refresh; and test causal hypotheses with root-cause records instead of correlations.

**8. Why PostgreSQL and not a cloud warehouse?**

The brief asked for PostgreSQL, and it is free, runs in Docker, and supports everything used here (window functions, FILTER, partial and covering indexes, EXPLAIN ANALYZE). The same SQL would port to Snowflake or BigQuery with small syntax changes.


## B. SQL

**9. When do you use INNER JOIN vs LEFT JOIN? Give an example from the project.**

INNER JOIN keeps rows with a match on both sides; LEFT JOIN keeps all left rows. In `dim_customer` I LEFT JOIN order history so customers who never bought still appear (segment 'No Purchase'); in `fact_order_items` I INNER JOIN products because an unmatched product would be a data error that staging should already have removed.

**10. What is a CTE and why use one?**

A named temporary result inside a query (WITH ...). I use them to break a question into readable steps, for example Q22 builds activity per cohort, then cohort sizes, then divides. A CTE does not guarantee better performance; in PostgreSQL 12+ it is usually inlined unless it is referenced more than once or marked MATERIALIZED.

**11. What is the difference between ROW_NUMBER, RANK and DENSE_RANK?**

ROW_NUMBER gives unique sequence numbers (ties broken arbitrarily). RANK gives ties the same rank and skips the next numbers (1,1,3). DENSE_RANK gives ties the same rank without gaps (1,1,2). I use ROW_NUMBER to de-duplicate in staging, RANK for plant OEE ranking (Q61) and DENSE_RANK for customer value rank (Q20).

**12. How did you remove duplicates in staging?**

`ROW_NUMBER() OVER (PARTITION BY business_key ORDER BY ...)` and keep rn = 1. Every row with rn > 1 is inserted into `staging.rejects` with the reason 'duplicate record removed', so the count is auditable.

**13. Explain LAG and where you used it.**

LAG(x, n) returns the value n rows earlier in the window. Q02 uses LAG over months for month-over-month growth, Q03 uses LAG(...,12) for year-over-year, and Q26 uses it to get days between a customer's consecutive orders.

**14. What is the difference between WHERE and HAVING?**

WHERE filters rows before grouping, HAVING filters groups after aggregation. Q43 uses HAVING to keep suppliers whose defect rate is more than twice the overall rate.

**15. What is conditional aggregation and why is it useful?**

Using FILTER (WHERE ...) or CASE inside an aggregate to compute several slices in one pass, e.g. Q15 computes 2024 and 2025 revenue and margin side by side with `sum(x) FILTER (WHERE year = 2025)`. It avoids self-joins and multiple scans.

**16. What is a correlated subquery and did you use one?**

A subquery that references the outer query and re-runs per row. I used a scalar subquery in Q45 (products using a material) and mostly prefer joins or window functions for performance. Correlated subqueries are acceptable for small outer sets.

**17. How do window functions differ from GROUP BY?**

GROUP BY collapses rows to one per group; a window function keeps every row and adds a computed value over a frame. Q06 shows each category's revenue and its share of the total in one row using `sum(sum(x)) OVER ()`.

**18. How do you do a running total or cumulative share?**

`SUM(x) OVER (ORDER BY ...)` with the default frame, as in the Pareto queries Q11 and Q53, divided by the grand total `SUM(x) OVER ()`.

**19. How did you handle bad dates in SQL?**

A `parse_date()` function that accepts yyyy-mm-dd and dd/mm/yyyy, returns NULL for anything impossible (like 30 Feb) and never raises an error, so one bad value does not stop a load. NULL dates are then either kept and flagged (delivered date) or rejected (order date).

**20. How do you optimise a slow analytical query?**

Read EXPLAIN (ANALYZE, BUFFERS), look for sequential scans on big tables and row-estimate errors, then add the right index (composite, partial or covering), select only needed columns, filter early, and avoid functions on indexed columns. In this project a 3-column index took a product-history lookup from 90 ms to 0.9 ms (see docs/performance.md).

**21. What is a covering index and where did you use one?**

An index that contains every column the query needs, so PostgreSQL does an index-only scan without visiting the table. `ix_fo_order_date` uses INCLUDE (customer_key, recognized_revenue) so monthly revenue queries show `Heap Fetches: 0`.

**22. What is a partial index?**

An index on a subset of rows. `ix_fis_stockout` indexes only rows with `stockout_flag = 1`, about 8% of the 1.2M-row snapshot table, so it is small and fast for stockout analysis.

**23. What are the risks of using NOT IN with NULLs?**

If the subquery returns any NULL, `x NOT IN (...)` evaluates to unknown and returns no rows. Use NOT EXISTS or a LEFT JOIN ... IS NULL instead. I used NOT EXISTS in staging to find parentless child rows.


## C. Data modelling

**24. What is the difference between a fact and a dimension table?**

A fact stores measurements of a business event at a stated grain (quantities, amounts, durations). A dimension stores descriptive context used to filter and group (product, customer, date). Facts are long and narrow; dimensions are short and wide.

**25. What is grain and why define it first?**

Grain is what one row means. It decides which measures are valid and prevents double counting. Every fact here has a one-sentence grain, a UNIQUE constraint that enforces it, and a DQ check. Example: fact_production = one product on one machine in one shift on one date.

**26. Star schema vs snowflake?**

Star: dimensions are denormalised, so each fact joins to each dimension directly. Snowflake: dimensions are normalised into sub-tables. I chose a star and kept category inside dim_product because it needs fewer joins, performs better in Power BI, and the category data is small.

**27. Why surrogate keys?**

They are small integers (fast joins and compression), independent of source-system key changes, allow 'unknown' members, and are required for Type 2 history. Business keys are retained and unique-indexed for traceability.

**28. What is a slowly changing dimension? Which types exist?**

How a dimension handles attribute change. Type 1 overwrites, Type 2 adds a new row with valid-from/valid-to, Type 3 adds a column for the previous value. Everything here is Type 1 because the source has no history; dim_customer (region) and dim_product (price) would be the first candidates for Type 2.

**29. What is a conformed dimension?**

A dimension shared by several facts with the same keys and meaning. Date, Product, Warehouse, Plant and Material are conformed, which is what makes a cross-domain query like production vs demand by product meaningful.

**30. What is a degenerate dimension?**

An identifier with no attributes, kept on the fact table: order_id, po_number, run_id. Making a dimension for it would add a join and no value.

**31. What is a periodic snapshot fact and why is inventory one?**

A fact with one row per entity per period showing its state (stock on hand each Sunday). Inventory is a state, not an event, so snapshots are the natural fit. The measures are semi-additive: you may sum across products or warehouses but not across dates.

**32. Normalisation vs denormalisation?**

Normalisation removes redundancy for transactional integrity (OLTP). Denormalisation duplicates descriptive data for fast reads (OLAP). The staging layer is closer to normalised source form; dw is denormalised.

**33. Where do you have a many-to-many relationship and how did you handle it?**

Product and material (a bill of materials). A bridge table with two one-to-many relationships resolves it. In Power BI the bridge is hidden, filters flow from Product and Material into it, and no bidirectional filter is used. Cross-filtering products to their suppliers is done with TREATAS in a measure.

**34. How do you handle role-playing dimensions?**

One physical dim_date with several foreign keys from a fact (order, ship, promised, delivered). In SQL I join the alias I need; in Power BI one relationship is active and the others inactive, used with USERELATIONSHIP.

**35. What are the checks that keep the warehouse trustworthy?**

Row reconciliation (raw = staging + rejects), NULL critical keys, orphan foreign keys, duplicate business keys and grain, impossible values, invalid dates and statuses, and KPI identities such as fact_orders revenue = fact_order_items revenue to the cent. 166 checks, all passing.

**36. How do you model cancelled orders and revenue?**

A dim_order_status with `is_revenue_recognized`, and fact columns `recognized_revenue` (0 unless shipped) next to `net_amount` (always the order value). Revenue = SUM(recognized_revenue); revenue lost = net_amount of cancelled/backordered orders.


## D. Power BI and DAX

**37. Measure vs calculated column?**

A calculated column is computed at refresh, stored in the model and evaluated per row; a measure is computed at query time in the current filter context. Use measures for aggregations (nothing in this model's KPI layer is a calculated column) and columns only for things you must slice or sort by.

**38. What is filter context vs row context?**

Filter context is the set of filters (slicers, rows, columns, CALCULATE arguments) applied to a calculation. Row context is the 'current row' inside an iterator or calculated column. Context transition (CALCULATE inside a row context) turns the current row into filters; I rely on it in [Repeat Customers].

**39. What does CALCULATE do?**

It evaluates an expression in a modified filter context: it adds, replaces or removes filters. `CALCULATE([Total Revenue], 'Order Status'[is_revenue_recognized] = TRUE())` adds a filter; `REMOVEFILTERS('Date')` removes date filters (used for lifetime value and cohorts).

**40. What is the difference between ALL, ALLSELECTED and REMOVEFILTERS?**

ALL / REMOVEFILTERS clear filters completely; ALLSELECTED clears the visual's own row/column filters but keeps the slicer selection, which makes it right for 'percent of total in the current selection', as in [Revenue % of Total].

**41. How does time intelligence work and what does it require?**

Functions like TOTALYTD, SAMEPERIODLASTYEAR and DATESINPERIOD shift the date filter. They require a contiguous Date table marked as the date table. Mine has one row per day for 2023-2026 and is marked on full_date.

**42. Why does the model have inactive relationships?**

Because several facts have more than one date (order, ship, promised, delivered) and Power BI allows only one active relationship between two tables. Inactive ones are switched on per measure with USERELATIONSHIP.

**43. Why single-direction relationships?**

They are predictable and fast and avoid ambiguity. Bidirectional filters can create multiple filter paths and wrong totals. I cross-filter through the BOM bridge with TREATAS instead.

**44. How do you handle a semi-additive measure like inventory in DAX?**

Take the last snapshot inside the selected period: `VAR _d = MAX(Inventory[snapshot_date_key]) RETURN CALCULATE(SUM(...), Inventory[snapshot_date_key] = _d)`. Summing stock over weeks would count the same unit repeatedly.

**45. How is OEE calculated in DAX and why from sums?**

[OEE] = [Availability] * [Performance] * [Quality], each a DIVIDE of summed numerator and denominator. Averaging per-run ratios would weight a 10-minute run the same as a full shift, which gives the wrong answer.

**46. What is DIVIDE and why use it?**

DIVIDE(a, b) returns BLANK (or a chosen alternative) when b is zero or blank instead of an error, which keeps visuals clean.

**47. How do drill-through and tooltips work here?**

The 'Investigate Product' page has Product[product_name] as a drill-through field. Right-clicking a product on pages 2, 4, 9 or 10 opens it with that product filtered and 'Keep all filters' on. Tooltip pages are small report pages assigned to a visual.

**48. How do you keep a Power BI model fast?**

Import mode, a star schema, integer keys, no bidirectional filters, no calculated columns for KPIs, hidden technical columns, auto date/time off, and only the columns used. Heaviest table here is the 1.2M-row inventory snapshot.

**49. Import vs DirectQuery?**

Import copies data into the compressed in-memory model (fast, full DAX, needs refresh). DirectQuery sends queries to the database at view time (fresh data, slower, limited DAX). Import suits this 3.1M-row model.

**50. What is the control tower page and how is it built?**

Eight status tiles (suppliers to customers), each with one KPI measure and a colour measure that returns green/amber/red from documented thresholds. A decomposition tree explains unfulfilled order value by category, plant, warehouse and product, and a problem-product table drills through to a page that follows that product through orders, stock, production, materials and suppliers.


## E. Business analytics

**51. Define OEE and give typical benchmarks.**

OEE = Availability x Performance x Quality. Availability: run time / planned time. Performance: actual output / output at rated speed. Quality: good units / total units. Around 85% is often cited as world-class; 60% is common. In this dataset the company is 68.4%.

**52. Define inventory turnover and days of inventory.**

Turnover = COGS / average inventory value, annualised; days of inventory = 365 / turnover. Higher turnover means less cash tied up, but too high can mean stockouts.

**53. What is a stockout rate and how did you define it?**

Share of active product-warehouse-weeks with zero stock on hand. 'Active' means launched at least 30 days ago, so unlaunched products do not count as stockouts.

**54. How do you measure supplier performance fairly?**

With defined metrics, not opinions: on-time % (received on or before promised date), lead time vs promised, rejection rate and OTIF; a minimum volume (100 deliveries) before comparing; and neutral bands (A-D) rather than best/worst labels.

**55. What is AOV and why did yours fall?**

Average order value = recognised revenue / shipped orders. It fell from $250 (2023) to $236 (2025), consistent with deeper discounting; I would confirm by comparing average list price per order against discount rate rather than assume.

**56. How do you measure customer retention and cohorts?**

Group customers by the month of their first order; for each later month count how many ordered again and divide by the cohort size. In the model it is `months_since_first_order` on the order fact plus `cohort_month` on the customer dimension.

**57. Gross margin vs markup?**

Margin = profit / revenue; markup = profit / cost. A product costing $60 sold at $100 has 40% margin and 66.7% markup.

**58. What is fulfilment rate vs on-time delivery?**

Fulfilment rate = units shipped / units ordered (did we have it?). On-time delivery % = shipments delivered by the promised date / shipments (did it arrive when promised?).


## F. Project-specific deep questions

**59. How do you prove your KPIs are right?**

Each headline KPI is computed two independent ways (e.g. revenue from the order table vs the line table, OEE as A x P x Q vs good/capacity), the Power BI cards must match `docs/kpi_reference_values.md`, and 166 DQ checks run on every build.

**60. Why does your staging layer log rejects instead of fixing everything?**

Fixing silently hides the problem. Rejects keep an audit trail and reconcile row counts. Where the business can live with a gap I keep the row (missing supplier goes to an Unknown member) and flag it.

**61. How did you merge duplicate customers?**

Duplicates were injected with a new id, lower-cased first name and upper-cased last name but the same e-mail. I lower-case and trim the e-mail, partition by it, keep one survivor, and map every old id to the survivor through `staging.customer_map` so orders are repointed. Real-world matching would need fuzzy logic and review.

**62. Why were some order statuses repaired and others left Unknown?**

If an order with an invalid status has a shipment, the shipment proves it shipped, so I set Delivered or In Transit. Without a shipment it could be cancelled or backordered; guessing would invent data, so it stays Unknown (23 orders stay Unknown and are excluded from revenue; 226 were repaired from their shipment).

**63. How does a supplier delay reach the customer in your data?**

Late PO -> raw-material days of supply fall -> machines record material-shortage downtime -> output drops -> plant finished-goods and warehouse replenishment shrink -> stockouts and backorders -> dispatch delays and cancellations. Q69, Q70 and Q79 follow each step, and the report calls it an association, not proof.

**64. Where could your analysis be misleading?**

Repeat rate for 2025 customers is lower partly because they have had less time; January 2023 shortage hours reflect simulation start-up; stockout and dispatch correlation (0.88) does not exclude other causes; and all numbers come from a simulation.

**65. How would you add forecasting without changing the BI focus?**

Replace the trailing-average expected demand in `analytics.v_demand_supply_product` with a seasonal baseline (same month last year x trend) in SQL, keeping the same columns so Power BI is unchanged. ML was out of scope.

**66. How would you productionise the pipeline?**

Schedule `run_pipeline.py` (cron, Airflow or GitHub Actions), make loads incremental, add unit tests for cleaning functions, alert on failed DQ checks, version the SQL, and give Power BI a read-only database role with gateway-based refresh.

**67. What did you learn about calibrating a simulation?**

Run small experiments and measure outcomes by year and by month; a model that is stable for 2023 can break in 2025 under growth. Growth had to be built into capacity, otherwise the demo story turned into 'everything collapses in the last year'.

**68. What are the limits of the Docker setup?**

`docker-compose.yml` starts PostgreSQL 16 with a healthcheck and a volume. I validated the pipeline against a local PostgreSQL 16 server; the compose file itself was not run in my build environment, so confirm with `docker compose up -d` and `docker compose ps` on your machine.


## Quick facts to memorise

| Fact | Value |
|---|---|
| Facts / dimensions | 13 fact tables, 15 dimensions + 1 bridge |
| Rows in the biggest tables | Inventory 1.18M, Material consumption 561k, Order items 600k |
| SQL | 81 analytical queries, 166 automated DQ checks, 73 declared foreign keys |
| DAX | about 200 measures in 10 display folders |
| Report | 10 pages + drill-through + tooltip pages |
| Headline results | Revenue $56.6M (2023-25), margin 35.7%, OEE 68.4%, supplier on-time 87.2%, delivery on-time 81.7%, return rate 6.5% |
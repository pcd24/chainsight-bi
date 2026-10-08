# Business Requirements

## 1. Project definition

**ChainSight** is an end-to-end Business Intelligence platform for the fictional company **NovaTech Manufacturing & Commerce**, which makes consumer-technology products (smart-home devices, computer/mobile accessories, audio, wearables, networking, gaming accessories) and sells them through its own e-commerce platform.

The platform connects one chain in a single warehouse so a manager can start from a customer problem and trace it back to its cause:

`Supplier -> Purchase order -> Raw material -> Manufacturing -> Quality -> Finished goods -> Warehouse -> E-commerce order -> Shipment -> Delivery -> Return`

> The data is **synthetic**. NovaTech does not exist and nothing in this project describes a real company.

## 2. Business scenario

| Item | Value |
|---|---|
| Time span | 1 Jan 2023 - 31 Dec 2025 (36 months) |
| Products | 500 across 7 categories |
| Customers | 20,000 (about 14,700 placed a non-cancelled order) |
| Plants / machines | 5 plants, 110 machines, 2 shifts per day |
| Warehouses | 15 across 5 sales regions |
| Suppliers / materials | 110 suppliers (plus one "unknown" member), 68 raw materials |
| Carriers | 5 (Express, Standard, Economy service levels) |
| Business model | Make-to-stock: plants build finished goods, warehouses hold them, orders ship from the warehouse |

## 3. Business questions the platform answers

1. How much revenue and profit are we making, and how fast are we growing?
2. Which products and categories drive revenue and profit? Where is margin eroding?
3. Which customers are valuable, and who is leaving?
4. Which products are returned, and why?
5. Which warehouses have stockout or excess problems? Which products may run out?
6. Which suppliers are late or send poor-quality material?
7. Which plants and machines lose the most output to downtime and defects?
8. How does supplier performance affect manufacturing, inventory, orders and delivery?
9. Where is the company losing money (discounts, returns, cancellations, scrap, downtime)?
10. What should management investigate first?

## 4. User personas

| Persona | Needs | Pages |
|---|---|---|
| Executive | One-screen health check and top risks | 1, 10 |
| E-commerce manager | Revenue, margin, discounts, returns | 2 |
| CRM / customer analyst | Segments, cohorts, value | 3 |
| Supply planner | Stockout, excess, demand vs supply | 4, 9 |
| Procurement manager | Supplier reliability, quality, cost | 5 |
| Plant manager | OEE, defects, capacity | 6 |
| Maintenance manager | Failures, downtime Pareto, PM mix | 7 |
| Logistics manager | Carrier and warehouse delivery performance | 8 |
| Operations lead | End-to-end chain status and root-cause drill | 10, drill-through |

## 5. Functional requirements

| ID | Requirement | Where it is met |
|---|---|---|
| FR1 | Reproducible synthetic source data with realistic cause-and-effect | `scripts/generate_data.py` |
| FR2 | RAW layer that preserves source data, including quality problems | `sql/02_raw`, `scripts/load_data.py` |
| FR3 | Staging that cleans, types, de-duplicates and logs every rejected row | `sql/03_staging` |
| FR4 | Star-schema warehouse with documented grain, keys and conformed dimensions | `sql/04_dimensions`, `sql/05_facts`, `docs/dimensional_model.md` |
| FR5 | Automated data-quality checks (NULLs, duplicates, orphans, impossible values, dates, statuses, grain) | `sql/06_quality` |
| FR6 | 50+ analytical SQL queries across e-commerce, customers, inventory, suppliers, manufacturing, logistics, cross-domain | `sql/08_analytics` (81 queries) |
| FR7 | Power BI model specification, DAX library, 12 page specifications | `powerbi/` |
| FR8 | Control tower with RAG status per chain stage and a drill path to root cause | page 10 and the drill-through page |
| FR9 | At least 15 evidence-based insights and a management report | `docs/insights.md`, `docs/management_report.md` |
| FR10 | One-command, repeatable build and validation | `scripts/run_pipeline.py` |

## 6. Non-functional requirements

* **Reproducible**: fixed seed (42); the same command gives the same data and the same KPIs.
* **Scalable to the laptop**: `--scale 0.1` produces a 10% dataset that runs the same pipeline.
* **Safe**: no secrets in the repo (`.env.example` only); the raw layer is never edited.
* **Trustworthy**: raw rows = staging rows + logged rejects; KPIs cross-checked two ways.
* **Understandable**: simple names, documented grain, no unnecessary technology, no machine learning.
* **Honest**: synthetic data; correlations are labelled as associations, not causes.

## 7. Scope decisions and assumptions

1. **Revenue recognition**: revenue counts when the order ships (Delivered or In Transit). Cancelled and backordered order value is reported separately as revenue not fulfilled.
2. **Fiscal year** starts 1 April (fiscal fields exist in the Date table; calendar year is used in the report).
3. **Costs**: unit cost rises for Audio and Gaming in 2024-2025 while list prices stay flat (a deliberate margin-pressure scenario).
4. **Inventory snapshots are weekly** (Sundays) to keep the table at 1.2M rows. Lot-level age is not in the source, so ageing is approximated by "days since last sale".
5. **No separate category table**: category lives inside the product dimension (star, not snowflake).
6. **No employee dimension**: the source has no operator-level data, so `DimEmployee` was deliberately not created rather than filled with invented data.
7. **Production run volume**: the production fact has 121,081 run records (machine x shift x day) against a stretch target of 300,000. The simulation is a demand-driven pull system, so runs are created only when stock needs replenishing. Detail-level volume is covered by 561,000 material-consumption rows and 153,000 downtime events.

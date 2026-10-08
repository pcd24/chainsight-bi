# DAX measure library

All measures live in one empty table called `_Measures` (create with *Enter Data* -> one blank column, then hide the column).
Each `.dax` file is one **display folder**. Paste a measure at a time (Modeling > New measure) - the first line of each
block, `Name = ...`, is the measure name. `// Format:` lines give the number format to set in Measure tools.

Table names used below are the **Power Query names** from `powerbi/model/power_query_load.m.txt`:
`Date, Customer, Product, Supplier, Material, Warehouse, Plant, Machine, Carrier, Promotion, Location, Order Status,
Return Reason, Defect Type, Downtime Type, BOM, Orders, Order Items, Shipments, Returns, Inventory, Material Inventory,
Purchases, Supplier Deliveries, Production, Material Consumption, Downtime, Maintenance, Defects, Product Supply Position`.

Conventions
* **Revenue is recognised revenue**: only shipped orders (Delivered, In Transit). Cancelled/backordered value is reported separately.
* Ratios are always `DIVIDE(sum, sum)` of aggregated numerators/denominators - never an average of row-level ratios.
* Snapshot tables (Inventory, Material Inventory) are semi-additive: stock measures use the **last snapshot in the selected period**.
* Role-playing dates: the *active* relationship is used by default; other dates use `USERELATIONSHIP` measures (see 11_role_playing_dates.dax).
* Every measure here was designed against the SQL in `sql/08_analytics`; `docs/kpi_reference_values.md` lists the expected card values
  so you can check your Power BI report against PostgreSQL.

# Dashboard specifications

Eleven report pages plus tooltip pages. Build them in this order (1 -> 10, then 11, 12). Every visual lists its fields, formatting and interactions so the report can be recreated exactly. Measure names in square brackets are in `powerbi/dax/`.

Global rules: theme `powerbi/theme/chainsight_theme.json`; fonts Segoe UI; KPI cards 150 x 76; no 3D, no decorative gauges; maximum one pie/donut (page 3, optional); numbers formatted per measure; every page filtered to `Date[is_actuals] = TRUE`.

| Page | File | Question |
|---|---|---|
| 1 Executive Command Center | `page01_executive_command_center.md` | How is the company performing overall? Where should leadership look first? |
| 2 E-Commerce Performance | `page02_ecommerce_performance.md` | Which products, categories and regions drive revenue and profit, and where do discounts and returns hurt? |
| 3 Customer Intelligence | `page03_customer_intelligence.md` | Is growth from new or returning customers? Which segments are valuable and which are slipping away? |
| 4 Inventory & Warehouse | `page04_inventory_warehouse.md` | Which warehouses and products have stockout or excess problems, and how fast does stock turn? |
| 5 Supplier Intelligence | `page05_supplier_intelligence.md` | Which suppliers show delivery or quality risk, and where are we dependent on one supplier? |
| 6 Manufacturing Intelligence | `page06_manufacturing_intelligence.md` | Which plants are inefficient, and is the cause availability, performance or quality? |
| 7 Machine & Maintenance | `page07_machine_maintenance.md` | Which machines and causes explain most downtime, and is maintenance reactive? |
| 8 Logistics & Fulfilment | `page08_logistics_fulfilment.md` | Are deliveries late because of the warehouse (slow dispatch) or the carrier (slow transit)? |
| 9 Demand & Supply Planning | `page09_demand_supply_planning.md` | Which products will run short, which have excess, and where is demand above proven capacity? |
| 10 End-to-End Control Tower | `page10_end_to_end_control_tower.md` | Where is the chain breaking right now, and what upstream stage is behind it? |
| 11 Investigate Product (drill-through, hidden) | `page11_investigate_product_drillthrough.md` | Why are deliveries delayed for this product? |
| 12 Tooltip pages (hidden): TT Product, TT Plant, TT Supplier | `page12_tooltip_pages.md` | - |

#!/usr/bin/env python3
"""Build docs/dimensional_model.md from the live warehouse catalog (columns, FKs) plus curated business metadata."""
import os
from db import connect, ROOT

FACTS = {
 "fact_orders": ("Order-to-cash", "One row per customer order.", "order_key (surrogate); order_id degenerate dimension, UNIQUE",
   ["order_count", "line_count", "units", "gross_amount", "discount_amount", "net_amount", "cogs_amount", "gross_profit_amount", "recognized_revenue", "recognized_cogs", "recognized_gross_profit", "days_to_ship"],
   "Order-level measures: order counts, cancellation, fulfilment speed, customer order sequence (new vs returning, cohorts). Revenue by product is read from fact_order_items."),
 "fact_order_items": ("Order-to-cash", "One row per product line within an order.", "order_item_key (surrogate); order_item_id UNIQUE; order_key links to fact_orders",
   ["quantity", "unit_price", "discount_pct", "gross_amount", "discount_amount", "net_amount", "cogs_amount", "gross_profit_amount", "recognized_revenue", "recognized_cogs", "recognized_gross_profit"],
   "Product-level revenue, margin and discount analysis. Carries order status and dispatch delay so product problems can be sliced."),
 "fact_shipments": ("Outbound logistics", "One row per shipment (one per shipped order).", "shipment_key (surrogate); shipment_id UNIQUE",
   ["shipment_count", "shipping_cost", "weight_kg", "days_to_ship", "transit_days", "order_to_delivery_days", "days_late", "on_time_flag", "delayed_flag"],
   "Delivery speed, carrier and warehouse reliability, shipping cost."),
 "fact_returns": ("Returns", "One row per return record against one order line.", "return_key (surrogate); return_id UNIQUE",
   ["quantity_returned", "refund_amount", "days_to_return", "restocked_flag"], "Return rate and reasons, linked to product, customer and warehouse."),
 "fact_inventory_snapshot": ("Inventory management", "One row per product, per warehouse, per weekly (Sunday) snapshot.", "inventory_key (surrogate); UNIQUE (snapshot_date_key, product_key, warehouse_key)",
   ["qty_on_hand", "qty_backordered", "qty_in_transit", "inventory_value", "units_ordered_week", "demand_4w", "days_of_cover", "days_since_last_sale", "stockout_flag", "low_stock_flag", "excess_flag", "excess_qty", "excess_value"],
   "Periodic snapshot: stock levels are semi-additive (never sum across dates)."),
 "fact_material_inventory_snapshot": ("Raw material inventory", "One row per material, per plant, per weekly snapshot.", "material_inventory_key (surrogate); UNIQUE (snapshot_date_key, plant_key, material_key)",
   ["qty_on_hand", "qty_on_order", "inventory_value", "consumption_4w", "days_of_supply", "low_supply_flag"], "Raw-material cover; connects supplier delays to production."),
 "fact_purchases": ("Procurement", "One row per purchase-order line (one material, one supplier, one plant).", "purchase_key (surrogate); po_line_id UNIQUE; po_number degenerate",
   ["quantity_ordered", "unit_price", "ordered_amount", "standard_amount", "price_variance_amount", "promised_lead_days", "qty_received", "qty_rejected", "received_flag"], "Spend, price variance, open orders."),
 "fact_supplier_deliveries": ("Goods receipt", "One row per delivery receipt against a purchase-order line.", "delivery_key (surrogate); receipt_id UNIQUE",
   ["delivery_count", "qty_received", "qty_rejected", "qty_accepted", "received_value", "actual_lead_days", "promised_lead_days", "days_late", "on_time_flag", "late_flag", "in_full_flag"], "Supplier on-time, lead time and quality."),
 "fact_production": ("Manufacturing", "One row per production run = one product on one machine in one shift on one date.", "production_key (surrogate); run_id UNIQUE; UNIQUE (date_key, shift, machine_key)",
   ["planned_minutes", "operating_minutes", "downtime_minutes", "material_shortage_minutes", "equipment_failure_minutes", "changeover_minutes", "capacity_units", "ideal_units", "total_units", "good_units", "defect_units"], "OEE (availability x performance x quality), capacity, supply-driven loss."),
 "fact_material_consumption": ("Manufacturing (derived)", "One row per material consumed by one production run (units made x bill of materials).", "consumption_key (surrogate); UNIQUE (production_key, material_key)",
   ["quantity_consumed", "consumption_value"], "Links finished goods to the raw materials and suppliers they depend on."),
 "fact_downtime": ("Machine downtime", "One row per downtime event (one cause within one production run).", "downtime_key (surrogate); downtime_id UNIQUE",
   ["duration_minutes", "duration_hours", "lost_units_est", "is_planned_flag"], "Downtime Pareto, machine ranking, production loss."),
 "fact_maintenance": ("Maintenance", "One row per maintenance work order on one machine.", "maintenance_key (surrogate); work_order_id UNIQUE",
   ["work_order_count", "corrective_flag", "duration_hours", "cost"], "Maintenance frequency, preventive vs corrective mix, cost."),
 "fact_defects": ("Quality inspection", "One row per defect type recorded within one production run.", "defect_key (surrogate); UNIQUE (production_key, defect_type_key)",
   ["defect_qty", "scrap_cost"], "Defect analysis by type, product, machine."),
}
DIMS = {
 "dim_date": ("Calendar: every day 2023-2026 with week, month, quarter, fiscal fields and sort columns.", "date_key (yyyymmdd int)", "full_date", "Role-playing: used by all facts, several times in some."),
 "dim_customer": ("Who buys. Includes first-order cohort and behavioural segment as of 2025-12-31.", "customer_key", "customer_id", "Type 1. Duplicates merged in staging."),
 "dim_product": ("What we sell. Category and sub-category are attributes here (star, not snowflake).", "product_key", "product_id", "Type 1."),
 "dim_supplier": ("Who supplies raw materials; S000 stands for 'supplier missing in source'.", "supplier_key", "supplier_id", "Type 1."),
 "dim_material": ("Raw materials and components.", "material_key", "material_id", "Type 1."),
 "dim_warehouse": ("Finished-goods warehouses.", "warehouse_key", "warehouse_id", "Type 1."),
 "dim_plant": ("Manufacturing plants.", "plant_key", "plant_id", "Type 1."),
 "dim_machine": ("Machines, with plant and production line (hierarchy Plant > Line > Machine).", "machine_key", "machine_id", "Type 1."),
 "dim_carrier": ("Logistics carriers.", "carrier_key", "carrier_id", "Type 1."),
 "dim_promotion": ("Promotions; key 0 = No Promotion so no NULL foreign keys.", "promotion_key", "promotion_id", "Type 1."),
 "dim_location": ("Geography. Conformed across customer, warehouse and plant attributes; used directly for shipment destination.", "location_key", "location_id", "Type 1."),
 "dim_order_status": ("Order status with an is_revenue_recognized flag.", "order_status_key", "order_status", "Static lookup."),
 "dim_return_reason": ("Return reasons grouped into Quality / Fulfilment / Customer choice.", "return_reason_key", "return_reason", "Static lookup."),
 "dim_defect_type": ("Manufacturing defect types.", "defect_type_key", "defect_type", "Static lookup."),
 "dim_downtime_type": ("Downtime causes with planned flag and loss category.", "downtime_type_key", "downtime_type", "Static lookup."),
 "bridge_product_material": ("Bill of materials: which materials each product uses and how many per unit.", "(product_key, material_key)", "-", "Many-to-many bridge."),
}


def main():
    cur = connect().cursor()
    cur.execute("""SELECT tc.table_name, kcu.column_name, ccu.table_name FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
        JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'dw' ORDER BY 1, 2""")
    fks = cur.fetchall()
    used_by = {}
    for t, c, rt in fks:
        used_by.setdefault(rt, set()).add(t)
    def cnt(t):
        cur.execute(f"SELECT count(*) FROM dw.{t}")
        return cur.fetchone()[0]
    def cols(t):
        cur.execute("SELECT column_name FROM information_schema.columns WHERE table_schema='dw' AND table_name=%s ORDER BY ordinal_position", (t,))
        return [r[0] for r in cur.fetchall()]
    L = ["# Dimensional Model", "",
         "Generated by `scripts/generate_model_doc.py` from the live warehouse (foreign keys and columns come from the PostgreSQL catalog), so it always matches the database.", "",
         "![star schema](../diagrams/star_schema.png)", "", "![ER diagram](../diagrams/er_diagram.png)", "",
         "## Modelling decisions (and what an interviewer may ask)", "",
         "| Decision | Reason |", "|---|---|",
         "| Constellation of stars: 13 facts, shared (conformed) dimensions | Each business process has its own grain; shared Date, Product, Warehouse, Plant, Customer, Material, Supplier and Machine let you compare processes |",
         "| Surrogate integer keys + business keys kept | Small, fast joins and insulation from source changes; business keys stay unique-indexed for traceability |",
         "| Category inside `dim_product` (no `dim_category`) | Star not snowflake: fewer joins, a single hierarchy, simpler Power BI model |",
         "| Weekly periodic snapshots for inventory | Stock is a state, not an event; snapshots make stockout, cover and trend queries simple. Weekly keeps 1.2M rows rather than 3.6M |",
         "| Revenue recognised at shipment (`recognized_revenue`) | Cancelled and backordered orders must not inflate revenue, but their value is needed to measure revenue lost |",
         "| Degenerate dimensions (`order_id`, `po_number`, `run_id`) kept on the fact | They have no attributes worth a dimension |",
         "| Type 1 dimensions (overwrite) | The source holds no history. If product price or customer address history mattered, `dim_product` and `dim_customer` would become Type 2 (add valid_from, valid_to, is_current) |",
         "| Bridge for BOM | Product-material is a true many-to-many; a bridge keeps both facts and dimensions at their natural grain |",
         "| No fact-to-fact relationships | Facts are combined through conformed dimensions, never joined directly (avoids fan-out and double counting) |", "",
         "## Fact tables", ""]
    for t, (proc, grain, key, measures, why) in FACTS.items():
        myfks = [(c, rt) for tt, c, rt in fks if tt == t]
        L += [f"### `{t}`", "", f"* **Business process:** {proc}", f"* **Grain:** {grain}", f"* **Key strategy:** {key}", f"* **Rows:** {cnt(t):,}",
              f"* **Why it exists:** {why}", f"* **Measures / additive columns:** {', '.join('`'+m+'`' for m in measures)}",
              "* **Foreign keys (declared in PostgreSQL):** " + ", ".join(f"`{c}` -> `{rt}`" for c, rt in myfks),
              "* **Related dimensions:** " + ", ".join(sorted({rt.replace('dim_', '') for c, rt in myfks})), ""]
    L += ["## Dimension tables and bridge", ""]
    for t, (purpose, sk, bk, scd) in DIMS.items():
        attrs = [c for c in cols(t) if not c.endswith("_key")]
        L += [f"### `{t}`", "", f"* **Purpose:** {purpose}", f"* **Surrogate key:** {sk}", f"* **Business key:** {bk}", f"* **History handling:** {scd}", f"* **Rows:** {cnt(t):,}",
              "* **Attributes:** " + ", ".join(f"`{a}`" for a in attrs), "* **Used by facts:** " + (", ".join(f"`{u}`" for u in sorted(used_by.get(t, []))) or "-"), ""]
    L += ["## Grain verification", "",
          "Every fact grain is enforced in PostgreSQL with a UNIQUE constraint (see the `uq_*_grain` constraints) and re-checked by `dq.check_results` category *Duplicates / grain*. A load that violated a grain would fail rather than double-count.", ""]
    open(os.path.join(ROOT, "docs", "dimensional_model.md"), "w", encoding="utf-8").write("\n".join(L))
    print("ok", len(FACTS), "facts", len(DIMS), "dims/bridge")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Build docs/data_dictionary.md from the live warehouse (table comments + column metadata + curated column notes)."""
import os, re
from db import connect, ROOT

NOTES = {
 "category": "Product category (7 official labels after standardisation)", "sub_category": "Product sub-category (e.g. Earbuds)", "category_scope": "Categories a promotion applies to",
 "channel": "Web or Mobile App", "city": "City", "country": "Country", "region": "Sales region (5 regions)", "state_province": "State / province",
 "current_unit_cost": "2025 unit cost (cost used for current valuation)", "day_of_month": "Day number in month", "day_of_week_num": "1 = Monday ... 7 = Sunday",
 "defect_type": "Defect category", "detection_stage": "Where the defect was caught (In-line Inspection / Final Test)", "disposition": "Scrap or Rework",
 "discount_pct": "Discount as a fraction (0.15 = 15%)", "downtime_type": "Cause of downtime", "email": "Customer e-mail (lower-case; used to merge duplicates)",
 "end_date": "Promotion end date", "start_date": "Promotion start date", "fiscal_quarter": "Fiscal quarter 1-4 (fiscal year starts 1 April)", "install_year": "Year the machine was installed",
 "is_month_end": "TRUE on the last day of the month", "iso_week": "ISO week number", "last_order_date": "Date of last non-cancelled order", "launch_date": "Product launch date",
 "line_count": "Number of order lines", "list_price": "List (catalogue) price", "loss_category": "Grouping of downtime causes (Supply, Equipment failure, Changeover, Other)",
 "machine_type": "Type of machine", "maintenance_type": "Preventive or Corrective", "manufacturer": "Machine manufacturer", "marketing_opt_in": "Y/N marketing consent",
 "material_family": "Material group (e.g. PCB Board)", "month_num": "Month number 1-12", "month_short": "Jan, Feb, ...", "month_start_date": "First day of the month", "month_year": "Label such as 'Mar 2024'; sort by month_year_sort",
 "opened_year": "Year the plant opened", "order_status": "Status label", "payment_method": "Payment method", "payment_terms_days": "Supplier payment terms in days",
 "plant_line": "Plant / production line label (hierarchy helper)", "po_number": "Purchase order number (one PO can have several lines)", "primary_plant": "Plant that manufactures the product",
 "production_line": "Production line within a plant", "promotion_type": "Seasonal, Event or Clearance", "qty_on_order": "Raw material units on open purchase orders",
 "qty_received": "Units received from supplier", "qty_rejected": "Received units rejected at inspection", "quantity": "Units on the order line", "quantity_ordered": "Units ordered from supplier",
 "quarter_num": "Quarter number 1-4", "quarter_year": "Label such as 'Q2 2024'; sort by quarter_year_sort", "quoted_lead_time_days": "Lead time the supplier quotes",
 "reason_group": "Quality, Fulfilment or Customer Choice / Expectation", "region": "Sales region", "return_reason": "Reason given for the return", "service_level": "Express, Standard or Economy",
 "shift": "Shift number (1 or 2)", "shipping_cost": "Cost of shipping the order", "signup_date": "Account creation date", "sku": "Stock keeping unit code", "standard_cost": "Planned cost per unit of material",
 "status_group": "Fulfilled, Unfulfilled, Lost or Unresolved", "status_sort": "Sort order for status labels", "supplier_tier": "Tier 1-3", "unit_of_measure": "Unit (EA = each)",
 "unit_price": "Price per unit (list price on orders; price paid on purchases)", "units": "Total units on the order", "units_ordered_week": "Units ordered in the week ending on the snapshot date",
 "week_start_date": "Monday of the week", "weight_kg": "Weight in kg", "year_num": "Calendar year", "po_number_": "", "payment_terms": "",
 # keys / generic
 "date_key": "Date as integer yyyymmdd; joins to dim_date.date_key", "full_date": "Calendar date", "is_actuals": "TRUE for dates up to the last data date (2025-12-31)",
 "month_year_sort": "Numeric yyyymm; use as Sort By Column for month_year", "quarter_year_sort": "Numeric yyyyq; Sort By Column for quarter_year",
 "fiscal_year": "Fiscal year, starting 1 April (FY2024 = Apr 2023 - Mar 2024)", "is_weekend": "TRUE for Saturday/Sunday",
 "order_count": "Constant 1 per row; SUM gives order count", "shipment_count": "Constant 1 per row", "delivery_count": "Constant 1 per row", "work_order_count": "Constant 1 per row",
 "recognized_revenue": "Net revenue (after discount) for shipped orders (Delivered, In Transit); 0 otherwise",
 "recognized_cogs": "Cost of goods sold for shipped orders; 0 otherwise", "recognized_gross_profit": "recognized_revenue - recognized_cogs",
 "net_amount": "Order value after discount, regardless of status (use for revenue-at-risk)", "gross_amount": "Quantity x list price before discount",
 "discount_amount": "gross_amount - net_amount", "cogs_amount": "Quantity x unit cost (cost of the order year)", "gross_profit_amount": "net_amount - cogs_amount (any status)",
 "days_to_ship": "Days from order date to shipment date (NULL if not shipped)", "fulfilment_delayed_flag": "1 if dispatch took more than 2 days",
 "customer_order_seq": "1 = customer's first non-cancelled order, 2 = second...; NULL for cancelled orders", "is_first_order": "1 if this is the customer's first non-cancelled order",
 "months_since_first_order": "Whole months between the customer's cohort month and this order (cohort analysis)", "status_inferred_flag": "TRUE if an invalid source status was repaired from the shipment record",
 "transit_days": "delivered date - ship date", "order_to_delivery_days": "delivered date - order date", "days_late": "delivered/received date - promised date (negative = early)",
 "on_time_flag": "1 = on or before promised date, 0 = late, NULL = not delivered / date unreadable", "delayed_flag": "1 = delivered after promised date",
 "delivered_flag": "1 if a delivered date exists", "delivered_date_unreadable_flag": "TRUE if source delivered date was invalid and was nulled in staging",
 "qty_on_hand": "Units in stock at snapshot", "qty_backordered": "Customer units waiting for stock at snapshot", "qty_in_transit": "Units on the way from plant to warehouse",
 "inventory_value": "qty_on_hand x unit cost (cost of the snapshot year)", "demand_4w": "Units ordered (non-cancelled) in the 4 weeks to the snapshot", "days_of_cover": "qty_on_hand / average daily demand over last 4 weeks (NULL if no demand)",
 "days_since_last_sale": "Days since the product last sold in this warehouse (inventory ageing proxy; lot-level age is not in the source)",
 "active_sku_flag": "1 if product has been launched for 30+ days (denominator for stockout rate)", "stockout_flag": "1 if active product has zero stock on hand",
 "low_stock_flag": "1 if stock covers less than 7 days of demand", "excess_flag": "1 if 10+ units on hand and more than 90 days of cover (or no demand)",
 "excess_qty": "Units above 90 days of demand for excess rows", "excess_value": "excess_qty x unit cost", "unit_cost": "Unit cost used for valuation",
 "consumption_4w": "Material consumed in the 4 weeks to the snapshot", "days_of_supply": "qty_on_hand / average daily consumption", "low_supply_flag": "1 if less than 7 days of supply",
 "ordered_amount": "quantity_ordered x unit_price", "standard_amount": "quantity_ordered x material standard cost", "price_variance_amount": "ordered_amount - standard_amount (positive = paid above standard)",
 "promised_lead_days": "Promised date - PO date", "actual_lead_days": "Received date - PO date", "late_flag": "1 if received after promised date", "in_full_flag": "1 if quantity received >= ordered",
 "qty_accepted": "qty_received - qty_rejected", "received_value": "qty_received x unit price", "rejected_value": "qty_rejected x unit price", "supplier_missing_flag": "1 if supplier id was missing in source (assigned to S000)",
 "received_flag": "1 if at least one receipt exists", "capacity_units": "Rated speed x planned minutes: maximum possible output", "ideal_units": "Rated speed x operating minutes: maximum output for the time actually run",
 "planned_minutes": "Scheduled minutes (480 per shift)", "operating_minutes": "planned_minutes - downtime_minutes", "downtime_minutes": "All lost minutes in the run",
 "material_shortage_minutes": "Minutes lost waiting for raw material", "equipment_failure_minutes": "Minutes lost to mechanical/electrical failure", "changeover_minutes": "Minutes lost changing product",
 "total_units": "Units produced (good + defective)", "good_units": "Units passing inspection", "defect_units": "Units failing inspection", "rated_units_per_min": "Machine rated speed for this product",
 "quantity_consumed": "Material units consumed = units made x quantity per unit (BOM)", "consumption_value": "quantity_consumed x standard cost", "duration_minutes": "Event duration in minutes", "duration_hours": "Event duration in hours",
 "lost_units_est": "duration x rated speed: output that could have been made", "is_planned_flag": "1 for planned downtime (changeover)", "corrective_flag": "1 for corrective (reactive) maintenance",
 "cost": "Maintenance cost; NULL when missing in source (excluded from averages)", "scrap_cost": "defect_qty x unit cost for scrapped defects", "defect_qty": "Units with this defect type",
 "quantity_returned": "Units returned", "refund_amount": "Money refunded", "days_to_return": "Return date - order date", "restocked_flag": "1 if returned units went back to stock",
 "customer_segment": "Behavioural segment as of 2025-12-31 (Champion, Loyal, Repeat, New, One-time, At Risk, Lost, No Purchase)", "cohort_month": "Month of the customer's first non-cancelled order",
 "first_order_date": "Date of first non-cancelled order", "lifetime_orders": "Count of non-cancelled orders", "price_tier": "Budget (<25), Mid (<80), Premium", "is_revenue_recognized": "TRUE for Delivered/In Transit",
 "qty_per_unit": "Material units needed per finished unit", "sourcing_share": "Planned share of a material bought from this supplier",
}


def describe(col, table=''):
    if table.startswith('dim_') and col == table[4:] + '_key':
        return 'Surrogate primary key of this dimension'
    if table.startswith('fact_') and col.endswith('_key') and col[:-4] == table[5:].replace('_snapshot','').replace('_items','_item'):
        return 'Surrogate primary key of this fact table'
    if col in NOTES:
        return NOTES[col]
    if col.endswith("_key") and col.split("_key")[0] in ("order", "order_item", "inventory", "purchase", "delivery", "production", "downtime", "maintenance", "defect", "return", "shipment", "consumption", "material_inventory"):
        return "Surrogate primary key of this fact table"
    if col.endswith("_key"):
        return "Surrogate key (foreign key to the matching dimension)" if not col.startswith(("customer_key",)) or True else ""
    if col.endswith("_id"):
        return "Business key from the source system"
    if col.endswith("_name"):
        return "Display name"
    return ""


def main():
    conn = connect()
    cur = conn.cursor()
    cur.execute("""SELECT c.relname, obj_description(c.oid), c.reltuples::bigint FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                   WHERE n.nspname = 'dw' AND c.relkind = 'r' ORDER BY (c.relname LIKE 'dim_%') DESC, c.relname""")
    tables = cur.fetchall()
    out = ["# Data Dictionary (generated)", "", "Generated by `scripts/generate_data_dictionary.py` from the live `dw` schema. Table comments hold purpose and grain; column notes are curated.", ""]
    for t, comment, _ in tables:
        cur.execute(f"SELECT count(*) FROM dw.{t}")
        n = cur.fetchone()[0]
        kind = "Dimension" if t.startswith("dim_") else ("Bridge" if t.startswith("bridge") else "Fact")
        out += [f"## dw.{t}", "", f"*{kind}* - {n:,} rows", "", comment or "", "", "| Column | Type | Description |", "|---|---|---|"]
        cur.execute("""SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'dw' AND table_name = %s ORDER BY ordinal_position""", (t,))
        for col, dt in cur.fetchall():
            out.append(f"| `{col}` | {dt} | {describe(col, t) or '-'} |")
        out.append("")
    path = os.path.join(ROOT, "docs", "data_dictionary.md")
    open(path, "w", encoding="utf-8").write("\n".join(out))
    print("wrote", path, len(tables), "tables")


if __name__ == "__main__":
    main()

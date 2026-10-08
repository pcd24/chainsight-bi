#!/usr/bin/env python3
"""
Compute the headline KPIs directly in PostgreSQL (the reference values your Power BI cards must match) and
cross-check each KPI through TWO independent paths (e.g. revenue from fact_orders vs fact_order_items).
Writes docs/kpi_reference_values.md and exits non-zero if any identity fails.
"""
import os, sys
from db import connect, ROOT

REF = {
 "Total Revenue (all time)": "SELECT round(sum(recognized_revenue),2) FROM dw.fact_order_items",
 "Gross Profit (all time)": "SELECT round(sum(recognized_gross_profit),2) FROM dw.fact_order_items",
 "Gross Margin % (all time)": "SELECT round(100*sum(recognized_gross_profit)/sum(recognized_revenue),2) FROM dw.fact_order_items",
 "Orders placed (all time)": "SELECT count(*) FROM dw.fact_orders",
 "Shipped orders (all time)": "SELECT count(*) FROM dw.fact_orders f JOIN dw.dim_order_status s USING (order_status_key) WHERE s.is_revenue_recognized",
 "AOV": "SELECT round(sum(recognized_revenue)/count(*) FILTER (WHERE s.is_revenue_recognized),2) FROM dw.fact_orders f JOIN dw.dim_order_status s USING (order_status_key)",
 "Units sold": "SELECT sum(quantity) FROM dw.fact_order_items i JOIN dw.dim_order_status s USING (order_status_key) WHERE s.is_revenue_recognized",
 "Cancellation rate %": "SELECT round(100.0*count(*) FILTER (WHERE s.order_status='Cancelled')/count(*),2) FROM dw.fact_orders f JOIN dw.dim_order_status s USING (order_status_key)",
 "Return rate % (returned / delivered units)": "SELECT round(100.0*(SELECT sum(quantity_returned) FROM dw.fact_returns)/(SELECT sum(quantity) FROM dw.fact_order_items i JOIN dw.dim_order_status s USING (order_status_key) WHERE s.order_status='Delivered'),2)",
 "Customers (non-cancelled buyers)": "SELECT count(DISTINCT customer_key) FROM dw.fact_orders f JOIN dw.dim_order_status s USING (order_status_key) WHERE s.order_status<>'Cancelled'",
 "Revenue 2025": "SELECT round(sum(recognized_revenue),2) FROM dw.fact_order_items i JOIN dw.dim_date d ON d.date_key=i.order_date_key WHERE d.year_num=2025",
 "Revenue 2024": "SELECT round(sum(recognized_revenue),2) FROM dw.fact_order_items i JOIN dw.dim_date d ON d.date_key=i.order_date_key WHERE d.year_num=2024",
 "Revenue YoY % (2025 vs 2024)": "SELECT round(100*(sum(recognized_revenue) FILTER (WHERE d.year_num=2025)/sum(recognized_revenue) FILTER (WHERE d.year_num=2024)-1),2) FROM dw.fact_order_items i JOIN dw.dim_date d ON d.date_key=i.order_date_key",
 "Inventory value (last snapshot)": "SELECT round(sum(inventory_value),2) FROM dw.fact_inventory_snapshot WHERE snapshot_date_key=(SELECT max(snapshot_date_key) FROM dw.fact_inventory_snapshot)",
 "Stockout rate % (all time)": "SELECT round(100.0*sum(stockout_flag)/sum(active_sku_flag),2) FROM dw.fact_inventory_snapshot",
 "Stockout rate % (2025)": "SELECT round(100.0*sum(stockout_flag)/sum(active_sku_flag),2) FROM dw.fact_inventory_snapshot i JOIN dw.dim_date d ON d.date_key=i.snapshot_date_key WHERE d.year_num=2025",
 "Supplier on-time % (all time)": "SELECT round(100.0*avg(on_time_flag),2) FROM dw.fact_supplier_deliveries",
 "Avg supplier lead time (days)": "SELECT round(avg(actual_lead_days),2) FROM dw.fact_supplier_deliveries",
 "Supplier defect rate %": "SELECT round(100.0*sum(qty_rejected)/sum(qty_received),3) FROM dw.fact_supplier_deliveries",
 "Supplier spend (PO lines)": "SELECT round(sum(ordered_amount),2) FROM dw.fact_purchases",
 "Availability %": "SELECT round(100.0*sum(operating_minutes)/sum(planned_minutes),2) FROM dw.fact_production",
 "Performance %": "SELECT round(100.0*sum(total_units)/sum(ideal_units),2) FROM dw.fact_production",
 "Quality %": "SELECT round(100.0*sum(good_units)/sum(total_units),2) FROM dw.fact_production",
 "OEE %": "SELECT round(100.0*sum(operating_minutes)/sum(planned_minutes)*sum(total_units)/sum(ideal_units)*sum(good_units)/sum(total_units),2) FROM dw.fact_production",
 "Defect rate %": "SELECT round(100.0*sum(defect_units)/sum(total_units),3) FROM dw.fact_production",
 "Downtime hours (events)": "SELECT round(sum(duration_hours),1) FROM dw.fact_downtime",
 "Material shortage hours": "SELECT round(sum(material_shortage_minutes)/60.0,1) FROM dw.fact_production",
 "Shipments": "SELECT count(*) FROM dw.fact_shipments",
 "On-time delivery %": "SELECT round(100.0*sum(on_time_flag)/count(on_time_flag),2) FROM dw.fact_shipments",
 "Avg delivery time (order to delivery, days)": "SELECT round(avg(order_to_delivery_days),2) FROM dw.fact_shipments",
 "Shipping cost": "SELECT round(sum(shipping_cost),2) FROM dw.fact_shipments",
}

# (label, query A, query B): the two must agree
IDENTITIES = [
 ("Revenue: fact_orders = fact_order_items", "SELECT round(sum(recognized_revenue),2) FROM dw.fact_orders", "SELECT round(sum(recognized_revenue),2) FROM dw.fact_order_items"),
 ("Gross profit: fact_orders = fact_order_items", "SELECT round(sum(recognized_gross_profit),2) FROM dw.fact_orders", "SELECT round(sum(recognized_gross_profit),2) FROM dw.fact_order_items"),
 ("Revenue: monthly query Q01 total = fact total", "SELECT round(sum(r),2) FROM (SELECT sum(f.recognized_revenue) r FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key=f.order_date_key GROUP BY d.month_year_sort) x", "SELECT round(sum(recognized_revenue),2) FROM dw.fact_orders"),
 ("OEE: A x P x Q of sums vs alternative definition good/capacity (tolerance 0.5 pt)", "SELECT round(sum(operating_minutes)::numeric/sum(planned_minutes)*sum(total_units)/sum(ideal_units)*sum(good_units)/sum(total_units),4) FROM dw.fact_production",
   "SELECT round(sum(good_units)/sum(capacity_units),4) FROM dw.fact_production", 0.005),
 ("Production: good + defective = total", "SELECT sum(good_units)+sum(defect_units) FROM dw.fact_production", "SELECT sum(total_units) FROM dw.fact_production"),
 ("Material consumption value = units made x BOM x cost", "SELECT round(sum(consumption_value),0) FROM dw.fact_material_consumption", "SELECT round(sum(p.total_units*b.qty_per_unit*m.standard_cost),0) FROM dw.fact_production p JOIN dw.bridge_product_material b USING (product_key) JOIN dw.dim_material m USING (material_key) WHERE p.total_units>0"),
 ("Supplier deliveries accepted + rejected = received", "SELECT sum(qty_accepted)+sum(qty_rejected) FROM dw.fact_supplier_deliveries", "SELECT sum(qty_received) FROM dw.fact_supplier_deliveries"),
 ("Inventory: last-snapshot value, fact vs product-level view", "SELECT round(sum(inventory_value),0) FROM dw.fact_inventory_snapshot WHERE snapshot_date_key=(SELECT max(snapshot_date_key) FROM dw.fact_inventory_snapshot)", "SELECT round(sum(inventory_value),0) FROM analytics.v_demand_supply_product"),
 ("Customers: dim lifetime orders = fact non-cancelled orders", "SELECT sum(lifetime_orders) FROM dw.dim_customer", "SELECT count(*) FROM dw.fact_orders f JOIN dw.dim_order_status s USING (order_status_key) WHERE s.order_status<>'Cancelled'"),
 ("Shipments = shipped orders", "SELECT count(*) FROM dw.fact_shipments", "SELECT count(*) FROM dw.fact_orders f JOIN dw.dim_order_status s USING (order_status_key) WHERE s.is_revenue_recognized"),
]


def main():
    conn = connect()
    cur = conn.cursor()
    lines = ["# KPI Reference Values", "",
             "Generated by `scripts/kpi_reference.py` straight from PostgreSQL (seed 42, scale 1.0). **Your Power BI cards must show the same numbers** when no slicers are applied.", "",
             "| KPI | Reference value |", "|---|---|"]
    for k, q in REF.items():
        cur.execute(q)
        v = cur.fetchone()[0]
        lines.append(f"| {k} | {float(v):,.2f} |" if v is not None else f"| {k} | n/a |")
    lines += ["", "## Internal consistency checks (each KPI computed two independent ways)", "", "| Check | Path A | Path B | Result |", "|---|---|---|---|"]
    bad = 0
    for ident in IDENTITIES:
        label, qa, qb = ident[:3]
        tol_abs = ident[3] if len(ident) > 3 else 0.01
        cur.execute(qa); a = cur.fetchone()[0]
        cur.execute(qb); b = cur.fetchone()[0]
        ok = abs(float(a) - float(b)) <= max(tol_abs, 0.0001 * abs(float(b)))
        bad += 0 if ok else 1
        lines.append(f"| {label} | {float(a):,.4f} | {float(b):,.4f} | {'PASS' if ok else '**FAIL**'} |")
    open(os.path.join(ROOT, "docs", "kpi_reference_values.md"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines[-len(IDENTITIES) - 1:]))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()

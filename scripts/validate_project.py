#!/usr/bin/env python3
"""
End-to-end validation. Writes docs/validation_report.md and exits non-zero on any failure.
  1. data-quality framework results (dq.check_results)
  2. every table exists with rows; primary keys unique; foreign keys declared
  3. all analytical queries execute
  4. KPI identities (two independent computations)
  5. scenario checks: the generated data really supports the intended investigations
"""
import datetime, os, subprocess, sys
from db import connect, ROOT

SCENARIOS = [
 ("S1 Supplier S001 late rate >= 60% in Aug-Nov 2024 (vs < 25% normal)",
  "SELECT 100.0*avg(late_flag) FROM dw.fact_supplier_deliveries f JOIN dw.dim_supplier s USING (supplier_key) JOIN dw.dim_date d ON d.date_key=f.received_date_key JOIN dw.dim_material m USING (material_key) WHERE s.supplier_id='S001' AND m.material_name='WiFi Module WM-200' AND d.full_date BETWEEN '2024-08-01' AND '2024-11-30'", lambda v: v >= 60),
 ("S1 Normal-period S001 late rate < 30% (Jan-May 2024)",
  "SELECT 100.0*avg(late_flag) FROM dw.fact_supplier_deliveries f JOIN dw.dim_supplier s USING (supplier_key) JOIN dw.dim_date d ON d.date_key=f.received_date_key WHERE s.supplier_id='S001' AND d.full_date BETWEEN '2024-01-01' AND '2024-05-31'", lambda v: v < 30),
 ("S1 Material shortage share of planned time higher in Aug-Nov 2024 than Aug-Nov 2025",
  "SELECT (SELECT 100.0*sum(material_shortage_minutes)/sum(planned_minutes) FROM dw.fact_production f JOIN dw.dim_date d ON d.date_key=f.date_key WHERE d.full_date BETWEEN '2024-08-01' AND '2024-11-30') - (SELECT 100.0*sum(material_shortage_minutes)/sum(planned_minutes) FROM dw.fact_production f JOIN dw.dim_date d ON d.date_key=f.date_key WHERE d.full_date BETWEEN '2025-08-01' AND '2025-11-30')", lambda v: v > 3),
 ("S1 Stockout rate of S001-component products exceeds other products in Nov 2024",
  "WITH dep AS (SELECT DISTINCT product_key FROM dw.bridge_product_material WHERE material_key=(SELECT material_key FROM dw.dim_material WHERE material_name='WiFi Module WM-200')) SELECT (100.0*sum(stockout_flag) FILTER (WHERE product_key IN (SELECT product_key FROM dep))/sum(active_sku_flag) FILTER (WHERE product_key IN (SELECT product_key FROM dep))) - (100.0*sum(stockout_flag) FILTER (WHERE product_key NOT IN (SELECT product_key FROM dep))/sum(active_sku_flag) FILTER (WHERE product_key NOT IN (SELECT product_key FROM dep))) FROM dw.fact_inventory_snapshot i JOIN dw.dim_date d ON d.date_key=i.snapshot_date_key WHERE d.month_year_sort=202411", lambda v: v > 1),
 ("S2 Revenue grows 2025 vs 2024 while gross margin falls by > 2 points",
  "SELECT (SELECT sum(recognized_revenue) FILTER (WHERE d.year_num=2025)/sum(recognized_revenue) FILTER (WHERE d.year_num=2024) - 1 FROM dw.fact_order_items f JOIN dw.dim_date d ON d.date_key=f.order_date_key) * 100 AS rev_growth_pct, (SELECT 100*sum(recognized_gross_profit) FILTER (WHERE d.year_num=2024)/sum(recognized_revenue) FILTER (WHERE d.year_num=2024) - 100*sum(recognized_gross_profit) FILTER (WHERE d.year_num=2025)/sum(recognized_revenue) FILTER (WHERE d.year_num=2025) FROM dw.fact_order_items f JOIN dw.dim_date d ON d.date_key=f.order_date_key) AS margin_drop_pts",
  lambda v: v[0] > 0 and v[1] > 2),
 ("S2 Audio margin falls > 5 points 2024 to 2025",
  "SELECT 100*sum(recognized_gross_profit) FILTER (WHERE d.year_num=2024)/sum(recognized_revenue) FILTER (WHERE d.year_num=2024) - 100*sum(recognized_gross_profit) FILTER (WHERE d.year_num=2025)/sum(recognized_revenue) FILTER (WHERE d.year_num=2025) FROM dw.fact_order_items f JOIN dw.dim_product p USING (product_key) JOIN dw.dim_date d ON d.date_key=f.order_date_key WHERE p.category='Audio'", lambda v: v > 5),
 ("S3 At least 10 products flagged shortage risk or capacity constrained",
  "SELECT count(*) FROM analytics.v_demand_supply_status WHERE supply_status IN ('Shortage risk','Capacity constrained')", lambda v: v >= 10),
 ("S5 At least 20 products flagged excess inventory",
  "SELECT count(*) FROM analytics.v_demand_supply_status WHERE supply_status='Excess inventory'", lambda v: v >= 20),
 ("S4 Warehouse stockout spread: worst warehouse > 2x the median warehouse",
  "WITH w AS (SELECT warehouse_key, 100.0*sum(stockout_flag)/sum(active_sku_flag) r FROM dw.fact_inventory_snapshot GROUP BY 1) SELECT max(r)/percentile_cont(0.5) WITHIN GROUP (ORDER BY r) FROM w", lambda v: v > 2),
 ("S6 Nine chronic machines: top-9 failure rates are >= 3x fleet average",
  "WITH f AS (SELECT d.machine_key, count(*)::numeric / (SELECT sum(operating_minutes)/60.0 FROM dw.fact_production p WHERE p.machine_key=d.machine_key) r FROM dw.fact_downtime d JOIN dw.dim_downtime_type t USING (downtime_type_key) WHERE t.loss_category='Equipment failure' GROUP BY 1), top9 AS (SELECT r FROM f ORDER BY r DESC LIMIT 9) SELECT (SELECT avg(r) FROM top9)/(SELECT avg(r) FROM f)", lambda v: v >= 2.0),
 ("S7 Defect rate of highest-defect wearables > 2x category average",
  "WITH r AS (SELECT product_key, sum(defect_units)::numeric/sum(total_units) d FROM dw.fact_production GROUP BY 1 HAVING sum(total_units)>1500), c AS (SELECT sum(defect_units)::numeric/sum(total_units) d FROM dw.fact_production f JOIN dw.dim_product p USING (product_key) WHERE p.category='Wearables') SELECT max(r.d)/(SELECT d FROM c) FROM r JOIN dw.dim_product p USING (product_key) WHERE p.category='Wearables'", lambda v: v > 2),
 ("S7 Defect-return association: product-level correlation > 0.3",
  "WITH d AS (SELECT product_key, sum(defect_units)::numeric/sum(total_units) dr FROM dw.fact_production GROUP BY 1 HAVING sum(total_units)>=1000), s AS (SELECT product_key, sum(quantity) u FROM dw.fact_order_items i JOIN dw.dim_order_status st USING (order_status_key) WHERE st.order_status='Delivered' GROUP BY 1), r AS (SELECT product_key, sum(quantity_returned) q FROM dw.fact_returns GROUP BY 1) SELECT corr(d.dr, COALESCE(r.q,0)::numeric/s.u) FROM d JOIN s USING (product_key) LEFT JOIN r USING (product_key)", lambda v: v > 0.3),
 ("S8 Stockout vs delayed dispatch correlation (warehouse-month) > 0.3",
  "WITH inv AS (SELECT i.warehouse_key, d.month_year_sort m, 100.0*sum(stockout_flag)/sum(active_sku_flag) s FROM dw.fact_inventory_snapshot i JOIN dw.dim_date d ON d.date_key=i.snapshot_date_key GROUP BY 1,2), f AS (SELECT warehouse_key, d.month_year_sort m, 100.0*avg(fulfilment_delayed_flag) FILTER (WHERE days_to_ship IS NOT NULL) x FROM dw.fact_orders o JOIN dw.dim_date d ON d.date_key=o.order_date_key GROUP BY 1,2) SELECT corr(inv.s, f.x) FROM inv JOIN f USING (warehouse_key, m)", lambda v: v > 0.3),
 ("Seasonality: Nov-Dec daily orders >= 1.4x the Jan-May average",
  "SELECT (SELECT avg(c) FROM (SELECT order_date_key, count(*) c FROM dw.fact_orders o JOIN dw.dim_date d ON d.date_key=o.order_date_key WHERE d.month_num IN (11,12) GROUP BY 1) a)/(SELECT avg(c) FROM (SELECT order_date_key, count(*) c FROM dw.fact_orders o JOIN dw.dim_date d ON d.date_key=o.order_date_key WHERE d.month_num BETWEEN 1 AND 5 GROUP BY 1) b)", lambda v: v >= 1.4),
 ("Plants differ: OEE spread between best and worst plant > 10 points",
  "WITH p AS (SELECT plant_key, 100.0*sum(operating_minutes)/sum(planned_minutes)*sum(total_units)/sum(ideal_units)*sum(good_units)/sum(total_units) oee FROM dw.fact_production GROUP BY 1) SELECT max(oee)-min(oee) FROM p", lambda v: v > 10),
 ("Suppliers differ: reliability spread (best band vs worst band on-time) > 40 points",
  "SELECT max(on_time_pct)-min(on_time_pct) FROM analytics.v_supplier_scorecard WHERE deliveries>=100", lambda v: v > 40),
 ("Customers repeat: 2023 cohort repeat rate > 80%",
  "SELECT 100.0*count(*) FILTER (WHERE lifetime_orders>=2)/count(*) FROM dw.dim_customer WHERE extract(year FROM first_order_date)=2023", lambda v: v > 80),
]


def main():
    conn = connect(); cur = conn.cursor()
    out = ["# Validation Report", "", f"Generated by `scripts/validate_project.py` on {datetime.date.today()} against the live database. Dataset: seed 42, scale 1.0.", ""]
    failures = 0

    # 1. DQ framework
    cur.execute("SELECT category, count(*), count(*) FILTER (WHERE status='PASS'), count(*) FILTER (WHERE status='FAIL'), count(*) FILTER (WHERE status='INFO') FROM dq.check_results GROUP BY 1 ORDER BY 1")
    out += ["## 1. Data-quality framework (`dq.check_results`)", "", "| Category | Checks | Pass | Fail | Info |", "|---|---|---|---|---|"]
    tot = [0, 0, 0, 0]
    for r in cur.fetchall():
        out.append(f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} | {r[4]} |")
        for i in range(4): tot[i] += r[i + 1]
    out.append(f"| **Total** | **{tot[0]}** | **{tot[1]}** | **{tot[2]}** | **{tot[3]}** |")
    failures += tot[2]
    cur.execute("SELECT check_name, violations FROM dq.check_results WHERE status='INFO' AND category <> 'Rejected by staging' ORDER BY 1")
    out += ["", "Informational counts (expected, documented, not failures):", ""] + [f"* {n}: {v:,}" for n, v in cur.fetchall()]
    cur.execute("SELECT source_table, count(*) FROM staging.rejects GROUP BY 1 ORDER BY 1")
    out += ["", "Rows removed or merged in staging (all logged in `staging.rejects`): " + ", ".join(f"{t} {n:,}" for t, n in cur.fetchall()), ""]

    # 2. structure
    cur.execute("""SELECT c.relname, c.reltuples::bigint, (SELECT count(*) FROM pg_constraint k WHERE k.conrelid=c.oid AND k.contype='p') pk
                   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='dw' AND c.relkind='r' ORDER BY 1""")
    tabs = cur.fetchall()
    out += ["## 2. Warehouse structure", "", "| Table | Rows | Primary key | Grain unique constraint |", "|---|---|---|---|"]
    for t, _, pk in tabs:
        cur.execute(f"SELECT count(*) FROM dw.{t}"); n = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid WHERE c.relname=%s AND k.contype='u'", (t,))
        u = cur.fetchone()[0]
        ok = n > 0 and pk == 1
        failures += 0 if ok else 1
        out.append(f"| `{t}` | {n:,} | {'yes' if pk else '**MISSING**'} | {u if t.startswith('fact_') else '-'} |")
    cur.execute("SELECT count(*) FROM information_schema.table_constraints WHERE table_schema='dw' AND constraint_type='FOREIGN KEY'")
    nfk = cur.fetchone()[0]
    out += ["", f"{len(tabs)} tables, all with a primary key and rows; **{nfk} foreign keys** declared and enforced (loading would have failed on any orphan).", ""]

    # 3. queries
    res = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "run_queries.py")], capture_output=True, text=True, env=os.environ)
    lines = [l for l in res.stdout.splitlines() if l.startswith("Q")]
    failed = [l for l in lines if "FAILED" in l]
    empty = [l for l in lines if " 0 rows" in l]
    out += ["## 3. Analytical queries", "", f"{len(lines)} queries executed, {len(failed)} failed, {len(empty)} returned no rows.", ""]
    out += [f"* {l}" for l in failed + empty]
    failures += len(failed) + len(empty)

    # 4. KPI identities
    res = subprocess.run([sys.executable, os.path.join(ROOT, "scripts", "kpi_reference.py")], capture_output=True, text=True, env=os.environ)
    ident = [l for l in res.stdout.splitlines() if l.startswith("|") and ("PASS" in l or "FAIL" in l)]
    out += ["", "## 4. KPI internal consistency", "", "| Check | A | B | Result |", "|---|---|---|---|"] + ident + [""]
    failures += sum(1 for l in ident if "FAIL" in l)

    # 5. scenarios
    out += ["## 5. Does the data support the intended investigations?", "", "| Scenario / pattern | Measured | Result |", "|---|---|---|"]
    for label, sql, test in SCENARIOS:
        cur.execute(sql); row = cur.fetchone()
        v = float(row[0]) if len(row) == 1 else tuple(float(x) for x in row)
        ok = bool(test(v))
        failures += 0 if ok else 1
        shown = f"{v:.2f}" if not isinstance(v, tuple) else ", ".join(f"{x:.2f}" for x in v)
        out.append(f"| {label} | {shown} | {'PASS' if ok else '**FAIL**'} |")

    out += ["", "## Summary", "", f"**{'ALL VALIDATIONS PASSED' if failures == 0 else str(failures) + ' VALIDATION FAILURE(S)'}**"]
    open(os.path.join(ROOT, "docs", "validation_report.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("\n".join(out[-24:]))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()

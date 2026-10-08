#!/usr/bin/env python3
"""
One-command pipeline: setup -> raw tables -> load CSVs -> staging -> dimensions -> facts -> quality -> indexes -> analytics views.

    python scripts/run_pipeline.py              # run everything (data must exist in data/raw)
    python scripts/run_pipeline.py --generate   # generate data first (use --scale 0.1 for a fast demo)
    python scripts/run_pipeline.py --from staging
"""
import argparse, subprocess, sys, os, time
from db import connect, run_folder, ROOT

STEPS = ["setup", "raw", "load", "staging", "dimensions", "facts", "quality", "indexes", "analytics"]
FOLDER = {"setup": "01_setup", "raw": "02_raw", "staging": "03_staging", "dimensions": "04_dimensions",
          "facts": "05_facts", "quality": "06_quality", "indexes": "07_indexes"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--generate", action="store_true", help="run the data generator first")
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--from", dest="start", choices=STEPS, default="setup")
    a = ap.parse_args()
    t0 = time.time()
    if a.generate:
        print("== generate data")
        subprocess.check_call([sys.executable, os.path.join(ROOT, "scripts", "generate_data.py"), "--scale", str(a.scale), "--seed", str(a.seed)])
    conn = connect()
    for step in STEPS[STEPS.index(a.start):]:
        print(f"== {step}", flush=True)
        if step == "load":
            subprocess.check_call([sys.executable, os.path.join(ROOT, "scripts", "load_data.py")])
        elif step == "analytics":
            # analytics folder: only the views file is executed here; query files are for reading/running ad hoc
            from db import run_sql_file
            run_sql_file(conn, os.path.join(ROOT, "sql", "08_analytics", "00_views.sql"))
        else:
            run_folder(conn, FOLDER[step])
    cur = conn.cursor()
    cur.execute("SELECT count(*) FILTER (WHERE status='PASS'), count(*) FILTER (WHERE status='FAIL' AND severity='ERROR'), count(*) FILTER (WHERE status='FAIL' AND severity='WARN'), count(*) FILTER (WHERE status='INFO') FROM dq.check_results")
    p, e, w, i = cur.fetchone()
    print(f"\nData-quality: {p} passed, {e} ERRORS, {w} warnings, {i} informational")
    print(f"Pipeline finished in {time.time() - t0:.0f}s")
    if e:
        cur.execute("SELECT check_name, violations FROM dq.check_results WHERE status='FAIL' AND severity='ERROR'")
        for r in cur.fetchall(): print("  FAILED:", r)
        sys.exit(1)


if __name__ == "__main__":
    main()

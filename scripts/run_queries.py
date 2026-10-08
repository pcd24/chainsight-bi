#!/usr/bin/env python3
"""Execute every analytical query in sql/08_analytics/*.sql (except 00_views) and report rows + time.
Usage: python scripts/run_queries.py [--show Q05]  -> prints the result of one query."""
import argparse, glob, os, re, time
from db import connect, ROOT


def split_queries(path):
    text = open(path, encoding="utf-8").read()
    parts = re.split(r"(?m)^-- (Q\d+) ", text)
    for i in range(1, len(parts), 2):
        yield parts[i], parts[i + 1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--show", help="query id to print, e.g. Q05")
    ap.add_argument("--limit", type=int, default=30)
    a = ap.parse_args()
    conn = connect()
    cur = conn.cursor()
    ok = bad = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "sql", "08_analytics", "0[1-9]_*.sql"))):
        for qid, body in split_queries(path):
            title = body.split("\n", 1)[0].strip()
            sql = body.split("\n", 1)[1]
            if a.show and a.show != qid:
                continue
            t0 = time.time()
            try:
                cur.execute(sql)
                rows = cur.fetchall()
                cols = [c[0] for c in cur.description]
                if a.show:
                    print(f"{qid} {title}\n" + " | ".join(cols))
                    for r in rows[:a.limit]:
                        print(" | ".join(str(x) for x in r))
                else:
                    print(f"{qid:<4} {len(rows):>4} rows {time.time() - t0:5.1f}s  {title[:70]}")
                ok += 1
            except Exception as e:
                conn.rollback()
                print(f"{qid:<4} FAILED: {str(e).splitlines()[0]}")
                bad += 1
    if not a.show:
        print(f"\n{ok} queries ran, {bad} failed")


if __name__ == "__main__":
    main()

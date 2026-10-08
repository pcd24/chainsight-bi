#!/usr/bin/env python3
"""Load every CSV in data/raw into the matching raw.<table> using COPY (fast, all TEXT)."""
import csv, glob, os, time
from db import connect, ROOT


def main():
    conn = connect()
    cur = conn.cursor()
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "raw", "*.csv"))):
        table = os.path.basename(path)[:-4]
        cols = next(csv.reader(open(path, encoding="utf-8")))
        t0 = time.time()
        cur.execute(f"TRUNCATE raw.{table}")
        with open(path, encoding="utf-8") as f:
            cur.copy_expert(f"COPY raw.{table} ({', '.join(cols)}) FROM STDIN WITH (FORMAT csv, HEADER true)", f)
        cur.execute(f"SELECT count(*) FROM raw.{table}")
        print(f"  raw.{table:<32} {cur.fetchone()[0]:>10,} rows ({time.time() - t0:.1f}s)", flush=True)
    conn.commit()
    conn.close()


if __name__ == "__main__":
    main()

"""Shared helpers: connection settings from .env / environment, and a SQL file runner."""
import os, time, glob
import psycopg2

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def load_env():
    path = os.path.join(ROOT, ".env")
    if os.path.exists(path):
        for line in open(path):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def connect():
    load_env()
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "localhost"), port=os.getenv("POSTGRES_PORT", "5432"),
        user=os.getenv("POSTGRES_USER", "chainsight"), password=os.environ["POSTGRES_PASSWORD"],
        dbname=os.getenv("POSTGRES_DB", "chainsight"))


def run_sql_file(conn, path):
    t0 = time.time()
    with conn.cursor() as cur:
        cur.execute(open(path, encoding="utf-8").read())
    conn.commit()
    print(f"  ran {os.path.relpath(path, ROOT)} ({time.time() - t0:.1f}s)", flush=True)


def run_folder(conn, folder):
    for f in sorted(glob.glob(os.path.join(ROOT, "sql", folder, "*.sql"))):
        run_sql_file(conn, f)

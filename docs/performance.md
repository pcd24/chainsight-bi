# Performance and Index Strategy

The warehouse is **read-heavy and bulk-loaded**, so: load first, index after, and index only where a real query pattern needs it. Primary keys, `UNIQUE` grain constraints and the `ux_dim_*` business-key indexes already exist; `sql/07_indexes/01_indexes.sql` adds the rest.

| Index | Table | Why it exists |
|---|---|---|
| `ix_fo_order_date (order_date_key) INCLUDE (customer_key, recognized_revenue)` | fact_orders | Monthly/yearly revenue trends read it without touching the table (index-only scan) |
| `ix_foi_order_date (order_date_key, product_key)` | fact_order_items | Revenue by product over time |
| `ix_foi_product (product_key, warehouse_key)` | fact_order_items | Demand lookups per product and warehouse (inventory, demand-vs-supply) |
| `ix_fo_customer (customer_key, order_date_key)` | fact_orders | Customer history, repeat purchase, cohorts |
| `ix_fs_ship_date`, `ix_fr_product` | shipments, returns | Carrier trends, return rate by product |
| `ix_fis_prod_wh (product_key, warehouse_key, snapshot_date_key)` | fact_inventory_snapshot | History of one product in one warehouse (the grain index starts with the date, so it cannot serve this) |
| `ix_fis_stockout ... WHERE stockout_flag = 1` | fact_inventory_snapshot | **Partial index**: stockout analysis touches about 8% of the 1.2M rows, so the index is small |
| `ix_fp_*`, `ix_fd_*`, `ix_fdef_prod`, `ix_fmc_material` | manufacturing facts | Plant/machine/product time series and the join from downtime to its production run |
| `ix_fpu_*`, `ix_fsd_*` | purchases, deliveries | Supplier and material analysis |

We deliberately did **not** index every foreign key column: unused indexes slow the load and waste space. Foreign key constraints (`02_foreign_keys.sql`) are declared after the load as proof of integrity.

## EXPLAIN ANALYZE examples (PostgreSQL 16, 1 CPU, no parallelism)

**1. Revenue by month for 2025 (index-only scan, no table access)**

```sql
SELECT d.month_year_sort, sum(f.recognized_revenue)
FROM dw.fact_orders f JOIN dw.dim_date d ON d.date_key = f.order_date_key
WHERE d.year_num = 2025 GROUP BY 1;
```
```
Index Only Scan using ix_fo_order_date on fact_orders f (actual rows=272 loops=365)
  Heap Fetches: 0
Execution Time: 23.8 ms
```
The `INCLUDE (customer_key, recognized_revenue)` columns mean PostgreSQL never visits the heap (`Heap Fetches: 0`).

**2. Stockouts in 2025 by warehouse (partial index)**

```
Index Only Scan using ix_fis_stockout on fact_inventory_snapshot (actual rows=38740)
Execution Time: 4.3 ms
```

**3. History of one product in one warehouse**

| | Plan | Time |
|---|---|---|
| With `ix_fis_prod_wh` | Bitmap Index Scan, 157 heap blocks | **0.9 ms** |
| Index scans disabled (what happens without it) | Seq Scan over 1.2M rows | **90 ms** |

That is a 100x difference for one of the most common drill-downs, from one 3-column index.

## Power BI performance notes

* Import mode with integer surrogate keys compresses very well; avoid high-cardinality text columns on fact tables.
* Disable Auto date/time; one marked Date table.
* All numbers come from measures over a star schema with single-direction relationships (no bidirectional filters).
* Inventory (1.2M rows) is the heaviest table; if memory is tight, filter the Power Query load to the last 12 months or use the monthly last-snapshot only.

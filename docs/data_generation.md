# Synthetic Data Generation

`scripts/generate_data.py` runs a **day-by-day simulation** of NovaTech (1 Jan 2023 - 31 Dec 2025) with a fixed random seed (default 42). It is a simulation rather than a table of random numbers, so upstream events really change downstream outcomes.

```
each day:
  1  warehouse transfers and raw-material deliveries arrive
  2  customers order (demand = popularity x category season x promotion x weekday x growth)
  3  order lines are filled from warehouse stock; the rest become backorders that wait for stock
  4  Mon/Thu: warehouses request replenishment from plants
  5  machines run shifts: failures, changeovers, material availability -> output -> defects
  6  purchasing: reorder raw materials; suppliers deliver on time or late, with rejects
  7  Sunday: snapshot all stock
afterwards:  orders get cancelled when they wait too long, ship, are delivered (carrier, region, season delays), and are sometimes returned
```

Run `python scripts/generate_data.py --scale 0.1 --seed 7` for a smaller or different dataset. Output is 24 CSVs in `data/raw` and `data/processed/generation_manifest.json`.

## Volumes (scale 1.0, seed 42)

| Entity | Rows |
|---|---|
| Customers (incl. 400 duplicate records) | 20,400 |
| Products / materials / suppliers | 500 / 68 / 110 |
| Warehouses / plants / machines | 15 / 5 / 110 |
| Orders / order lines | about 250,000 / 600,000 |
| Shipments | about 231,800 |
| Returns | about 39,000 |
| Inventory snapshots (weekly) | about 1.18M |
| Production runs / downtime events / defects | about 121,000 / 140,000 / 18,300 |
| Material consumption (derived) | about 561,000 |
| Purchase-order lines / receipts | about 57,000 / 56,200 |
| Maintenance work orders | about 10,900 |

## Realistic behaviour that is built in

| Requirement | How |
|---|---|
| Seasonality, weekends | Monthly factor per category (peaks in Nov-Dec), weekday factor |
| Promotions | 23 promotions; discount lifts demand, and cuts margin |
| Product popularity | Log-normal popularity: a few best sellers, a long tail |
| Geography | Region demand shares; warehouses serve their region |
| Repeat customers and churn | Per-customer purchase rate; 45% of customers churn after a random lifetime |
| Returns | Category base rate x product defect rate x customer return propensity x late delivery |
| Cancellations | Higher the longer an order waits for stock |
| Supplier differences | Each supplier has its own lead time, lateness probability, delay size, reject rate and price level |
| Machine differences | Speed, failure probability, severity; 9 chronic-downtime machines |
| Plant differences | Plant speed factor, defect factor, failure factor |
| Warehouse differences | 2 lean warehouses (stockouts), 2 heavy warehouses (excess) |

## Deliberate cross-domain scenarios

| # | Scenario | Mechanism |
|---|---|---|
| 1 | **Supplier A (S001, Apex Components) disruption, Jul-Nov 2024** | S001's late probability rises to 75% and delays to about 14 days; it supplies 70% of component WiFi Module WM-200, used by Smart Cameras and other products. Raw-material cover falls, machines wait for material, output drops, warehouses run out |
| 2 | **Audio revenue up, margin down (2025)** | 30% "Audio Mega Clearance" promotion plus a 7% unit-cost rise on Audio and Gaming while list prices stay flat |
| 3 | **Promotion supply pressure** | One earbuds product gets 3.5x demand during Black Friday 2024 and Summer Sale 2025 and has little spare capacity |
| 4 | **Capacity-constrained products** | About 11 products have capacity equal to average demand; demand grows 20% a year, so they fall short in peaks |
| 5 | **Excess inventory** | 24 low-demand products (mousepads, phone cases) are produced to a long cover target |
| 6 | **Machine downtime** | 9 machines fail about 4.5x as often; their runs lose output |
| 7 | **Defects and returns** | 12 wearables made in Shenzhen have 6-9% defect rates; the return probability rises with the product defect rate |
| 8 | **Fulfilment and delivery** | Stockouts create backorders, which delay dispatch, which raises cancellations and late deliveries |
| 9 | **Chennai plant capacity** | Chennai has the fewest machines for the products assigned to it, so it runs near its limit |

## Dirty data injected into RAW

A few percent of rows in each table are damaged. The exact counts of every injected problem are in `data/processed/generation_manifest.json` (key `injected_issues`), for example: 400 duplicate customer records, 6,249 order-status spelling variants plus 249 invalid statuses, 999 orders with dd/mm/yyyy dates and 74 with no date, 299 negative order quantities, 239 invalid product ids, 117 inventory rows with negative stock, 114 impossible delivery dates (e.g. 30 February). The staging layer must account for every one of them.

## Known simulation limits (be ready to say these in an interview)

* **Start-up effect**: raw-material stock starts at a rough guess, so January 2023 shows an unusually high material-shortage loss. Treat Jan 2023 as warm-up when reading trends.
* **Material shortage is the largest downtime cause** (63% of downtime hours). It is concentrated in Q4 peaks and the 2024 supplier disruption. In a real plant this share would be lower; here it is a consequence of the simulated reorder policy and is useful because it exposes the supplier-to-production link.
* **Right-censoring**: customers acquired in 2025 have had less time to repeat-purchase, so their repeat rate is mechanically lower than older cohorts.
* Dispatch delays (more than 2 days) are common because multi-line orders wait for their slowest item.

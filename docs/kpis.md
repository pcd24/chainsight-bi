# KPI Definitions

Single source of truth for every KPI. SQL and DAX use the same definitions; `docs/kpi_reference_values.md` lists the expected values.

## E-commerce

| KPI | Definition | DAX measure | SQL |
|---|---|---|---|
| Total Revenue | Net revenue (after discount) of **shipped** orders (Delivered, In Transit) | `[Total Revenue]` | Q01 |
| Gross Profit | Revenue minus cost of goods sold, shipped orders | `[Gross Profit]` | Q01 |
| Gross Margin % | Gross profit / revenue | `[Gross Margin %]` | Q06 |
| Total Orders | Orders placed, any status | `[Total Orders]` | Q01 |
| Shipped Orders | Orders with revenue recognised | `[Shipped Orders]` | Q01 |
| AOV | Revenue / shipped orders | `[AOV]` | Q04 |
| Units Sold | Units on shipped orders | `[Units Sold]` | Q01 |
| Average Selling Price | Revenue / units sold | `[Average Selling Price]` | Q16 |
| Discount Rate % | Discount amount / gross sales (before discount) | `[Discount Rate %]` | Q08 |
| Return Rate | Units returned / units delivered (by order date of the returned item) | `[Return Rate]` | Q09 |
| Cancellation Rate | Cancelled orders / orders placed | `[Cancellation Rate]` | Q10 |
| Backorder Rate | Backordered orders / orders placed | `[Backorder Rate]` | Q10 |
| Unfulfilled Order Value | Net value of cancelled + backordered orders (revenue at risk or lost) | `[Unfulfilled Order Value]` | Q10, Q81 |
| Fulfilment Rate | Units shipped / units ordered | `[Fulfilment Rate]` | Q35 |

## Customers

| KPI | Definition | DAX |
|---|---|---|
| Customers | Distinct buyers with a non-cancelled order in the period | `[Customers]` |
| New Customers | Customers whose first non-cancelled order is in the period | `[New Customers]` |
| Returning Customers | Customers minus new customers | `[Returning Customers]` |
| Repeat Customers | Customers with 2+ non-cancelled orders in the period | `[Repeat Customers]` |
| Repeat Purchase Rate | Repeat customers / customers | `[Repeat Purchase Rate]` |
| Customer Lifetime Value (historical) | Gross profit per customer over all history; **not a forecast** | `[Customer Lifetime Value (Historical)]` |
| Cohort Retention % | Customers from a first-order month who order again N months later / cohort size | `[Cohort Retention %]` |
| Segments | Champion (5+ orders, active 90 days), Loyal (3+), Repeat (2), New (1 order in last 90 days), One-time, At Risk (181-365 days inactive), Lost (>365 days) as of 2025-12-31 | `Customer[customer_segment]` |

## Inventory and supply

| KPI | Definition | DAX |
|---|---|---|
| Inventory Quantity / Value | Last weekly snapshot in the selected period (never summed across dates) | `[Inventory Quantity]`, `[Inventory Value]` |
| Average Inventory | Average of weekly total inventory value in the period | `[Average Inventory]` |
| Inventory Turnover | (COGS / average inventory value) x (365 / days in period) | `[Inventory Turnover]` |
| Days of Inventory | 365 / turnover | `[Days of Inventory]` |
| Stockout Rate | Active product-warehouse-weeks with zero stock / all active product-warehouse-weeks. "Active" = launched 30+ days ago | `[Stockout Rate]` |
| Low Stock | Stock covers less than 7 days of trailing 4-week demand | `[Low Stock Products]` |
| Excess Inventory | Value of stock above 90 days of demand (10+ units on hand, or no demand) | `[Excess Inventory]` |
| Days of Cover | On hand / average daily demand of the last 4 weeks | `[Average Days of Cover]` |
| Supplier On-Time % | Deliveries received on or before the promised date / deliveries received | `[Supplier On-Time %]` |
| Average Supplier Lead Time | Mean days from PO date to receipt | `[Average Supplier Lead Time]` |
| Supplier Defect Rate | Units rejected at inspection / units received | `[Supplier Defect Rate]` |
| OTIF % | On time **and** in full | `[OTIF %]` |
| Supplier Performance Band | A: 90%+ on time, B: 80-90%, C: 65-80%, D: below 65% (neutral labels, not a ranking) | `[Supplier Performance Band]` |

## Manufacturing

| KPI | Definition | DAX |
|---|---|---|
| Availability | Operating minutes / planned minutes | `[Availability]` |
| Performance | Units produced / (rated units per minute x operating minutes) | `[Performance]` |
| Quality | Good units / units produced | `[Quality]` |
| **OEE** | Availability x Performance x Quality, from **aggregated sums** | `[OEE]` |
| Capacity Utilization | Machine-shifts scheduled / machine-shifts available (2 per machine per day) | `[Capacity Utilization]` |
| Output vs Rated Capacity | Units produced / (rated speed x all planned minutes) = Availability x Performance | `[Output vs Rated Capacity]` |
| Defect Rate | Defective units / units produced | `[Defect Rate]` |
| Downtime Hours | Sum of downtime event hours | `[Downtime Hours]` |
| Production Loss | Downtime minutes x rated speed (estimate of units not made) | `[Production Loss (Units)]` |
| Failures per 1,000 operating hours | Equipment-failure events / operating hours x 1000 | `[Failures per 1,000 Operating Hours]` |
| Corrective Maintenance % | Corrective work orders / all work orders | `[Corrective Maintenance %]` |

## Logistics

| KPI | Definition | DAX |
|---|---|---|
| On-Time Delivery % | Delivered on or before the promised date / delivered shipments with a known date | `[On-Time Delivery %]` |
| Average Delivery Time | Days from order date to delivery date | `[Average Delivery Time (Days)]` |
| Average Days to Ship | Days from order date to ship date (warehouse speed) | `[Average Days to Ship]` |
| Shipping Cost per kg | Shipping cost / shipment weight | `[Shipping Cost per kg]` |

## Control tower thresholds (RAG)

| Stage | KPI | Green | Amber | Red |
|---|---|---|---|---|
| Suppliers | On-time % | >= 85% | 75-85% | < 75% |
| Materials | Days of supply | >= 14 | 7-14 | < 7 |
| Manufacturing | OEE | >= 70% | 60-70% | < 60% |
| Inventory | Stockout rate | <= 8% | 8-12% | > 12% |
| Warehouse | Days to dispatch | <= 3 | 3-5 | > 5 |
| Orders | Cancelled + backordered % | <= 6% | 6-10% | > 10% |
| Shipments | On-time delivery % | >= 85% | 75-85% | < 75% |
| Customers | Return rate | <= 6% | 6-8% | > 8% |

Thresholds are assumptions for a consumer-electronics business and live in `powerbi/dax/09_control_tower.dax`; change them in one place. With 2025 data the tiles show: Suppliers green (87%), Materials green (17 days), Manufacturing green (71.6%), Inventory amber (9.9%), Warehouse red (5.9 days), Orders red (10.9%), Shipments amber (81%), Customers amber (6.5% all-time return rate).

# Management Report: NovaTech Manufacturing & Commerce, 2023-2025

*Prepared from the ChainSight warehouse (synthetic dataset, seed 42). All figures come from the queries and KPI reference listed in `docs/kpi_reference_values.md` and `sql/08_analytics`. Observations point to areas to investigate; they do not prove causes.*

## 1. Summary

NovaTech grew revenue 9.2% in 2025 to $20.9M, but gross profit was flat at $7.0M because margin fell 3.1 points to 33.6%. At the same time the value of orders cancelled or left backordered tripled to $3.6M. The chain shows stress in four places: Audio discounting, two stockout-prone warehouses (Chicago and Mumbai), material shortages that waste more than 60% of lost machine time, and a plant (Chennai) running close to capacity while others have idle shifts.

## 2. What happened, where, why (association), impact, what to investigate

| # | What happened | Where | Why (evidence, not proof) | Business impact | Investigate |
|---|---|---|---|---|---|
| 1 | Margin fell 3.1 points while revenue grew | Audio (-10.1 pts), Gaming (-3.1) | Audio discount rate 4.0% to 12.4%; 30% clearance promotion; higher Audio unit cost | Gross profit flat despite +$1.7M revenue | Audio promotions and cost [Q12, Q16] |
| 2 | Cancelled + backordered order value tripled ($1.17M to $3.59M) | All categories; worst for Chennai-made products (22.6% unfulfilled lines) | Stockouts rose; Chennai at 82% shift use | About 15% of 2025 order value (cancelled/backordered $3.59M vs $20.87M recognised) did not convert to revenue | Product-level supply gaps [Q37, Q81] |
| 3 | Stockouts concentrated | Chicago 29.4%, Mumbai 20.2% | Stockouts correlate 0.88 with slow dispatch | Late and lost orders in two regions | Replenishment targets; rebalancing |
| 4 | Machines idle waiting for material | All plants, peaking Nov-Dec and in the 2024 supplier disruption | Material shortage = 63% of downtime hours; Supplier S001 late rate 36% to 90% (Jul to Sep 2024) | Output lost | Reorder policy; second sources |
| 5 | Plant efficiency gap of 18 OEE points | Monterrey 55.7% vs Shenzhen 74.0% | Availability and speed, not quality | Under-used capacity | Monterrey changeovers and failures |
| 6 | Returns cost $4.3M in refunds | Wearables 10.7%, Audio 8.3% | Higher defect-rate products are returned more (correlation 0.64) | 6.5% of delivered units come back | Shenzhen wearables quality |

## 3. Business performance

| | 2023 | 2024 | 2025 |
|---|---|---|---|
| Orders placed | 69,721 | 80,988 | 99,127 |
| Revenue (recognised) | $16.65M | $19.12M | $20.87M |
| Gross profit | $6.18M | $7.02M | $7.01M |
| Gross margin | 37.1% | 36.7% | 33.6% |
| Average order value | $250.5 | $248.6 | $236.3 |
| Cancelled orders | 4.6% | 5.0% | 7.8% |
| Backordered orders | 0.0% | 0.0% | 3.1% |
| Order value cancelled/backordered | $0.92M | $1.17M | $3.59M |

Total 2023-2025: revenue $56.6M, gross profit $20.2M (35.7% margin), 249,836 orders, 231,695 shipped. Revenue by region: North America 33.9%, Europe 28.3%, Asia Pacific 24.0%, Latin America 8.0%, Middle East & Africa 5.8%. Audio (25.9% of revenue, 28.6% margin) and Wearables (25.2% of revenue, 35.0% margin) are the two largest categories. Audio is the largest category but has the lowest margin; Mobile Accessories has the highest (47.0%).

## 4. Revenue and profitability

* Seasonality: Nov and Dec daily orders are about 70% above the rest of the year.
* Discount depth: margin is 38.5% at full price and 10.1% at 21%+ discount (Q08).
* Average order value fell 5.7% from 2023 to 2025 ($250.5 to $236.3), consistent with more discounting.

## 5. Customers

* 14,654 customers placed a non-cancelled order; 6,327 are "Champions" and generate 78.7% of revenue; the top 10% of customers produce 45.6%.
* About 4,800 customers are At Risk or Lost (14.2% of historic revenue) and form a win-back pool.
* Repeat rate is 94% for the 2023 cohort and 68% for the 2025 cohort; the lower figure partly reflects less time to reorder.

## 6. Inventory health

* Finished-goods inventory at the last snapshot is $1.14M; the company stockout rate rose from 7.5% (2023) to 9.9% (2025).
* 15 products are at shortage risk (4,818 backordered units); 46 carry excess stock ($106k).
* Chicago and Mumbai are the problem warehouses; Munich holds the largest excess (gaming and mobile accessories).

## 7. Supplier performance

* Spend $22.4M across 110 suppliers; on-time delivery 87.2%; average lead time 14.9 days; rejection rate 1.44%.
* 8 suppliers are below 65% on time and account for $2.1M of spend. Supplier S001 had a severe disruption from Aug to Nov 2024.
* Some widely used materials rely on a single supplier for 70-89% of spend.

## 8. Manufacturing performance

* OEE 68.4% overall (66.6% in 2023, 66.5% in 2024, 71.6% in 2025): availability 85.4%, performance 81.8%, quality 97.8%.
* Plants range from 55.7% (Monterrey) to 74.0% (Shenzhen). Defect rate 2.17%; scrap cost $0.93M.
* Nine machines have abnormal failure rates; maintenance is 83-89% reactive.

## 9. Logistics performance

* 231,695 shipments; 81.7% delivered on or before the promised date; average 9.3 days from order to delivery; shipping cost $1.97M.
* Europe 89.0% on time, other regions 77-81%. Carrier on-time ranges from 85.8% (SwiftShip Express) to 73.0% (GlobeLine Freight).

## 10. Operational risks

1. Peak-season (Nov-Dec) overload across suppliers, plants and warehouses at the same time.
2. Supplier concentration on high-use materials (packaging, IC chips, microphone capsules).
3. Chennai capacity: its products are under-served.
4. Stockout-prone warehouses and the associated dispatch delays.
5. Reactive maintenance on a few high-failure machines.
6. Margin dilution from deep discounts.

## 11. Areas requiring investigation (prioritised)

1. Audio pricing, promotion and cost (largest margin effect).
2. Replenishment targets for Chicago and Mumbai.
3. Material reorder policy and second sources for the top single-supplier materials.
4. Moving volume from Chennai to plants with idle shifts.
5. Shenzhen wearables with defect rates 2-4x normal.
6. Preventive maintenance on the nine high-failure machines.
7. Carrier mix for promise-date-sensitive orders.

## 12. Limits of this report

The dataset is synthetic. Associations (e.g. defects and returns, supplier delays and shortages) are shown to illustrate analysis; a real project would test causes with further data (root-cause records, controlled comparisons). January 2023 is distorted by the simulation start-up and customers acquired in 2025 have had less time to repeat-purchase.

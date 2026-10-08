# Evidence-Based Insights

Every number below was produced by a query in `sql/08_analytics` (query id in brackets) on the generated dataset (seed 42, scale 1.0). The data is **synthetic**, so these insights demonstrate the analysis method; they are not facts about a real company. Where the data only shows association, the insight says so and names what to investigate instead of claiming a cause.

## Revenue, margin and discounts

### 1. Revenue grew in 2025 but gross profit did not
* **Observation:** 2025 revenue rose while gross profit stayed flat; margin fell.
* **Evidence:** Revenue $19.12M (2024) to $20.87M (2025), +9.2%. Gross profit $7.02M to $7.01M. Gross margin 36.7% to 33.6% (-3.1 points). [Q01, Q03, Q15]
* **Implication:** Growth is not translating into profit; extra volume was bought with discounts and/or higher costs.
* **Investigate:** Category and promotion mix (insight 2), unit-cost trend by category (Q16).

### 2. Audio explains most of the margin decline
* **Observation:** Audio's margin dropped about 10 points while the other categories moved 0 to -3 points.
* **Evidence:** Audio margin 31.8% to 21.7% (-10.1 pts); revenue +4.8%; discount rate on Audio 4.0% to 12.4%. Gaming Accessories -3.1 pts; all others between -1.3 and +0.1. [Q15]
* **Implication:** One category is diluting company margin. The timing coincides with a deep Audio clearance promotion (30% off, Feb-Apr 2025) and higher Audio unit costs, but the data shows association with these, not a measured split between them.
* **Investigate:** Audio promotions [Q12] and Audio unit cost versus selling price [Q16]; separate price/discount effect from cost effect.

### 3. Deep discounts destroy margin
* **Observation:** Margin falls steeply with discount depth.
* **Evidence:** Full price 38.5%; 1-10% off 32.4%; 11-20% off 23.6%; 21%+ off 10.1%. Profit per unit $28.76 at full price vs $6.66 at 21%+. [Q08]
* **Implication:** Discounts above 20% leave very little profit per unit; they need a volume or inventory-clearing justification.
* **Investigate:** Whether the 21%+ promotions (Black Friday, clearance) lifted volume enough to compensate [Q12].

## Fulfilment, inventory and demand

### 4. Revenue not fulfilled tripled in 2025
* **Observation:** More orders were cancelled or left backordered in 2025.
* **Evidence:** Order value cancelled or backordered $1.17M (2024) to $3.59M (2025). Cancellation rate 5.0% to 7.8%; backorder rate 0.0% to 3.1%. [Q10, Q13]
* **Implication:** Demand that the company could have served was lost or delayed; demand grew about 22% in orders while supply did not keep pace in some places.
* **Investigate:** Which products and warehouses carry the loss [Q81, Q35].

### 5. Two warehouses carry most of the stockout problem
* **Observation:** Stockout rates are very uneven.
* **Evidence:** Chicago 29.4% and Mumbai 20.2% of active product-weeks at zero stock, versus 7.7-8.0% in Amsterdam, Dallas and Santiago. Company stockout rate rose 7.5% (2023) to 9.9% (2025). [Q30]
* **Implication:** Customers served by these two warehouses see far more unavailable items.
* **Investigate:** Stock targets and replenishment frequency for these two warehouses; whether stock should be rebalanced from over-stocked sites (Munich and others, Q33).

### 6. Stockouts move together with slow dispatch
* **Observation:** Months with more stockouts in a warehouse are months with more late dispatches.
* **Evidence:** Correlation 0.88 between warehouse-month stockout rate and share of orders dispatched more than 2 days after ordering (540 warehouse-months). [Q72]
* **Implication:** Dispatch delay is mostly a stock-availability problem, not a picking-speed problem. This is an association; it does not rule out other causes.
* **Investigate:** Dispatch time for orders where every line was in stock versus orders with a backordered line.

### 7. 15 products are at shortage risk; 46 carry excess
* **Observation:** The demand-versus-supply view separates products into balanced, shortage, constrained and excess.
* **Evidence:** 438 balanced, 46 excess-inventory ($106k), 15 shortage-risk (4,818 backordered units), 1 capacity-constrained. [Q37]
* **Implication:** Attention is needed on a short list of products rather than the whole catalogue.
* **Investigate:** The 15 shortage products' production schedule and material cover [Q79]; the excess list for promotion or reduced production.

## Customers

### 8. A small group of customers produces most of the revenue
* **Observation:** Revenue is highly concentrated.
* **Evidence:** Top 10% of customers = 45.6% of revenue; top 30% = 78.0%. "Champion" customers (5+ orders, active in the last 90 days) are 6,327 customers and 78.7% of revenue. [Q25, Q21]
* **Implication:** Losing a small number of Champions would hurt more than losing many one-time buyers.
* **Investigate:** Service levels and stock availability for the products Champions buy.

### 9. Repeat purchasing is strong, with a caveat about newer customers
* **Observation:** Repeat rate falls for newer cohorts.
* **Evidence:** Share of buyers with 2+ orders: 94.0% (first order in 2023), 87.0% (2024), 68.4% (2025). [Q18]
* **Implication:** Part of the fall is mechanical (2025 customers have had less time to reorder). It should not be read as a retention collapse without a like-for-like cohort comparison.
* **Investigate:** Retention at the same age (month 3, month 6) across cohorts [Q22].

### 10. About 4,800 customers are at risk or lost
* **Observation:** A visible group has gone quiet.
* **Evidence:** 1,647 "At Risk" (no order for 181-365 days) and 3,166 "Lost" (over 365 days) customers, together 14.2% of revenue. [Q21, Q23]
* **Implication:** There is a win-back pool with historic value.
* **Investigate:** Whether these customers were hit by stockouts or late deliveries before leaving.

## Returns and quality

### 11. Wearables and Audio are returned most
* **Observation:** Return rates differ widely by category.
* **Evidence:** Wearables 10.7%, Audio 8.3%, versus Computer Accessories 4.6% (returned/delivered units). Refunds total $4.32M (company return rate 6.5%). [Q09]
* **Implication:** Returns are a major hidden cost, concentrated in two categories.
* **Investigate:** Return reasons by category (Q09 detail, `dim_return_reason`), and product defect rates (insight 12).

### 12. Products with higher manufacturing defect rates are returned more often
* **Observation:** Defect rate and return rate rise together across products.
* **Evidence:** Lowest-defect quintile: 0.84% defects, 4.5% returns. Highest quintile: 4.46% defects, 9.3% returns. Product-level correlation 0.64. [Q74]
* **Implication:** Quality at the plant is linked to cost after the sale. This is an association across products; other product traits (category) also differ between quintiles.
* **Investigate:** Return reasons for high-defect products ("Defective / Not Working" share).

### 13. A group of Shenzhen wearables has defect rates 2-4 times the category norm
* **Observation:** A handful of products stand out.
* **Evidence:** Nova Vertex Smart Watch Lite 100 (P0384): 17.5% defect rate vs 4.6% category average (3.8x); Nova Prime Smart Ring Max 400 (P0393): 11.1% (2.4x). [Q57]
* **Implication:** Scrap cost ($0.93M in total across all products) and returns concentrate in a few products.
* **Investigate:** Shenzhen lines, machines and defect types for these products [Q56].

## Suppliers and materials

### 14. Material shortage is the largest single cause of lost machine time
* **Observation:** Waiting for material outweighs equipment failure.
* **Evidence:** 88,894 of 141,205 downtime hours (63.0%) were material shortage; changeover 17.1%; mechanical and electrical failure 16.0% combined. [Q53]
* **Implication:** Fixing material supply would recover more capacity than fixing machines. Material loss peaks in Nov-Dec each year, and January 2023 is inflated by the simulation start-up.
* **Investigate:** Reorder points and safety stock for the materials most often short; seasonal pre-buying.

### 15. A major supplier's delays coincide with a production and stock squeeze
* **Observation:** Supplier S001 (Apex Components) slipped badly in 2024 and the chain downstream tightened.
* **Evidence:** S001 late deliveries rose from 36% (Jul 2024) to 78% (Aug) and 90% (Sep); average days late reached 21 in Sep. For products using its WiFi Module WM-200, material-shortage time was 59.8% of planned production time in Nov 2024 vs 15.8% for other products; stockout rate 13.1% vs 10.6%. [Q69, Q70]
* **Implication:** One supplier problem can cascade to production and shelves. The monthly pattern is not perfectly consistent (e.g. July 2024 shows no shortage), so this is an association to investigate, not proof of cause.
* **Investigate:** WM-200 purchase orders and receipts for Aug-Nov 2024, the plants' days of supply for that material, and the alternative sources (they supplied only 30% of the material).

### 16. Supplier reliability is split into clear bands
* **Observation:** Most suppliers are reliable; a small group is not.
* **Evidence:** 52 of 82 suppliers (with 100+ deliveries) deliver 90%+ on time; 8 suppliers are below 65% on time and account for $2.1M of spend. Overall on-time 87.2%, average lead time 14.9 days, rejection rate 1.44%. [Q41, KPI reference]
* **Implication:** A targeted review of 8 suppliers addresses most delivery risk.
* **Investigate:** Whether low-reliability suppliers are also single sources for any material [Q45].

### 17. Several materials depend heavily on one supplier
* **Observation:** Single-supplier exposure exists on widely used materials.
* **Evidence:** Packaging Box PKG-200: 86% of spend with one supplier, used by 87 products. IC Chip ICX-400: 89% with one supplier, used by 54 products. Microphone Capsule supply is the most concentrated family (HHI 3,167). [Q45, Q46]
* **Implication:** A disruption at those suppliers would affect many products at once.
* **Investigate:** Qualification of second sources.

## Manufacturing

### 18. Plant efficiency differs by almost 20 OEE points
* **Observation:** OEE ranges from 55.7% to 74.0%.
* **Evidence:** Shenzhen 74.0%, Chennai 69.2%, Austin 66.6%, Wroclaw 66.2%, Monterrey 55.7%. Monterrey's weak spots are availability (78.2%) and performance (72.7%); quality is near 98% everywhere. [Q50]
* **Implication:** The improvement opportunity is in availability and speed, not in quality. Part of the availability loss is material shortage (insight 14), not the plant's own doing.
* **Investigate:** Monterrey changeover and failure hours [Q53, Q58].

### 19. A few machines fail far more than the fleet average
* **Observation:** Failure frequency is extremely uneven.
* **Evidence:** MC-PL4-24 (Shenzhen packaging line) 106 failures per 1,000 operating hours (7.1x the fleet average); MC-PL5-02 (Monterrey) 97 (6.5x); MC-PL1-14 (Austin) 71 (4.8x). [Q54]
* **Implication:** A very small number of machines drive a disproportionate share of lost output.
* **Investigate:** Maintenance history and spare-part strategy for these machines [Q58, `fact_maintenance`].

### 20. Maintenance is mostly reactive
* **Observation:** Corrective work dominates.
* **Evidence:** Corrective maintenance is 83.5% to 89.2% of work orders in every plant. Machines in the lowest preventive-maintenance quartile averaged 127 failures; the highest quartile 81; correlation -0.15. [Q55, Q60]
* **Implication:** More preventive maintenance is associated with fewer failures, but the relationship is weak, so it is not a guaranteed lever.
* **Investigate:** Preventive-maintenance compliance by machine.

### 21. Chennai is nearly out of capacity
* **Observation:** One plant runs close to its limit while others have room.
* **Evidence:** Shift utilisation in 2025: Chennai 82.2%, Shenzhen 65.8%, Austin 49.6%, Wroclaw 42.1%, Monterrey 39.4%. Order lines for Chennai-made products were 22.6% unfulfilled in 2025 vs 10.3-10.8% for the other plants. [Q49, Q80]
* **Implication:** Chennai's products are being short-served while other plants have idle shifts. Association, not proof; other product-level factors also differ.
* **Investigate:** Moving some Chennai products to plants with spare shifts.

## Logistics

### 22. Delivery reliability differs by carrier and region
* **Observation:** On-time delivery varies by about 13 points between carriers.
* **Evidence:** SwiftShip Express 85.8%, AeroParcel 85.2%, MetroPost 82.1%, TransContinental 76.9%, GlobeLine (Economy) 73.0%. By destination, Europe 89.0% vs 77-81% elsewhere; average order-to-delivery 7.0 days in Europe vs 12.5 days in Middle East & Africa. [Q63, Q64]
* **Implication:** Cheaper carriers are slower and less reliable (cost per kg $2.21 for GlobeLine vs $2.79 for SwiftShip).
* **Investigate:** Whether to route high-value or promised-date orders to higher-reliability carriers.

### 23. Seasonality drives a 70% peak in orders
* **Observation:** November and December volumes are far above the rest of the year.
* **Evidence:** Average daily orders in 2024: about 170-190 in Jan-May; 329 in Nov and 324 in Dec (+70%). Stockouts and material shortage hours also peak in Nov-Dec. [Q01, Q31, Q53]
* **Implication:** Peak season stresses every stage of the chain at once.
* **Investigate:** Pre-season stock build and material pre-buying.

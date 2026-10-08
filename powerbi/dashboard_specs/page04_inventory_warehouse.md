# Page 4 - Inventory & Warehouse

**Page purpose.** Show where finished-goods stock is too low, too high or ageing, and how warehouses compare.

**Business question.** Which warehouses and products have stockout or excess problems, and how fast does stock turn?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Date[year_num]` | Tile slicer | x 12 y 60 w 200 h 34 |
| `Date[month_year]` | Dropdown | x 224 y 60 w 140 h 34 |
| `Warehouse[region]` | Dropdown | x 376 y 60 w 160 h 34 |
| `Product[category]` | Dropdown | x 548 y 60 w 160 h 34 |

## Page-level filters

* Date[is_actuals] = TRUE

## Visuals

### 4.1  Inventory Value

* **Type:** Card (new card visual)
* **Position / size:** x 12, y 108, w 150, h 76
* **Fields:** [Inventory Value]
* **Formatting / conditional formatting / notes:** Last snapshot in selection

### 4.2  Inventory Turnover

* **Type:** Card (new card visual)
* **Position / size:** x 172, y 108, w 150, h 76
* **Fields:** [Inventory Turnover]

### 4.3  Days of Inventory

* **Type:** Card (new card visual)
* **Position / size:** x 332, y 108, w 150, h 76
* **Fields:** [Days of Inventory]

### 4.4  Stockout Rate

* **Type:** Card (new card visual)
* **Position / size:** x 492, y 108, w 150, h 76
* **Fields:** [Stockout Rate]
* **Formatting / conditional formatting / notes:** Rules: <= 8% green, 8-12% amber, > 12% red

### 4.5  Excess Inventory

* **Type:** Card (new card visual)
* **Position / size:** x 652, y 108, w 150, h 76
* **Fields:** [Excess Inventory]
* **Formatting / conditional formatting / notes:** Above 90 days of demand

### 4.6  Fulfilment Rate

* **Type:** Card (new card visual)
* **Position / size:** x 812, y 108, w 150, h 76
* **Fields:** [Fulfilment Rate]

### 4.7  Backordered Units

* **Type:** Card (new card visual)
* **Position / size:** x 972, y 108, w 150, h 76
* **Fields:** [Backordered Units]

### 4.8  Low Stock Products

* **Type:** Card (new card visual)
* **Position / size:** x 1132, y 108, w 150, h 76
* **Fields:** [Low Stock Products]
* **Formatting / conditional formatting / notes:** < 7 days of cover

### 4.9  Inventory value and stockout rate over time

* **Type:** Line chart
* **Position / size:** x 12, y 196, w 420, h 230
* **X-axis:** Date[month_year]
* **Y-axis:** [Inventory Value]
* **Secondary y-axis:** [Stockout Rate]
* **Formatting / conditional formatting / notes:** Because stock is a snapshot, each month shows its last weekly snapshot.

### 4.10  Warehouse comparison: stockout rate

* **Type:** Clustered bar chart
* **Position / size:** x 444, y 196, w 400, h 230
* **Y-axis:** Warehouse[warehouse_name]
* **X-axis:** [Stockout Rate]
* **Tooltip:** [Low Stock Rate], [Excess Rate], [Avg Days to Dispatch], [Days of Inventory]
* **Formatting / conditional formatting / notes:** Conditional bar colour: <= 8% #27AE60, 8-12% #F39C12, > 12% #C0392B. Sort descending.

### 4.11  Inventory ageing (days since last sale)

* **Type:** Clustered column chart
* **Position / size:** x 856, y 196, w 412, h 230
* **X-axis:** Inventory[days_since_last_sale] grouped: 0-30, 31-60, 61-90, 91-180, 180+, no sale
* **Y-axis:** [Inventory Value]
* **Formatting / conditional formatting / notes:** Create the group on Inventory[days_since_last_sale] (Data groups > Bin / List). Ageing proxy - see data dictionary.

### 4.12  Low-stock products (action list)

* **Type:** Table
* **Position / size:** x 12, y 438, w 410, h 270
* **Columns:** Product[product_name], Product[category], [Inventory Quantity], [Backordered Units], [Average Days of Cover]
* **Filter:** [Low Stock Products] >= 1 (visual filter on measure) and Top N 20 by [Backordered Units]
* **Formatting / conditional formatting / notes:** Data bars on backordered units; red font if cover < 3.

### 4.13  Excess-stock products

* **Type:** Table
* **Position / size:** x 434, y 438, w 410, h 270
* **Columns:** Product[product_name], Product[category], [Excess Units], [Excess Inventory], [Stock Not Sold 90d+ Value]
* **Filter:** Top N 20 by [Excess Inventory]
* **Formatting / conditional formatting / notes:** Blue data bars.

### 4.14  Inventory risk matrix: category x warehouse

* **Type:** Matrix (inventory risk matrix)
* **Position / size:** x 856, y 438, w 412, h 270
* **Rows:** Product[category]
* **Columns:** Warehouse[warehouse_name]
* **Values:** [Stockout Rate]
* **Formatting / conditional formatting / notes:** Conditional formatting: Background colour gradient white -> #C0392B; add second matrix copy with [Excess Rate] in blue via bookmark 'Excess view'.

## Interactions (Format > Edit interactions)

Selecting a warehouse in 4.10 filters 4.9, 4.11, 4.12, 4.13. Matrix 4.14 cross-highlights only the tables.

## Drill-through

Right-click product in 4.12 or 4.13 > Drill through > 'Investigate Product'.

## Bookmarks and buttons

'Stockout view' / 'Excess view' (swaps matrix 4.14 measure).

## Tooltips

4.10 uses a report-page tooltip with [Low Stock Rate], [Excess Rate], [Days of Inventory] (built-in tooltip fields are enough).

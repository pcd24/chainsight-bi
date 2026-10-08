# Page 9 - Demand & Supply Planning

**Page purpose.** For every product, compare expected demand with on-hand stock, incoming supply and proven production capacity to flag shortages, excess and capacity limits. This page is an 'as-of last snapshot' view and ignores the date slicer on purpose.

**Business question.** Which products will run short, which have excess, and where is demand above proven capacity?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Product[category]` | Dropdown | x 12 y 60 w 180 h 34 |
| `'Product Supply Position'[supply_status]` | Tile slicer (4 values) | x 204 y 60 w 520 h 34 |
| `Product[primary_plant]` | Dropdown | x 736 y 60 w 200 h 34 |

## Page-level filters

* None (as-of view). Edit interactions: Date slicers are not on this page.

## Visuals

### 9.1  Expected Demand (30d)

* **Type:** Card (new card visual)
* **Position / size:** x 12, y 108, w 150, h 76
* **Fields:** [Expected Demand 30d]

### 9.2  On Hand + In Transit

* **Type:** Card (new card visual)
* **Position / size:** x 172, y 108, w 150, h 76
* **Fields:** [Current On-Hand (As Of)] + [Incoming Inventory (In Transit)]

### 9.3  Demonstrated Capacity (30d)

* **Type:** Card (new card visual)
* **Position / size:** x 332, y 108, w 150, h 76
* **Fields:** [Production Capacity 30d]

### 9.4  Net Supply Gap

* **Type:** Card (new card visual)
* **Position / size:** x 492, y 108, w 150, h 76
* **Fields:** [Supply Gap]
* **Formatting / conditional formatting / notes:** Red if < 0

### 9.5  Shortage-Risk Products

* **Type:** Card (new card visual)
* **Position / size:** x 652, y 108, w 150, h 76
* **Fields:** [Products Shortage Risk]

### 9.6  Capacity-Constrained

* **Type:** Card (new card visual)
* **Position / size:** x 812, y 108, w 150, h 76
* **Fields:** [Products Capacity Constrained]

### 9.7  Excess-Stock Products

* **Type:** Card (new card visual)
* **Position / size:** x 972, y 108, w 150, h 76
* **Fields:** [Products Excess]

### 9.8  Capacity Coverage

* **Type:** Card (new card visual)
* **Position / size:** x 1132, y 108, w 150, h 76
* **Fields:** [Capacity Coverage Ratio]
* **Formatting / conditional formatting / notes:** Red if < 1.0

### 9.9  Product supply position

* **Type:** Table (product supply position)
* **Position / size:** x 12, y 196, w 760, h 512
* **Columns:** 'Product Supply Position'[product_name], 'Product Supply Position'[category], [Avg Daily Demand 90d], [Expected Demand 30d], [Current On-Hand (As Of)], [Incoming Inventory (In Transit)], [Backordered (As Of)], [Production Capacity 30d], [Supply Gap], 'Product Supply Position'[supply_status]
* **Default sort:** [Supply Gap] ascending
* **Formatting / conditional formatting / notes:** Background colour on supply_status via [Supply Status Colour] (Format by > Field value). Data bars on [Supply Gap] (negative red, positive blue).

### 9.10  Products by supply status

* **Type:** Clustered column chart
* **Position / size:** x 784, y 196, w 484, h 250
* **X-axis:** 'Product Supply Position'[supply_status]
* **Y-axis:** [Products (Supply Position)]
* **Data labels:** On
* **Formatting / conditional formatting / notes:** Column colour = Format by Field value > [Supply Status Colour] (Shortage risk #C0392B, Capacity constrained #E67E22, Excess inventory #2980B9, Balanced #27AE60).

### 9.11  Demand vs proven capacity

* **Type:** Scatter chart
* **Position / size:** x 784, y 458, w 484, h 250
* **X-axis:** [Expected Demand 30d]
* **Y-axis:** [Production Capacity 30d]
* **Details:** 'Product Supply Position'[product_name]
* **Legend:** 'Product Supply Position'[supply_status]
* **Formatting / conditional formatting / notes:** Add y = x constant line: products below it have demand above proven capacity.

## Interactions (Format > Edit interactions)

Status slicer filters table and charts. Selecting a bar in 9.10 filters 9.9 and 9.11.

## Drill-through

Right-click product in 9.9 > Drill through > 'Investigate Product'.

## Bookmarks and buttons

'Shortages only' (supply_status = Shortage risk + Capacity constrained), 'Excess only', 'All'.

## Tooltips

9.11: product, on hand, backordered.

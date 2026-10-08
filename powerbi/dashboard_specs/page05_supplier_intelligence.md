# Page 5 - Supplier Intelligence

**Page purpose.** Compare supplier delivery reliability, lead time, quality and cost with neutral, defined bands (not best/worst labels).

**Business question.** Which suppliers show delivery or quality risk, and where are we dependent on one supplier?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Date[year_num]` | Tile slicer (received date) | x 12 y 60 w 200 h 34 |
| `Supplier[country]` | Dropdown | x 224 y 60 w 160 h 34 |
| `Supplier[supplier_tier]` | Dropdown | x 396 y 60 w 140 h 34 |
| `Material[material_family]` | Dropdown | x 548 y 60 w 180 h 34 |
| `Plant[plant_name]` | Dropdown | x 740 y 60 w 180 h 34 |

## Page-level filters

* Date[is_actuals] = TRUE

## Visuals

### 5.1  Supplier Spend

* **Type:** Card (new card visual)
* **Position / size:** x 12, y 108, w 150, h 76
* **Fields:** [Supplier Spend]

### 5.2  Active Suppliers

* **Type:** Card (new card visual)
* **Position / size:** x 172, y 108, w 150, h 76
* **Fields:** [Active Suppliers]

### 5.3  Avg Lead Time (days)

* **Type:** Card (new card visual)
* **Position / size:** x 332, y 108, w 150, h 76
* **Fields:** [Average Supplier Lead Time]

### 5.4  On-Time %

* **Type:** Card (new card visual)
* **Position / size:** x 492, y 108, w 150, h 76
* **Fields:** [Supplier On-Time %]
* **Formatting / conditional formatting / notes:** Rules: >= 85% green, 75-85% amber, < 75% red

### 5.5  Defect Rate

* **Type:** Card (new card visual)
* **Position / size:** x 652, y 108, w 150, h 76
* **Fields:** [Supplier Defect Rate]
* **Formatting / conditional formatting / notes:** Red if > 2%

### 5.6  Late Deliveries

* **Type:** Card (new card visual)
* **Position / size:** x 812, y 108, w 150, h 76
* **Fields:** [Late Deliveries]

### 5.7  Price vs Standard

* **Type:** Card (new card visual)
* **Position / size:** x 972, y 108, w 150, h 76
* **Fields:** [Price Variance vs Standard %]

### 5.8  Top Supplier Share

* **Type:** Card (new card visual)
* **Position / size:** x 1132, y 108, w 150, h 76
* **Fields:** [Top Supplier Spend Share %]

### 5.9  Supplier performance matrix

* **Type:** Scatter chart (supplier performance matrix)
* **Position / size:** x 12, y 196, w 420, h 270
* **X-axis:** [Supplier On-Time %]
* **Y-axis:** [Supplier Defect Rate]
* **Size:** [Supplier Spend]
* **Details:** Supplier[supplier_name]
* **Legend:** [Supplier Performance Band]
* **Formatting / conditional formatting / notes:** Add constant lines: x = 80% on-time, y = 2% defect to create four quadrants. Quadrant labels (text boxes): top-left 'Delivery and quality risk', top-right 'Quality risk', bottom-left 'Delivery risk', bottom-right 'Reliable delivery / low rejects'. Neutral palette, no 'best/worst' wording.

### 5.10  Supplier table

* **Type:** Table (supplier ranking)
* **Position / size:** x 444, y 196, w 420, h 270
* **Columns:** Supplier[supplier_name], [Supplier Spend], [Supplier On-Time %], [Average Supplier Lead Time], [Lead Time Gap (Days)], [Supplier Defect Rate], [Supplier Performance Band]
* **Default sort:** [Supplier Spend] descending (a neutral sort; users may re-sort)
* **Formatting / conditional formatting / notes:** Data bars on spend; icon set or background on [Supplier On-Time %] using the rules above. Minimum 100 deliveries: visual filter [Deliveries Received] >= 100.

### 5.11  Lead-time distribution

* **Type:** Column chart
* **Position / size:** x 876, y 196, w 392, h 270
* **X-axis:** 'Supplier Deliveries'[actual_lead_days] grouped: <=7, 8-14, 15-21, 22-30, 31+ days
* **Y-axis:** [Deliveries Received]
* **Formatting / conditional formatting / notes:** Group on actual_lead_days.

### 5.12  Late-delivery trend

* **Type:** Line chart
* **Position / size:** x 12, y 478, w 420, h 230
* **X-axis:** Date[month_year]
* **Y-axis:** [Late Delivery %]
* **Secondary:** [Average Days Late (when late)]
* **Formatting / conditional formatting / notes:** Highlights the Jul-Nov 2024 spike.

### 5.13  Spend by material family / dependency

* **Type:** Bar chart
* **Position / size:** x 444, y 478, w 420, h 230
* **Y-axis:** Material[material_family]
* **X-axis:** [Supplier Spend]
* **Tooltip:** [Top Supplier Spend Share %], [Products Using Material]
* **Formatting / conditional formatting / notes:** Tooltip shows how dependent the family is on its largest supplier.

### 5.14  Supplier quality: rejected share by supplier tier

* **Type:** Clustered column chart
* **Position / size:** x 876, y 478, w 392, h 230
* **X-axis:** Supplier[supplier_tier]
* **Y-axis:** [Supplier Defect Rate]
* **Tooltip:** [Deliveries Received], [OTIF %]

## Interactions (Format > Edit interactions)

Clicking a point in 5.9 filters tables and trend. Slicer 'Plant' filters deliveries by receiving plant.

## Drill-through

Supplier name drill-through is optional: create page 'Supplier Detail' with the same visuals filtered to one supplier. Not required for the 10 core pages.

## Bookmarks and buttons

'Reset filters'.

## Tooltips

5.9 tooltip: [Deliveries Received], [Average Days Late (when late)], [OTIF %].

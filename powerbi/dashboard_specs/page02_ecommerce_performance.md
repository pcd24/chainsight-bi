# Page 2 - E-Commerce Performance

**Page purpose.** Show what sells, where, at what margin, and what is returned or lost.

**Business question.** Which products, categories and regions drive revenue and profit, and where do discounts and returns hurt?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Date[year_num]` | Tile slicer, multi-select | x 12 y 60 w 220 h 34 |
| `Date[month_year]` | Dropdown | x 244 y 60 w 140 h 34 |
| `Product[category]` | Dropdown | x 396 y 60 w 160 h 34 |
| `Customer[region]` | Dropdown | x 568 y 60 w 160 h 34 |
| `Orders[channel]` | Dropdown | x 740 y 60 w 120 h 34 |
| `Promotion[promotion_name]` | Dropdown, search on | x 872 y 60 w 220 h 34 |

## Page-level filters

* Date[is_actuals] = TRUE

## Visuals

### 2.1  Revenue

* **Type:** Card (new card visual)
* **Position / size:** x 12, y 108, w 150, h 76
* **Fields:** [Total Revenue]

### 2.2  Orders (shipped)

* **Type:** Card (new card visual)
* **Position / size:** x 172, y 108, w 150, h 76
* **Fields:** [Shipped Orders]

### 2.3  AOV

* **Type:** Card (new card visual)
* **Position / size:** x 332, y 108, w 150, h 76
* **Fields:** [AOV]

### 2.4  Units Sold

* **Type:** Card (new card visual)
* **Position / size:** x 492, y 108, w 150, h 76
* **Fields:** [Units Sold]

### 2.5  Gross Margin %

* **Type:** Card (new card visual)
* **Position / size:** x 652, y 108, w 150, h 76
* **Fields:** [Gross Margin %]
* **Formatting / conditional formatting / notes:** Reference label: [Gross Margin Change (pts)]

### 2.6  Return Rate

* **Type:** Card (new card visual)
* **Position / size:** x 812, y 108, w 150, h 76
* **Fields:** [Return Rate]
* **Formatting / conditional formatting / notes:** Red font if > 8%

### 2.7  Cancellation Rate

* **Type:** Card (new card visual)
* **Position / size:** x 972, y 108, w 150, h 76
* **Fields:** [Cancellation Rate]
* **Formatting / conditional formatting / notes:** Red font if > 8%

### 2.8  Revenue Not Fulfilled

* **Type:** Card (new card visual)
* **Position / size:** x 1132, y 108, w 150, h 76
* **Fields:** [Unfulfilled Order Value]
* **Formatting / conditional formatting / notes:** Cancelled + backordered order value

### 2.9  Monthly revenue trend (with prior year)

* **Type:** Line chart
* **Position / size:** x 12, y 196, w 420, h 230
* **X-axis:** Date[month_year]
* **Y-axis:** [Total Revenue], [Revenue Previous Year]
* **Tooltip:** [Revenue YoY %], [Revenue MoM %]
* **Formatting / conditional formatting / notes:** Prior-year line dashed grey.

### 2.10  Revenue by category

* **Type:** Clustered bar chart
* **Position / size:** x 444, y 196, w 270, h 230
* **Y-axis:** Product[category]
* **X-axis:** [Total Revenue]
* **Tooltip:** [Gross Margin %], [Return Rate]
* **Formatting / conditional formatting / notes:** Bar colour rules on [Gross Margin %] (< 30% red).

### 2.11  Revenue by region

* **Type:** Map (filled map or bubble)
* **Position / size:** x 726, y 196, w 270, h 230
* **Location:** Customer[country]
* **Size:** [Total Revenue]
* **Tooltip:** [AOV], [Gross Margin %]
* **Formatting / conditional formatting / notes:** Use bubble map; if the map visual is disabled by tenant policy use a bar chart by Customer[region].

### 2.12  Order status mix

* **Type:** Clustered column chart
* **Position / size:** x 1008, y 196, w 260, h 230
* **X-axis:** 'Order Status'[order_status] (sorted by status_sort)
* **Y-axis:** [Total Orders]
* **Data labels:** On
* **Formatting / conditional formatting / notes:** Colours: Delivered #27AE60, In Transit #2A9D8F, Backordered #F39C12, Cancelled #C0392B, Unknown #8D99AE.

### 2.13  Top / bottom products

* **Type:** Table (top and bottom products)
* **Position / size:** x 12, y 438, w 520, h 270
* **Columns:** Product[product_name], Product[category], [Total Revenue], [Gross Margin %], [Units Sold], [Return Rate]
* **Visual-level filter:** Top N: 15 by [Total Revenue]; second copy of visual with Bottom N: 15 (use bookmark 'Show bottom 15' toggle)
* **Formatting / conditional formatting / notes:** Data bars on [Total Revenue]; conditional font colour on [Gross Margin %] < 20%. Right-click row > Drill through > 'Investigate Product'.

### 2.14  Discount vs margin by category

* **Type:** Scatter chart
* **Position / size:** x 544, y 438, w 360, h 270
* **X-axis:** [Discount Rate %]
* **Y-axis:** [Gross Margin %]
* **Size:** [Total Revenue]
* **Legend:** Product[category]
* **Details:** Product[sub_category]
* **Formatting / conditional formatting / notes:** Add trend line. Shows that deeper discounts erode margin.

### 2.15  Returns by reason group

* **Type:** Stacked column chart
* **Position / size:** x 916, y 438, w 352, h 270
* **X-axis:** Product[category]
* **Legend:** 'Return Reason'[reason_group]
* **Y-axis:** [Units Returned]
* **Formatting / conditional formatting / notes:** Switch to 100% stacked via bookmark 'Share view'.

## Interactions (Format > Edit interactions)

All slicers filter all visuals. 2.10 category bars cross-highlight 2.13 and 2.14. Disable 2.11 -> 2.9 cross-filter to keep the trend stable when exploring regions.

## Drill-through

Drill-through source: product rows in 2.13 -> 'Investigate Product'.

## Bookmarks and buttons

'Show top 15' / 'Show bottom 15' (swap visible copies of 2.13), 'Absolute / Share view' for 2.15.

## Tooltips

2.10 and 2.13 use tooltip page 'TT Product'.

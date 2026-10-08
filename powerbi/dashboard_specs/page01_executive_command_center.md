# Page 1 - Executive Command Center

**Page purpose.** Give executives a 30-second answer to 'How is the company performing overall?' and show where the chain is under stress.

**Business question.** How is the company performing overall? Where should leadership look first?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Date[year_num]` | Dropdown, multi-select, default 2025 | x 840 y 60 w 140 h 34 |
| `Date[month_year]` | Dropdown (sorted by month_year_sort) | x 990 y 60 w 140 h 34 |
| `Customer[region]` | Dropdown | x 1140 y 60 w 128 h 34 |
| `Product[category]` | Dropdown | x 690 y 60 w 140 h 34 |

## Page-level filters

* Date[is_actuals] = TRUE

## Visuals

### 1.1  Revenue

* **Type:** Card (new card visual)
* **Position / size:** x 12, y 108, w 150, h 76
* **Fields:** [Total Revenue]
* **Formatting / conditional formatting / notes:** Reference label: [Revenue YoY %] with up/down arrow; green if >= 0, red if < 0

### 1.2  Gross Profit

* **Type:** Card (new card visual)
* **Position / size:** x 172, y 108, w 150, h 76
* **Fields:** [Gross Profit]
* **Formatting / conditional formatting / notes:** Reference label: [Gross Profit YoY %]

### 1.3  Gross Margin %

* **Type:** Card (new card visual)
* **Position / size:** x 332, y 108, w 150, h 76
* **Fields:** [Gross Margin %]
* **Formatting / conditional formatting / notes:** Reference label: [Gross Margin Change (pts)] (pts vs last year); red if < 0

### 1.4  Orders

* **Type:** Card (new card visual)
* **Position / size:** x 492, y 108, w 150, h 76
* **Fields:** [Total Orders]
* **Formatting / conditional formatting / notes:** Reference label: [Orders YoY %]

### 1.5  Inventory Value

* **Type:** Card (new card visual)
* **Position / size:** x 652, y 108, w 150, h 76
* **Fields:** [Inventory Value]
* **Formatting / conditional formatting / notes:** Last snapshot in selection

### 1.6  OEE

* **Type:** Card (new card visual)
* **Position / size:** x 812, y 108, w 150, h 76
* **Fields:** [OEE]
* **Formatting / conditional formatting / notes:** Font colour: rules - >= 70% green, 60-70% amber, < 60% red

### 1.7  Supplier On-Time %

* **Type:** Card (new card visual)
* **Position / size:** x 972, y 108, w 150, h 76
* **Fields:** [Supplier On-Time %]
* **Formatting / conditional formatting / notes:** Rules: >= 85% green, 75-85% amber, < 75% red

### 1.8  Customer Delivery % (on-time)

* **Type:** Card (new card visual)
* **Position / size:** x 1132, y 108, w 150, h 76
* **Fields:** [On-Time Delivery %]
* **Formatting / conditional formatting / notes:** Rules: >= 85% green, 75-85% amber, < 75% red

### 1.9  Revenue and gross profit trend

* **Type:** Line and clustered column chart
* **Position / size:** x 12, y 196, w 620, h 232
* **X-axis:** Date[month_year] (continuous = off; sorted by month_year_sort)
* **Column y-axis:** [Total Revenue]
* **Line y-axis:** [Gross Margin %] (secondary axis)
* **Tooltip:** [Revenue YoY %], [Total Orders], [AOV]
* **Formatting / conditional formatting / notes:** Columns #0F4C5C, line #E36414. Constant line none. Cross-filters the rest of the page.

### 1.10  Revenue by region

* **Type:** Clustered bar chart
* **Position / size:** x 644, y 196, w 300, h 232
* **Y-axis:** Customer[region]
* **X-axis:** [Total Revenue]
* **Data labels:** On
* **Tooltip:** [Gross Margin %], [Return Rate], [On-Time Delivery %]
* **Formatting / conditional formatting / notes:** Sort by [Total Revenue] descending.

### 1.11  Revenue and margin by category

* **Type:** Clustered bar chart
* **Position / size:** x 956, y 196, w 312, h 232
* **Y-axis:** Product[category]
* **X-axis:** [Total Revenue]
* **Tooltip:** [Gross Margin %], [Discount Rate %]
* **Formatting / conditional formatting / notes:** Conditional formatting (bar colour) by rules on [Gross Margin %]: < 30% #C0392B, 30-40% #F4A261, >= 40% #2A9D8F.

### 1.12  Supply chain health

* **Type:** Six KPI tiles in a 3 x 2 grid (each tile = one Card visual, 200 x 124 px, inside the 620 x 268 area)
* **Position / size:** x 12, y 440, w 620, h 268
* **Tiles (left to right, top to bottom):** [CT Suppliers KPI] "Supplier on-time", [CT Materials KPI] "Raw material days of supply", [CT Inventory KPI] "Stockout rate", [CT Warehouse KPI] "Days to dispatch", [CT Orders KPI] "Cancelled + backordered orders", [CT Shipments KPI] "On-time delivery"
* **Formatting / conditional formatting / notes:** Card background (Format > Cell/Background > fx > Field value) = [CT Colour Suppliers], [CT Colour Materials], [CT Colour Inventory], [CT Colour Warehouse], [CT Colour Orders], [CT Colour Shipments] respectively, with transparency 85% so text stays readable. A button 'Open Control Tower' (Page navigation > page 10) sits at the top right of this area.

### 1.13  Manufacturing health by plant

* **Type:** Clustered column chart
* **Position / size:** x 644, y 440, w 300, h 268
* **X-axis:** Plant[plant_name]
* **Y-axis:** [OEE]
* **Data labels:** On (0%)
* **Tooltip:** [Availability], [Performance], [Quality]
* **Formatting / conditional formatting / notes:** Bar colour by rules: >= 70% #27AE60, 60-70% #F39C12, < 60% #C0392B. Reference line at 70% (target). Tooltip page 'TT Plant'.

### 1.14  Major operational alerts

* **Type:** Card (text)
* **Position / size:** x 956, y 440, w 312, h 268
* **Fields:** [Alert Text]
* **Formatting / conditional formatting / notes:** Multi-line text, font 12 pt, red accent bar on the left (shape). Shows 'No red alerts' when everything is green.

## Interactions (Format > Edit interactions)

Month/region/category slicers filter every visual. Visual 1.10 (region) and 1.11 (category) cross-filter each other and the trend. Turn OFF cross-filtering from 1.9 (trend) to the KPI cards so cards always show the slicer selection, not a single clicked month. Turn OFF interactions from 1.14 to everything.

## Drill-through

No drill-through on this page. The 'Open Control Tower' button (top right of tile area 1.12) leads to page 10, which is the drill-through source.

## Bookmarks and buttons

'Reset all filters' (button, top right), 'Focus 2025' (sets year slicer to 2025).

## Tooltips

Visual 1.13 uses tooltip page 'TT Plant'.

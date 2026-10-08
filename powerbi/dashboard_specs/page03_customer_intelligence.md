# Page 3 - Customer Intelligence

**Page purpose.** Show who buys, who returns, who is valuable and whether customers stay.

**Business question.** Is growth from new or returning customers? Which segments are valuable and which are slipping away?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Date[year_num]` | Tile slicer | x 12 y 60 w 200 h 34 |
| `Customer[region]` | Dropdown | x 224 y 60 w 160 h 34 |
| `Customer[customer_segment]` | Dropdown | x 396 y 60 w 180 h 34 |
| `Customer[marketing_opt_in]` | Dropdown | x 588 y 60 w 140 h 34 |

## Page-level filters

* Date[is_actuals] = TRUE

## Visuals

### 3.1  Customers

* **Type:** Card (new card visual)
* **Position / size:** x 12, y 108, w 150, h 76
* **Fields:** [Customers]

### 3.2  New Customers

* **Type:** Card (new card visual)
* **Position / size:** x 172, y 108, w 150, h 76
* **Fields:** [New Customers]

### 3.3  Returning Customers

* **Type:** Card (new card visual)
* **Position / size:** x 332, y 108, w 150, h 76
* **Fields:** [Returning Customers]

### 3.4  Repeat Purchase Rate

* **Type:** Card (new card visual)
* **Position / size:** x 492, y 108, w 150, h 76
* **Fields:** [Repeat Purchase Rate]

### 3.5  Customer Value (hist. GP)

* **Type:** Card (new card visual)
* **Position / size:** x 652, y 108, w 150, h 76
* **Fields:** [Customer Lifetime Value (Historical)]
* **Formatting / conditional formatting / notes:** Tooltip text: historical gross profit per customer, not a forecast

### 3.6  Orders per Customer

* **Type:** Card (new card visual)
* **Position / size:** x 812, y 108, w 150, h 76
* **Fields:** [Orders per Customer]

### 3.7  Revenue per Customer

* **Type:** Card (new card visual)
* **Position / size:** x 972, y 108, w 150, h 76
* **Fields:** [Revenue per Customer]

### 3.8  Inactive (180d+)

* **Type:** Card (new card visual)
* **Position / size:** x 1132, y 108, w 150, h 76
* **Fields:** [Inactive Customers (180d+)]
* **Formatting / conditional formatting / notes:** Not affected by date slicer (segment as of 2025-12-31)

### 3.9  New vs returning customers by month

* **Type:** Stacked column chart
* **Position / size:** x 12, y 196, w 420, h 230
* **X-axis:** Date[month_year]
* **Y-axis:** [New Customers], [Returning Customers]
* **Formatting / conditional formatting / notes:** New #E36414, Returning #0F4C5C.

### 3.10  Customers by segment

* **Type:** Donut chart (limit: use only because 8 slices max)
* **Position / size:** x 444, y 196, w 240, h 230
* **Legend:** Customer[customer_segment]
* **Values:** [Customers by Segment]
* **Formatting / conditional formatting / notes:** If you prefer, replace with a horizontal bar chart sorted descending (recommended for readability).

### 3.11  Revenue by segment

* **Type:** Clustered bar chart
* **Position / size:** x 696, y 196, w 270, h 230
* **Y-axis:** Customer[customer_segment]
* **X-axis:** [Total Revenue]
* **Tooltip:** [Revenue per Customer], [Customers]

### 3.12  Purchase frequency distribution

* **Type:** Column chart
* **Position / size:** x 978, y 196, w 290, h 230
* **X-axis:** Customer[lifetime_orders] (bin size 1, cap at 10 using a group)
* **Y-axis:** [Customers by Segment]
* **Formatting / conditional formatting / notes:** Create a bin group on lifetime_orders: 1, 2, 3, 4, 5, 6-9, 10+.

### 3.13  Cohort retention (months since first order)

* **Type:** Matrix (cohort retention)
* **Position / size:** x 12, y 438, w 620, h 270
* **Rows:** Customer[cohort_month] (format mmm yyyy)
* **Columns:** Orders[months_since_first_order]
* **Values:** [Cohort Retention %]
* **Slicers on this page:** Date slicer must NOT be applied to this visual (Edit interactions: Date slicer -> 3.13 = None)
* **Formatting / conditional formatting / notes:** Conditional formatting > Background colour > Gradient on the value: min white #FFFFFF, max #0F4C5C. Show only months 0-12 via visual filter months_since_first_order <= 12.

### 3.14  Top 15 customers by revenue

* **Type:** Table
* **Position / size:** x 644, y 438, w 330, h 270
* **Columns:** Customer[full_name], Customer[region], Customer[customer_segment], [Total Revenue], [Orders per Customer]
* **Filter:** Top N 15 by [Total Revenue]
* **Formatting / conditional formatting / notes:** Data bars on revenue.

### 3.15  Customers by region

* **Type:** Clustered bar chart
* **Position / size:** x 986, y 438, w 282, h 270
* **Y-axis:** Customer[region]
* **X-axis:** [Customers]
* **Tooltip:** [Revenue per Customer], [Return Rate]

## Interactions (Format > Edit interactions)

Segment slicer filters everything except the cohort matrix, whose cohort logic ignores the Date slicer by design (Edit interactions).

## Drill-through

No drill-through. Table 3.14 supports Drill down by Customer[full_name] only.

## Bookmarks and buttons

'Reset filters'.

## Tooltips

Default tooltips.

# Page 6 - Manufacturing Intelligence

**Page purpose.** Show how efficiently plants convert time and materials into good output and which of the three OEE factors limits each plant.

**Business question.** Which plants are inefficient, and is the cause availability, performance or quality?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Date[year_num]` | Tile slicer | x 12 y 60 w 200 h 34 |
| `Date[quarter_year]` | Dropdown | x 224 y 60 w 140 h 34 |
| `Plant[plant_name]` | Dropdown | x 376 y 60 w 200 h 34 |
| `Product[category]` | Dropdown | x 588 y 60 w 170 h 34 |

## Page-level filters

* Date[is_actuals] = TRUE

## Visuals

### 6.1  Production Output

* **Type:** Card (new card visual)
* **Position / size:** x 12, y 108, w 150, h 76
* **Fields:** [Production Output]

### 6.2  OEE

* **Type:** Card (new card visual)
* **Position / size:** x 172, y 108, w 150, h 76
* **Fields:** [OEE]
* **Formatting / conditional formatting / notes:** Rules: >= 70% green, 60-70% amber, < 60% red

### 6.3  Availability

* **Type:** Card (new card visual)
* **Position / size:** x 332, y 108, w 150, h 76
* **Fields:** [Availability]

### 6.4  Performance

* **Type:** Card (new card visual)
* **Position / size:** x 492, y 108, w 150, h 76
* **Fields:** [Performance]

### 6.5  Quality

* **Type:** Card (new card visual)
* **Position / size:** x 652, y 108, w 150, h 76
* **Fields:** [Quality]

### 6.6  Capacity Utilization

* **Type:** Card (new card visual)
* **Position / size:** x 812, y 108, w 150, h 76
* **Fields:** [Capacity Utilization]
* **Formatting / conditional formatting / notes:** Share of machine-shifts scheduled

### 6.7  Downtime Hours

* **Type:** Card (new card visual)
* **Position / size:** x 972, y 108, w 150, h 76
* **Fields:** [Downtime Hours]

### 6.8  Defect Rate

* **Type:** Card (new card visual)
* **Position / size:** x 1132, y 108, w 150, h 76
* **Fields:** [Defect Rate]
* **Formatting / conditional formatting / notes:** Red if > 3%

### 6.9  Plant comparison (OEE factors)

* **Type:** Clustered bar chart
* **Position / size:** x 12, y 196, w 420, h 250
* **Y-axis:** Plant[plant_name]
* **X-axis:** [Availability], [Performance], [Quality], [OEE]
* **Sort:** [OEE] descending
* **Formatting / conditional formatting / notes:** Four series: A #8D99AE, P #2A9D8F, Q #F4A261, OEE #0F4C5C (thicker). Tooltip page 'TT Plant'.

### 6.10  OEE trend

* **Type:** Line chart
* **Position / size:** x 444, y 196, w 420, h 250
* **X-axis:** Date[month_year]
* **Y-axis:** [OEE]
* **Legend:** Plant[plant_name]
* **Formatting / conditional formatting / notes:** Add reference line at 70%.

### 6.11  Production vs rated capacity

* **Type:** Line and clustered column chart
* **Position / size:** x 876, y 196, w 392, h 250
* **X-axis:** Date[quarter_year]
* **Column y-axis:** [Production Output]
* **Line y-axis:** [Output vs Rated Capacity]
* **Formatting / conditional formatting / notes:** Production vs plan (plan = rated capacity at rated speed).

### 6.12  Where planned time is lost (hours)

* **Type:** Stacked column chart
* **Position / size:** x 12, y 458, w 420, h 250
* **X-axis:** Plant[plant_name]
* **Y-axis:** [Material Shortage Hours], [Equipment Failure Hours], [Changeover Hours]
* **Formatting / conditional formatting / notes:** Shows supply-driven loss vs equipment vs changeover per plant.

### 6.13  Defects by type

* **Type:** Clustered column chart
* **Position / size:** x 444, y 458, w 420, h 250
* **X-axis:** 'Defect Type'[defect_type]
* **Y-axis:** [Defect Units (by type)]
* **Legend:** Product[category]

### 6.14  Plant scorecard

* **Type:** Gauge-free KPI table
* **Position / size:** x 876, y 458, w 392, h 250
* **Columns:** Plant[plant_name], [Production Output], [OEE], [Capacity Utilization], [Defect Rate], [Scrap Cost]
* **Formatting / conditional formatting / notes:** Conditional formatting: background rules on OEE and Defect Rate. Replaces decorative gauges.

## Interactions (Format > Edit interactions)

Plant slicer and clicking a plant bar in 6.9 filter all visuals. Clicking a machine type is not on this page (see page 7).

## Drill-through

From 6.14 right-click plant > Drill through > 'Machine Detail' optional; page 7 covers plant -> machine drill-down with a hierarchy.

## Bookmarks and buttons

'Reset filters'.

## Tooltips

6.9 and 6.14 use 'TT Plant'.

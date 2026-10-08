# Page 7 - Machine & Maintenance

**Page purpose.** Find the machines, causes and maintenance patterns behind lost production.

**Business question.** Which machines and causes explain most downtime, and is maintenance reactive?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Date[year_num]` | Tile slicer | x 12 y 60 w 200 h 34 |
| `Plant[plant_name]` | Dropdown | x 224 y 60 w 200 h 34 |
| `Machine[machine_type]` | Dropdown | x 436 y 60 w 180 h 34 |
| `'Downtime Type'[loss_category]` | Dropdown | x 628 y 60 w 180 h 34 |

## Page-level filters

* Date[is_actuals] = TRUE

## Visuals

### 7.1  Downtime Hours

* **Type:** Card (new card visual)
* **Position / size:** x 12, y 108, w 150, h 76
* **Fields:** [Downtime Hours]

### 7.2  Failure Events

* **Type:** Card (new card visual)
* **Position / size:** x 172, y 108, w 150, h 76
* **Fields:** [Failure Events]

### 7.3  Failures / 1,000 h

* **Type:** Card (new card visual)
* **Position / size:** x 332, y 108, w 150, h 76
* **Fields:** [Failures per 1,000 Operating Hours]

### 7.4  Maintenance Orders

* **Type:** Card (new card visual)
* **Position / size:** x 492, y 108, w 150, h 76
* **Fields:** [Maintenance Orders]

### 7.5  Corrective %

* **Type:** Card (new card visual)
* **Position / size:** x 652, y 108, w 150, h 76
* **Fields:** [Corrective Maintenance %]
* **Formatting / conditional formatting / notes:** Red if > 80%

### 7.6  Production Loss (units)

* **Type:** Card (new card visual)
* **Position / size:** x 812, y 108, w 150, h 76
* **Fields:** [Production Loss (Units)]

### 7.7  Maintenance Cost

* **Type:** Card (new card visual)
* **Position / size:** x 972, y 108, w 150, h 76
* **Fields:** [Maintenance Cost]

### 7.8  Capacity Utilization

* **Type:** Card (new card visual)
* **Position / size:** x 1132, y 108, w 150, h 76
* **Fields:** [Capacity Utilization]

### 7.9  Downtime Pareto by cause

* **Type:** Line and clustered column chart (Pareto)
* **Position / size:** x 12, y 196, w 460, h 250
* **X-axis:** 'Downtime Type'[downtime_type] sorted by [Downtime Hours] descending
* **Column y-axis:** [Downtime Hours]
* **Line y-axis:** [Cumulative Downtime % (Pareto)]
* **Formatting / conditional formatting / notes:** Line axis fixed 0-100%. 80% reference line.

### 7.10  Plant > Line > Machine: downtime

* **Type:** Bar chart with hierarchy (drill-down)
* **Position / size:** x 484, y 196, w 400, h 250
* **Y-axis:** Machine hierarchy: plant_name > production_line > machine_id
* **X-axis:** [Unplanned Downtime Hours]
* **Tooltip:** [Failures per 1,000 Operating Hours], [Production Loss (Units)]
* **Formatting / conditional formatting / notes:** Enable drill-down icon (top of visual) and 'Expand all down one level'. Bar colour rule: failures per 1,000 h >= 2x fleet average dark red.

### 7.11  Failure trend

* **Type:** Line chart
* **Position / size:** x 896, y 196, w 372, h 250
* **X-axis:** Date[month_year]
* **Y-axis:** [Failure Events]
* **Legend:** Plant[plant_name]

### 7.12  Machine comparison

* **Type:** Table (machine comparison)
* **Position / size:** x 12, y 458, w 520, h 250
* **Columns:** Machine[machine_id], Machine[plant_name], Machine[machine_type], [Failure Events], [Failures per 1,000 Operating Hours], [Unplanned Downtime Hours], [Production Loss (Units)], [Availability]
* **Filter:** Top N 15 by [Production Loss (Units)]
* **Formatting / conditional formatting / notes:** Data bars on production loss; conditional font red when failures per 1,000 h > 40.

### 7.13  Maintenance: preventive vs corrective

* **Type:** Clustered column chart
* **Position / size:** x 544, y 458, w 340, h 250
* **X-axis:** Date[quarter_year]
* **Y-axis:** [Maintenance Orders]
* **Legend:** Maintenance[maintenance_type]
* **Formatting / conditional formatting / notes:** Preventive #2A9D8F, Corrective #C0392B.

### 7.14  Maintenance history (drill)

* **Type:** Table (maintenance history)
* **Position / size:** x 896, y 458, w 372, h 250
* **Columns:** Maintenance[work_order_id], Maintenance[maintenance_type], Machine[machine_id], Maintenance[duration_hours], Maintenance[cost]
* **Filter:** Show when a machine is selected in 7.10 / 7.12; otherwise top 20 by cost
* **Formatting / conditional formatting / notes:** Details table; fields are raw columns, so set Summarization to 'Don't summarize'.

## Interactions (Format > Edit interactions)

Selecting a machine in 7.10 or 7.12 filters 7.11, 7.13 and 7.14 (maintenance history). Slicer 'loss_category' filters 7.9 and 7.10.

## Drill-through

Hierarchy drill-down Plant -> Line -> Machine on 7.10.

## Bookmarks and buttons

'Reset filters'.

## Tooltips

7.10 default tooltip with listed fields.

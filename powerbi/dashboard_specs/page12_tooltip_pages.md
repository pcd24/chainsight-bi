# Page 12 - Tooltip pages (hidden): TT Product, TT Plant, TT Supplier

**Page purpose.** Small report-page tooltips shown on hover. Each is a page of size Tooltip (320 x 240) with Page information > Allow use as tooltip = On, hidden from navigation.

**Business question.** -

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

## Slicers

None.

## Page-level filters

* Tooltip field: Product[product_name] (TT Product), Plant[plant_name] (TT Plant), Supplier[supplier_name] (TT Supplier)

## Visuals

### 12.1  Product snapshot

* **Type:** Multi-row card (TT Product)
* **Position / size:** x 0, y 0, w 320, h 120
* **Fields:** [Total Revenue], [Gross Margin %], [Return Rate], [Stockout Rate]

### 12.2  Revenue trend

* **Type:** Line chart (TT Product)
* **Position / size:** x 0, y 120, w 320, h 120
* **X-axis:** Date[month_year]
* **Y-axis:** [Total Revenue]
* **Formatting / conditional formatting / notes:** No axes titles, sparkline style.

### 12.3  OEE breakdown

* **Type:** Multi-row card (TT Plant)
* **Position / size:** x 0, y 0, w 320, h 120
* **Fields:** [OEE], [Availability], [Performance], [Quality]

### 12.4  Lost hours

* **Type:** Clustered column (TT Plant)
* **Position / size:** x 0, y 120, w 320, h 120
* **X-axis:** (static) three measures
* **Y-axis:** [Material Shortage Hours], [Equipment Failure Hours], [Changeover Hours]

### 12.5  Supplier snapshot

* **Type:** Multi-row card (TT Supplier)
* **Position / size:** x 0, y 0, w 320, h 120
* **Fields:** [Supplier Spend], [Supplier On-Time %], [Average Supplier Lead Time], [Supplier Defect Rate]

### 12.6  On-time % trend

* **Type:** Line chart (TT Supplier)
* **Position / size:** x 0, y 120, w 320, h 120
* **X-axis:** Date[month_year]
* **Y-axis:** [Supplier On-Time %]

## Interactions (Format > Edit interactions)

n/a

## Drill-through

n/a

## Bookmarks and buttons

n/a

## Tooltips

Assign in the Format pane of the host visual: Tooltips > Type: Report page > Page: TT ...

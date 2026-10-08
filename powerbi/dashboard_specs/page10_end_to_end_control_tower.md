# Page 10 - End-to-End Control Tower

**Page purpose.** The signature page: one status tile per stage of the chain with a KPI and RAG status, plus a drill path from a business problem back to its supply-side cause.

**Business question.** Where is the chain breaking right now, and what upstream stage is behind it?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Date[year_num]` | Tile slicer | x 12 y 60 w 200 h 34 |
| `Date[month_year]` | Dropdown | x 224 y 60 w 150 h 34 |
| `Product[category]` | Dropdown | x 386 y 60 w 170 h 34 |
| `Warehouse[region]` | Dropdown | x 568 y 60 w 170 h 34 |
| `Plant[plant_name]` | Dropdown | x 750 y 60 w 190 h 34 |

## Page-level filters

* Date[is_actuals] = TRUE

## Visuals

### 10.1  Chain: SUPPLIERS > MATERIALS > MANUFACTURING > INVENTORY > WAREHOUSE > ORDERS > SHIPMENTS > CUSTOMERS

* **Type:** 8 status tiles in one row (each = 1 Card visual + 1 rectangle shape)
* **Position / size:** x 12, y 108, w 1256, h 150
* **Tile 1 Suppliers:** Card [CT Suppliers KPI] (format 0%) + subtitle 'On-time %'; rectangle fill = [CT Colour Suppliers]
* **Tile 2 Materials:** Card [CT Materials KPI] (0 days) + subtitle 'Days of supply'; fill = [CT Colour Materials]
* **Tile 3 Manufacturing:** Card [CT Manufacturing KPI] (0%) + 'OEE'; fill = [CT Colour Manufacturing]
* **Tile 4 Inventory:** Card [CT Inventory KPI] (0.0%) + 'Stockout rate'; fill = [CT Colour Inventory]
* **Tile 5 Warehouse:** Card [CT Warehouse KPI] (0.0 days) + 'Days to dispatch'; fill = [CT Colour Warehouse]
* **Tile 6 Orders:** Card [CT Orders KPI] (0.0%) + 'Cancelled + backordered'; fill = [CT Colour Orders]
* **Tile 7 Shipments:** Card [CT Shipments KPI] (0%) + 'On-time delivery'; fill = [CT Colour Shipments]
* **Tile 8 Customers:** Card [CT Customers KPI] (0.0%) + 'Return rate'; fill = [CT Colour Customers]
* **Formatting / conditional formatting / notes:** Each tile is 148 x 150 px with a 24 px right-arrow shape (>) between tiles. Rectangle fill uses Format > Fill > fx > Field value > the [CT Colour ...] measure (the tile tint comes from the DAX status, not hard-coded). Tile text: KPI 24 pt, subtitle 10 pt grey.

### 10.2  Supporting KPIs

* **Type:** Card row (supporting numbers)
* **Position / size:** x 12, y 266, w 1256, h 60
* **Cards:** [Red Stages], [Material Shortage Hours], [Stocked-out Products], [Unfulfilled Order Value], [Late Deliveries], [Delayed Shipments]
* **Formatting / conditional formatting / notes:** [Red Stages] > 0 shows red.

### 10.3  What explains unfulfilled order value?

* **Type:** Decomposition tree
* **Position / size:** x 12, y 338, w 560, h 370
* **Analyze:** [Unfulfilled Order Value]
* **Explain by (in this order):** Product[category], Product[primary_plant], Warehouse[warehouse_name], Product[product_name]
* **Formatting / conditional formatting / notes:** Expand the tree: Category > Plant > Warehouse > Product. This is the investigative drill from 'delayed/unfulfilled orders' to the product and where it is made/stocked.

### 10.4  Problem products

* **Type:** Table (problem products - drill-through source)
* **Position / size:** x 584, y 338, w 684, h 200
* **Columns:** Product[product_name], Product[category], Product[primary_plant], [Product Problem Lines %], [Stockout Rate], [Material Shortage Hours], [Unfulfilled Order Value]
* **Filter:** Top N 15 by [Product Problem Lines %] with [Total Orders] >= 300
* **Formatting / conditional formatting / notes:** Conditional formatting: data bars on [Unfulfilled Order Value], red font on [Stockout Rate] > 15%. RIGHT-CLICK ROW > DRILL THROUGH > 'Investigate Product'.

### 10.5  Supplier lateness vs plant material-shortage hours

* **Type:** Line chart
* **Position / size:** x 584, y 550, w 340, h 158
* **X-axis:** Date[month_year]
* **Y-axis:** [Late Delivery %]
* **Secondary y-axis:** [Material Shortage Hours]
* **Formatting / conditional formatting / notes:** Dual axis shows the association between supplier lateness and shortage hours (association, not proven cause).

### 10.6  Stockout rate vs delayed dispatch

* **Type:** Line chart
* **Position / size:** x 936, y 550, w 332, h 158
* **X-axis:** Date[month_year]
* **Y-axis:** [Stockout Rate]
* **Secondary y-axis:** [Average Days to Dispatch]

## Interactions (Format > Edit interactions)

Slicers filter every tile (each tile measure respects Date/Product/Warehouse/Plant filters where the underlying fact is related). Selecting a plant filters tiles 2, 3 and the shortage-hours line; inventory/orders tiles ignore Plant (no relationship) by design - note shown in a footnote text box.

## Drill-through

Drill-through target page: 'Investigate Product' (see below). Path: Delayed/unfulfilled orders > Product > Warehouse > Inventory > Production > Required material > Supplier > Purchase order.

## Bookmarks and buttons

'Reset filters'; 'Peak season' (Nov-Dec); 'Supplier disruption Jul-Nov 2024' (sets month slicer to Jul-Nov 2024).

## Tooltips

Tiles use a tooltip page with the stage's 3 supporting measures (optional).

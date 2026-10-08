# Page 8 - Logistics & Fulfilment

**Page purpose.** Show shipping speed, reliability and cost by carrier, region and warehouse.

**Business question.** Are deliveries late because of the warehouse (slow dispatch) or the carrier (slow transit)?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

**Navigation.** Top navigation strip (y 8, h 36): 10 page-navigation buttons (Executive, E-Commerce, Customers, Inventory, Suppliers, Manufacturing, Machines, Logistics, Demand-Supply, Control Tower). Button action = Page navigation; the current page button uses fill #0F4C5C and white text, others transparent with #52606D text.

## Slicers

| Field | Type / settings | Position |
|---|---|---|
| `Date[year_num]` | Tile slicer (ship date) | x 12 y 60 w 200 h 34 |
| `Carrier[carrier_name]` | Dropdown | x 224 y 60 w 200 h 34 |
| `Location[region]` | Dropdown (destination region) | x 436 y 60 w 180 h 34 |
| `Warehouse[warehouse_name]` | Dropdown | x 628 y 60 w 220 h 34 |

## Page-level filters

* Date[is_actuals] = TRUE

## Visuals

### 8.1  Shipments

* **Type:** Card (new card visual)
* **Position / size:** x 12, y 108, w 150, h 76
* **Fields:** [Shipments Count]

### 8.2  On-Time Delivery %

* **Type:** Card (new card visual)
* **Position / size:** x 172, y 108, w 150, h 76
* **Fields:** [On-Time Delivery %]
* **Formatting / conditional formatting / notes:** Rules: >= 85% green, 75-85% amber, < 75% red

### 8.3  Avg Delivery Time (days)

* **Type:** Card (new card visual)
* **Position / size:** x 332, y 108, w 150, h 76
* **Fields:** [Average Delivery Time (Days)]

### 8.4  Avg Days to Ship

* **Type:** Card (new card visual)
* **Position / size:** x 492, y 108, w 150, h 76
* **Fields:** [Average Days to Ship]

### 8.5  Avg Transit (days)

* **Type:** Card (new card visual)
* **Position / size:** x 652, y 108, w 150, h 76
* **Fields:** [Average Transit Time (Days)]

### 8.6  Delayed Shipments

* **Type:** Card (new card visual)
* **Position / size:** x 812, y 108, w 150, h 76
* **Fields:** [Delayed Shipments]

### 8.7  Shipping Cost

* **Type:** Card (new card visual)
* **Position / size:** x 972, y 108, w 150, h 76
* **Fields:** [Shipping Cost]

### 8.8  Cost per kg

* **Type:** Card (new card visual)
* **Position / size:** x 1132, y 108, w 150, h 76
* **Fields:** [Shipping Cost per kg]

### 8.9  Carrier comparison: on-time %

* **Type:** Clustered column chart
* **Position / size:** x 12, y 196, w 420, h 250
* **X-axis:** Carrier[carrier_name]
* **Y-axis:** [On-Time Delivery %]
* **Tooltip:** [Average Transit Time (Days)], [Shipping Cost per kg], [Shipments Count]
* **Formatting / conditional formatting / notes:** Conditional colour by rules (85/75).

### 8.10  Regional delivery performance

* **Type:** Clustered bar chart
* **Position / size:** x 444, y 196, w 400, h 250
* **Y-axis:** Location[region]
* **X-axis:** [On-Time Delivery %]
* **Tooltip:** [Average Delivery Time (Days)], [Average Days to Ship]
* **Formatting / conditional formatting / notes:** Destination region from Shipments[destination_location_key].

### 8.11  Delivery-time distribution

* **Type:** Column chart
* **Position / size:** x 856, y 196, w 412, h 250
* **X-axis:** Shipments[order_to_delivery_days] grouped: 1-3, 4-5, 6-7, 8-10, 11-14, 15+
* **Y-axis:** [Shipments Count]
* **Formatting / conditional formatting / notes:** Group on order_to_delivery_days.

### 8.12  Where delivery time goes: dispatch vs transit by warehouse

* **Type:** Stacked bar chart
* **Position / size:** x 12, y 458, w 420, h 250
* **Y-axis:** Warehouse[warehouse_name]
* **X-axis:** [Average Days to Ship], [Average Transit Time (Days)]
* **Formatting / conditional formatting / notes:** Stacked bars show whether delay sits in the warehouse or with the carrier.

### 8.13  Delayed shipments by warehouse

* **Type:** Table
* **Position / size:** x 444, y 458, w 400, h 250
* **Columns:** Warehouse[warehouse_name], [Delayed Shipments], [On-Time Delivery %], [Average Days Late (Delayed)]
* **Formatting / conditional formatting / notes:** Sort by [Delayed Shipments] descending.

### 8.14  Shipping cost per shipment trend

* **Type:** Line chart
* **Position / size:** x 856, y 458, w 412, h 250
* **X-axis:** Date[month_year]
* **Y-axis:** [Shipping Cost per Shipment]
* **Secondary:** [Shipping Cost % of Revenue]
* **Formatting / conditional formatting / notes:** Date here = ship date (active relationship).

## Interactions (Format > Edit interactions)

Carrier slicer filters all visuals; 8.9 cross-filters 8.10-8.14.

## Drill-through

None.

## Bookmarks and buttons

'Reset filters'.

## Tooltips

Default.

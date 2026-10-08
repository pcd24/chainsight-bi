# Page 11 - Investigate Product (drill-through, hidden)

**Page purpose.** Follow one product through the chain: what happened to its orders, its warehouse stock, its production, the materials it needs and the suppliers of those materials.

**Business question.** Why are deliveries delayed for this product?

**Canvas.** 1280 x 720 px (16:9), page background #F5F7FA, visual background white, 6 px rounded border #E4E7EB, 12 px gutters.

## Slicers

None.

## Page-level filters

* Drill-through field: Product[product_name] (Keep all filters = ON)
* Date[is_actuals] = TRUE

## Visuals

### 11.1  Product

* **Type:** Card (title)
* **Position / size:** x 12, y 60, w 400, h 76
* **Fields:** Product[product_name]
* **Subtitle:** Product[category] and Product[primary_plant] (multi-row card)
* **Formatting / conditional formatting / notes:** Back button (top left, Action = Back).

### 11.2  Problem lines %

* **Type:** Card (new card visual)
* **Position / size:** x 424, y 108, w 150, h 76
* **Fields:** [Product Problem Lines %]

### 11.3  Stockout rate

* **Type:** Card (new card visual)
* **Position / size:** x 584, y 108, w 150, h 76
* **Fields:** [Stockout Rate]

### 11.4  Material shortage h

* **Type:** Card (new card visual)
* **Position / size:** x 744, y 108, w 150, h 76
* **Fields:** [Material Shortage Hours]

### 11.5  Backordered units

* **Type:** Card (new card visual)
* **Position / size:** x 904, y 108, w 150, h 76
* **Fields:** [Backordered Units]

### 11.6  Revenue not fulfilled

* **Type:** Card (new card visual)
* **Position / size:** x 1064, y 108, w 150, h 76
* **Fields:** [Unfulfilled Order Value]

### 11.7  1. Orders: status by month

* **Type:** Stacked column chart
* **Position / size:** x 12, y 148, w 420, h 270
* **X-axis:** Date[month_year]
* **Y-axis:** [Total Orders]
* **Legend:** 'Order Status'[order_status]
* **Formatting / conditional formatting / notes:** Status colours as page 2.

### 11.8  2. Warehouse stock: on hand vs backordered

* **Type:** Line chart
* **Position / size:** x 444, y 148, w 420, h 270
* **X-axis:** Date[month_year]
* **Y-axis:** [Inventory Quantity]
* **Secondary:** [Backordered Units]

### 11.9  3. Production: output and shortage hours

* **Type:** Line and clustered column chart
* **Position / size:** x 876, y 148, w 392, h 270
* **X-axis:** Date[month_year]
* **Column y-axis:** [Production Output]
* **Line y-axis:** [Material Shortage Hours]

### 11.10  4. Required materials (bill of materials)

* **Type:** Table
* **Position / size:** x 12, y 430, w 420, h 278
* **Columns:** Material[material_name], Material[material_family], [BOM Qty per Unit], [Material Days of Supply]
* **Visual-level filter:** [BOM Qty per Unit] is not blank
* **Formatting / conditional formatting / notes:** Only the materials this product uses are listed (BOM bridge).

### 11.11  5. Suppliers of those materials

* **Type:** Table
* **Position / size:** x 444, y 430, w 420, h 278
* **Columns:** Supplier[supplier_name], [Supplier On-Time % (Product Materials)], [Late Deliveries (Product Materials)]
* **Visual-level filter:** [Late Deliveries (Product Materials)] is not blank
* **Formatting / conditional formatting / notes:** Sorted by late deliveries descending. Neutral colours; use bands, not 'worst'.

### 11.12  6. Recent purchase orders for these materials

* **Type:** Table
* **Position / size:** x 876, y 430, w 392, h 278
* **Columns:** Purchases[po_number], Material[material_name], Supplier[supplier_name], Purchases[promised_lead_days], Purchases[quantity_ordered], Purchases[received_flag]
* **Note:** Filtered through Material via a visual-level filter [BOM Qty per Unit] not blank on Material
* **Formatting / conditional formatting / notes:** Optional: list is long; show Top N 20 by Purchases[order_date_key] descending.

## Interactions (Format > Edit interactions)

Opened via drill-through from pages 2, 4, 9 and 10.

## Drill-through

This is the drill-through target. Add the 'Back' button.

## Bookmarks and buttons

None.

## Tooltips

None.

-- 02_raw/01_raw_tables.sql
-- RAW layer: one table per source file. Every column is TEXT on purpose:
-- the raw layer must accept anything the source sends, including bad dates and negative numbers.
-- Cleaning and typing happen in the staging layer, never here.

DROP SCHEMA IF EXISTS raw CASCADE;
CREATE SCHEMA raw;

CREATE TABLE raw.locations (
    location_id TEXT,
    city TEXT,
    state_province TEXT,
    country TEXT,
    region TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.customers (
    customer_id TEXT,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    phone TEXT,
    location_id TEXT,
    signup_date TEXT,
    marketing_opt_in TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.products (
    product_id TEXT,
    sku TEXT,
    product_name TEXT,
    category TEXT,
    sub_category TEXT,
    list_price TEXT,
    unit_cost_2023 TEXT,
    unit_cost_2024 TEXT,
    unit_cost_2025 TEXT,
    weight_kg TEXT,
    launch_date TEXT,
    manufacturing_plant_id TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.materials (
    material_id TEXT,
    material_name TEXT,
    material_family TEXT,
    standard_cost TEXT,
    unit_of_measure TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.bom (
    product_id TEXT,
    material_id TEXT,
    qty_per_unit TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.suppliers (
    supplier_id TEXT,
    supplier_name TEXT,
    country TEXT,
    supplier_tier TEXT,
    payment_terms_days TEXT,
    quoted_lead_time_days TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.supplier_materials (
    supplier_id TEXT,
    material_id TEXT,
    sourcing_share TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.warehouses (
    warehouse_id TEXT,
    warehouse_name TEXT,
    location_id TEXT,
    region TEXT,
    capacity_units TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.plants (
    plant_id TEXT,
    plant_name TEXT,
    location_id TEXT,
    opened_year TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.machines (
    machine_id TEXT,
    plant_id TEXT,
    production_line TEXT,
    machine_type TEXT,
    install_year TEXT,
    manufacturer TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.carriers (
    carrier_id TEXT,
    carrier_name TEXT,
    service_level TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.promotions (
    promotion_id TEXT,
    promotion_name TEXT,
    promotion_type TEXT,
    discount_pct TEXT,
    start_date TEXT,
    end_date TEXT,
    category_scope TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.orders (
    order_id TEXT,
    customer_id TEXT,
    order_date TEXT,
    order_status TEXT,
    channel TEXT,
    payment_method TEXT,
    warehouse_id TEXT,
    promised_delivery_date TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.order_items (
    order_item_id TEXT,
    order_id TEXT,
    product_id TEXT,
    quantity TEXT,
    unit_price TEXT,
    discount_pct TEXT,
    promotion_id TEXT,
    unit_cost TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.shipments (
    shipment_id TEXT,
    order_id TEXT,
    carrier_id TEXT,
    warehouse_id TEXT,
    ship_date TEXT,
    promised_delivery_date TEXT,
    delivered_date TEXT,
    shipping_cost TEXT,
    weight_kg TEXT,
    shipment_status TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.returns (
    return_id TEXT,
    order_item_id TEXT,
    order_id TEXT,
    product_id TEXT,
    return_date TEXT,
    quantity_returned TEXT,
    return_reason TEXT,
    refund_amount TEXT,
    restocked TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.inventory_snapshots (
    snapshot_date TEXT,
    warehouse_id TEXT,
    product_id TEXT,
    qty_on_hand TEXT,
    qty_backordered TEXT,
    qty_in_transit TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.material_inventory_snapshots (
    snapshot_date TEXT,
    plant_id TEXT,
    material_id TEXT,
    qty_on_hand TEXT,
    qty_on_order TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.purchase_orders (
    po_line_id TEXT,
    po_number TEXT,
    order_date TEXT,
    plant_id TEXT,
    supplier_id TEXT,
    material_id TEXT,
    quantity_ordered TEXT,
    unit_price TEXT,
    promised_date TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.supplier_deliveries (
    receipt_id TEXT,
    po_line_id TEXT,
    received_date TEXT,
    qty_received TEXT,
    qty_rejected TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.production_runs (
    run_id TEXT,
    run_date TEXT,
    shift TEXT,
    machine_id TEXT,
    plant_id TEXT,
    product_id TEXT,
    planned_minutes TEXT,
    downtime_minutes TEXT,
    operating_minutes TEXT,
    rated_units_per_min TEXT,
    planned_qty TEXT,
    total_units TEXT,
    good_units TEXT,
    defect_units TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.downtime_events (
    downtime_id TEXT,
    run_id TEXT,
    event_date TEXT,
    machine_id TEXT,
    plant_id TEXT,
    downtime_type TEXT,
    duration_minutes TEXT,
    is_planned TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.maintenance_orders (
    work_order_id TEXT,
    machine_id TEXT,
    plant_id TEXT,
    work_order_date TEXT,
    maintenance_type TEXT,
    duration_hours TEXT,
    cost TEXT,
    triggered_by_run_id TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE raw.defects (
    defect_id TEXT,
    run_id TEXT,
    defect_type TEXT,
    defect_qty TEXT,
    detection_stage TEXT,
    disposition TEXT,
    _loaded_at TIMESTAMPTZ DEFAULT now()
);

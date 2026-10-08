-- 04_dimensions/03_bridge_product_material.sql
-- Bill of materials as a BRIDGE table (a product uses many materials; a material is used by many products).
-- It is the one genuine many-to-many in the model. In Power BI it is hidden, both dimensions filter it, and it never
-- filters the dimensions back (see powerbi/model/model_specification.md).
CREATE TABLE dw.bridge_product_material AS
SELECT p.product_key, m.material_key, b.qty_per_unit
FROM staging.stg_bom b
JOIN dw.dim_product p ON p.product_id = b.product_id
JOIN dw.dim_material m ON m.material_id = b.material_id;
ALTER TABLE dw.bridge_product_material ADD PRIMARY KEY (product_key, material_key);
CREATE INDEX ix_bridge_material ON dw.bridge_product_material (material_key);

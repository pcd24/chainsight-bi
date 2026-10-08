-- 03_staging/01_functions_and_rejects.sql
-- Reusable cleaning functions + the reject log. Every row removed from the pipeline is logged here
-- with a reason, so raw_rows = staging_rows + rejected_rows always reconciles (see 06_quality).
DROP SCHEMA IF EXISTS staging CASCADE;
CREATE SCHEMA staging;

CREATE TABLE staging.rejects (
    reject_id    BIGSERIAL PRIMARY KEY,
    source_table TEXT NOT NULL,
    record_key   TEXT,
    reason       TEXT NOT NULL,
    rejected_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trim, collapse repeated whitespace, turn empty strings into NULL.
CREATE FUNCTION staging.clean_text(t TEXT) RETURNS TEXT AS $$
    SELECT NULLIF(btrim(regexp_replace(t, '\s+', ' ', 'g')), '')
$$ LANGUAGE sql IMMUTABLE;

-- Accepts YYYY-MM-DD and DD/MM/YYYY. Impossible dates (e.g. 2024-02-30) return NULL instead of failing the load.
CREATE FUNCTION staging.parse_date(t TEXT) RETURNS DATE AS $$
BEGIN
    t := btrim(t);
    IF t IS NULL OR t = '' THEN RETURN NULL; END IF;
    IF t ~ '^\d{4}-\d{2}-\d{2}$' THEN RETURN t::date; END IF;
    IF t ~ '^\d{2}/\d{2}/\d{4}$' THEN RETURN to_date(t, 'DD/MM/YYYY'); END IF;
    RETURN NULL;
EXCEPTION WHEN others THEN
    RETURN NULL;
END $$ LANGUAGE plpgsql IMMUTABLE;

-- Collapse spelling/case variants of product categories into the 7 official labels.
CREATE FUNCTION staging.std_category(t TEXT) RETURNS TEXT AS $$
    SELECT CASE lower(regexp_replace(btrim(t), '[\s\-_]+', ' ', 'g'))
        WHEN 'smart home' THEN 'Smart Home'
        WHEN 'computer accessories' THEN 'Computer Accessories' WHEN 'computer accessory' THEN 'Computer Accessories'
        WHEN 'mobile accessories' THEN 'Mobile Accessories'     WHEN 'mobile accessory' THEN 'Mobile Accessories'
        WHEN 'audio' THEN 'Audio'
        WHEN 'wearables' THEN 'Wearables' WHEN 'wearable' THEN 'Wearables'
        WHEN 'networking' THEN 'Networking'
        WHEN 'gaming accessories' THEN 'Gaming Accessories' WHEN 'gaming accessory' THEN 'Gaming Accessories'
    END
$$ LANGUAGE sql IMMUTABLE;

-- Order status: map variants to 4 valid values, anything else becomes 'Unknown' (kept, flagged, not guessed).
CREATE FUNCTION staging.std_order_status(t TEXT) RETURNS TEXT AS $$
    SELECT CASE lower(regexp_replace(btrim(t), '[\s\-_]+', ' ', 'g'))
        WHEN 'delivered' THEN 'Delivered' WHEN 'delivrd' THEN 'Delivered'
        WHEN 'cancelled' THEN 'Cancelled' WHEN 'canceled' THEN 'Cancelled'
        WHEN 'in transit' THEN 'In Transit'
        WHEN 'backordered' THEN 'Backordered' WHEN 'back ordered' THEN 'Backordered'
        ELSE 'Unknown' END
$$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION staging.std_payment(t TEXT) RETURNS TEXT AS $$
    SELECT CASE upper(btrim(t)) WHEN 'COD' THEN 'COD' WHEN 'PAYPAL' THEN 'PayPal' ELSE initcap(btrim(t)) END
$$ LANGUAGE sql IMMUTABLE;

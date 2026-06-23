-- V2__add_entity_id.sql
-- Flyway migration: adds entity_id column to all tables for multi-entity
-- data segregation. Existing rows are backfilled with 'SG' to preserve
-- the Singapore baseline exactly.

-- ── client ──────────────────────────────────────────────────
ALTER TABLE client
    ADD COLUMN entity_id VARCHAR(10);

UPDATE client SET entity_id = 'SG' WHERE entity_id IS NULL;

ALTER TABLE client
    ALTER COLUMN entity_id SET NOT NULL;

ALTER TABLE client
    ALTER COLUMN residency_region TYPE VARCHAR(50);

-- Remove the SG-only default so inserts must supply the value explicitly
ALTER TABLE client
    ALTER COLUMN residency_region DROP DEFAULT;

CREATE INDEX IF NOT EXISTS idx_client_entity ON client (entity_id);

-- ── portfolio ───────────────────────────────────────────────
ALTER TABLE portfolio
    ADD COLUMN entity_id VARCHAR(10);

UPDATE portfolio SET entity_id = 'SG' WHERE entity_id IS NULL;

ALTER TABLE portfolio
    ALTER COLUMN entity_id SET NOT NULL;

-- Remove SG-only defaults; application must supply entity-specific values
ALTER TABLE portfolio
    ALTER COLUMN base_currency DROP DEFAULT;

ALTER TABLE portfolio
    ALTER COLUMN booking_centre DROP DEFAULT;

ALTER TABLE portfolio
    ALTER COLUMN mgmt_fee_bps DROP DEFAULT;

CREATE INDEX IF NOT EXISTS idx_portfolio_entity ON portfolio (entity_id);

-- ── holding ─────────────────────────────────────────────────
ALTER TABLE holding
    ADD COLUMN entity_id VARCHAR(10);

UPDATE holding SET entity_id = 'SG' WHERE entity_id IS NULL;

ALTER TABLE holding
    ALTER COLUMN entity_id SET NOT NULL;

-- Remove SG-only default
ALTER TABLE holding
    ALTER COLUMN currency DROP DEFAULT;

CREATE INDEX IF NOT EXISTS idx_holding_entity ON holding (entity_id);
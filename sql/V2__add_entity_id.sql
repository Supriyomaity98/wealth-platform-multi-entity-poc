-- V2__add_entity_id.sql
-- Flyway-compatible migration: add entity_id dimension to all business tables.
-- Default 'SG' preserves existing Singapore data without a backfill step.

-- ── client ──────────────────────────────────────────────────────
ALTER TABLE client
    ADD COLUMN IF NOT EXISTS entity_id VARCHAR(10) NOT NULL DEFAULT 'SG';

-- Update residency_region default to match shared contract naming
ALTER TABLE client
    ALTER COLUMN residency_region TYPE VARCHAR(50);

ALTER TABLE client
    ALTER COLUMN residency_region SET DEFAULT 'azure-southeast-asia';

-- Update language default to full locale
ALTER TABLE client
    ALTER COLUMN language SET DEFAULT 'en_SG';

CREATE INDEX IF NOT EXISTS idx_client_entity ON client (entity_id);

-- ── portfolio ───────────────────────────────────────────────────
ALTER TABLE portfolio
    ADD COLUMN IF NOT EXISTS entity_id VARCHAR(10) NOT NULL DEFAULT 'SG';

CREATE INDEX IF NOT EXISTS idx_portfolio_entity ON portfolio (entity_id);

-- ── holding ─────────────────────────────────────────────────────
ALTER TABLE holding
    ADD COLUMN IF NOT EXISTS entity_id VARCHAR(10) NOT NULL DEFAULT 'SG';

CREATE INDEX IF NOT EXISTS idx_holding_entity ON holding (entity_id);
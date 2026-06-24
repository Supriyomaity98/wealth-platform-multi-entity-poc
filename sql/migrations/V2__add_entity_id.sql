-- sql/migrations/V2__add_entity_id.sql
-- Dialect: PostgreSQL 14+   Tool: Flyway (versioned migration)
-- Purpose: Add entity_id scoping to all business tables.
--          Backfill existing rows to 'SG' (baseline preservation).
--          Idempotent via DO $$ blocks guarded by information_schema checks.

BEGIN;

-- entity_config lookup table
CREATE TABLE IF NOT EXISTS entity_config (
    entity_id                CHAR(2)       PRIMARY KEY CHECK (entity_id IN ('SG','HK','CH')),
    currency                 CHAR(3)       NOT NULL,
    locale                   VARCHAR(10)   NOT NULL,
    regulator                VARCHAR(50)   NOT NULL,
    booking_centre           VARCHAR(50)   NOT NULL,
    fee_bps                  INTEGER       NOT NULL,
    large_position_threshold NUMERIC(18,2) NOT NULL,
    suitability_framework    VARCHAR(50)   NOT NULL,
    kms_vault_name           VARCHAR(50)   NOT NULL,
    data_residency_strict    BOOLEAN       NOT NULL DEFAULT TRUE
);

INSERT INTO entity_config
    (entity_id,currency,locale,regulator,booking_centre,fee_bps,large_position_threshold,suitability_framework,kms_vault_name,data_residency_strict)
VALUES
    ('SG','SGD','en_SG','MAS',  'Singapore', 50,  250000,  'MAS_FAA_2002',    'wealth-sg',TRUE),
    ('HK','HKD','en_HK','SFC',  'Hong Kong', 60,  1000000, 'SFC_COP_2019',    'wealth-hk',TRUE),
    ('CH','CHF','de_CH','FINMA','Zurich',    80,  5000000, 'FINMA_LSFin_2020','wealth-ch',TRUE)
ON CONFLICT (entity_id) DO NOTHING;

-- client table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='client' AND column_name='entity_id'
    ) THEN
        ALTER TABLE client ADD COLUMN entity_id CHAR(2) NOT NULL DEFAULT 'SG';
        ALTER TABLE client ADD CONSTRAINT chk_client_entity_id CHECK (entity_id IN ('SG','HK','CH'));
        UPDATE client SET entity_id='SG';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_client_entity ON client (entity_id, client_id);

-- portfolio table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='portfolio' AND column_name='entity_id'
    ) THEN
        ALTER TABLE portfolio ADD COLUMN entity_id CHAR(2) NOT NULL DEFAULT 'SG';
        ALTER TABLE portfolio ADD CONSTRAINT chk_portfolio_entity_id CHECK (entity_id IN ('SG','HK','CH'));
        UPDATE portfolio SET entity_id='SG';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_portfolio_entity ON portfolio (entity_id, portfolio_id);

-- holding table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='holding' AND column_name='entity_id'
    ) THEN
        ALTER TABLE holding ADD COLUMN entity_id CHAR(2) NOT NULL DEFAULT 'SG';
        ALTER TABLE holding ADD CONSTRAINT chk_holding_entity_id CHECK (entity_id IN ('SG','HK','CH'));
        UPDATE holding SET entity_id='SG';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_holding_entity ON holding (entity_id, holding_id);

-- FK: enforce entity_id references entity_config
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='fk_client_entity_config' AND table_name='client') THEN
        ALTER TABLE client ADD CONSTRAINT fk_client_entity_config FOREIGN KEY (entity_id) REFERENCES entity_config (entity_id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='fk_portfolio_entity_config' AND table_name='portfolio') THEN
        ALTER TABLE portfolio ADD CONSTRAINT fk_portfolio_entity_config FOREIGN KEY (entity_id) REFERENCES entity_config (entity_id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='fk_holding_entity_config' AND table_name='holding') THEN
        ALTER TABLE holding ADD CONSTRAINT fk_holding_entity_config FOREIGN KEY (entity_id) REFERENCES entity_config (entity_id);
    END IF;
END $$;

COMMIT;
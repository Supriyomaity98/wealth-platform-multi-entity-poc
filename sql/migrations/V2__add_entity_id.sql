-- Migration V2: Add entity_id to all business tables, backfill SG,
-- add CHECK constraints, composite indexes, and entity_config table.
-- Dialect: PostgreSQL. Idempotent where possible.
-- Secrets: DB credentials via ${KEYVAULT:wealth-sg-db-connection-string}
--          (and wealth-hk / wealth-ch for other entities).

-- ===== 1. client =====
ALTER TABLE client
    ADD COLUMN IF NOT EXISTS entity_id CHAR(2);

UPDATE client SET entity_id = 'SG' WHERE entity_id IS NULL;

ALTER TABLE client
    ALTER COLUMN entity_id SET NOT NULL,
    ALTER COLUMN entity_id SET DEFAULT 'SG';

ALTER TABLE client DROP CONSTRAINT IF EXISTS client_pkey;
ALTER TABLE client ADD PRIMARY KEY (client_id, entity_id);

ALTER TABLE client DROP CONSTRAINT IF EXISTS chk_client_entity;
ALTER TABLE client ADD CONSTRAINT chk_client_entity
    CHECK (entity_id IN ('SG', 'HK', 'CH'));

CREATE INDEX IF NOT EXISTS idx_client_entity
    ON client (entity_id, client_id);

-- ===== 2. portfolio =====
-- Drop FK before PK change on client
ALTER TABLE portfolio DROP CONSTRAINT IF EXISTS portfolio_client_id_fkey;

ALTER TABLE portfolio
    ADD COLUMN IF NOT EXISTS entity_id CHAR(2);

UPDATE portfolio SET entity_id = 'SG' WHERE entity_id IS NULL;

ALTER TABLE portfolio
    ALTER COLUMN entity_id SET NOT NULL,
    ALTER COLUMN entity_id SET DEFAULT 'SG';

ALTER TABLE portfolio DROP CONSTRAINT IF EXISTS portfolio_pkey;
ALTER TABLE portfolio ADD PRIMARY KEY (portfolio_id, entity_id);

ALTER TABLE portfolio DROP CONSTRAINT IF EXISTS chk_portfolio_entity;
ALTER TABLE portfolio ADD CONSTRAINT chk_portfolio_entity
    CHECK (entity_id IN ('SG', 'HK', 'CH'));

ALTER TABLE portfolio DROP CONSTRAINT IF EXISTS fk_portfolio_client;
ALTER TABLE portfolio ADD CONSTRAINT fk_portfolio_client
    FOREIGN KEY (client_id, entity_id)
    REFERENCES client (client_id, entity_id);

DROP INDEX IF EXISTS idx_portfolio_client;
CREATE INDEX IF NOT EXISTS idx_portfolio_entity_client
    ON portfolio (entity_id, client_id);

-- ===== 3. holding =====
ALTER TABLE holding DROP CONSTRAINT IF EXISTS holding_portfolio_id_fkey;

ALTER TABLE holding
    ADD COLUMN IF NOT EXISTS entity_id CHAR(2);

UPDATE holding SET entity_id = 'SG' WHERE entity_id IS NULL;

ALTER TABLE holding
    ALTER COLUMN entity_id SET NOT NULL,
    ALTER COLUMN entity_id SET DEFAULT 'SG';

ALTER TABLE holding DROP CONSTRAINT IF EXISTS holding_pkey;
ALTER TABLE holding ADD PRIMARY KEY (holding_id, entity_id);

ALTER TABLE holding DROP CONSTRAINT IF EXISTS chk_holding_entity;
ALTER TABLE holding ADD CONSTRAINT chk_holding_entity
    CHECK (entity_id IN ('SG', 'HK', 'CH'));

ALTER TABLE holding DROP CONSTRAINT IF EXISTS fk_holding_portfolio;
ALTER TABLE holding ADD CONSTRAINT fk_holding_portfolio
    FOREIGN KEY (portfolio_id, entity_id)
    REFERENCES portfolio (portfolio_id, entity_id);

DROP INDEX IF EXISTS idx_holding_portfolio;
CREATE INDEX IF NOT EXISTS idx_holding_entity_portfolio
    ON holding (entity_id, portfolio_id);

-- ===== 4. entity_config reference table =====
CREATE TABLE IF NOT EXISTS entity_config (
    entity_id              CHAR(2)      PRIMARY KEY,
    currency               CHAR(3)      NOT NULL,
    locale                 VARCHAR(10)  NOT NULL,
    regulator              VARCHAR(20)  NOT NULL,
    booking_centre         VARCHAR(50)  NOT NULL,
    fee_bps                INTEGER      NOT NULL,
    large_position_threshold NUMERIC(18,2) NOT NULL,
    suitability_framework  VARCHAR(50)  NOT NULL,
    kms_vault_name         VARCHAR(50)  NOT NULL,
    data_region            VARCHAR(30),
    disclosure_locale      VARCHAR(10),
    audit_trail_enabled    BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_entity_config_id
        CHECK (entity_id IN ('SG', 'HK', 'CH'))
);

INSERT INTO entity_config
    (entity_id, currency, locale, regulator, booking_centre, fee_bps,
     large_position_threshold, suitability_framework, kms_vault_name)
VALUES
    ('SG','SGD','en_SG','MAS',  'Singapore', 50,  250000,'MAS_FAA_2002',    'wealth-sg'),
    ('HK','HKD','en_HK','SFC',  'Hong Kong', 60, 1000000,'SFC_COP_2019',    'wealth-hk'),
    ('CH','CHF','de_CH','FINMA','Zurich',     80, 5000000,'FINMA_LSFin_2020','wealth-ch')
ON CONFLICT (entity_id) DO NOTHING;
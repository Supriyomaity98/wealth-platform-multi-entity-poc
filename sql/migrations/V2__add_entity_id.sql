-- Dialect: PostgreSQL 14+
-- Migration V2: add entity_id to all business tables; backfill SG baseline.
-- Idempotent: ADD COLUMN IF NOT EXISTS; DO $$ PL/pgSQL guards on all constraints.
-- Secrets: DB credentials resolved via ${KEYVAULT:wealth-{entity}-db-password}
-- Entity determined at app startup from WEALTH_ENTITY_ID env var (not in SQL).

BEGIN;

-- 0. Entity config reference table + canonical seed
CREATE TABLE IF NOT EXISTS entity_config (
    entity_id                CHAR(2)       PRIMARY KEY,
    currency_code            CHAR(3)       NOT NULL,
    default_locale           VARCHAR(10)   NOT NULL,
    fee_bps                  INTEGER       NOT NULL,
    large_position_threshold NUMERIC(18,2) NOT NULL,
    booking_centre           VARCHAR(50)   NOT NULL,
    suitability_framework    VARCHAR(50)   NOT NULL,
    primary_regulator        VARCHAR(20)   NOT NULL,
    data_region              VARCHAR(30)   NOT NULL,
    key_vault_name           VARCHAR(50)   NOT NULL,
    CONSTRAINT chk_entity_config_id CHECK (entity_id IN ('SG','HK','CH'))
);

INSERT INTO entity_config
    (entity_id,currency_code,default_locale,fee_bps,large_position_threshold,
     booking_centre,suitability_framework,primary_regulator,data_region,key_vault_name)
VALUES
    ('SG','SGD','en_SG', 50,  250000,'Singapore','MAS_FAA_2002',    'MAS',  'ap-southeast-1','wealth-sg'),
    ('HK','HKD','en_HK', 60,1000000,'Hong Kong', 'SFC_COP_2019',    'SFC',  'ap-east-1',     'wealth-hk'),
    ('CH','CHF','de_CH', 80,5000000,'Zurich',    'FINMA_LSFin_2020','FINMA','eu-central-1',  'wealth-ch')
ON CONFLICT (entity_id) DO NOTHING;

-- 1. client
ALTER TABLE client ADD COLUMN IF NOT EXISTS entity_id CHAR(2);
UPDATE client SET entity_id = 'SG' WHERE entity_id IS NULL;
ALTER TABLE client ALTER COLUMN entity_id SET NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname='chk_client_entity_id' AND conrelid='client'::regclass
    ) THEN
        ALTER TABLE client ADD CONSTRAINT chk_client_entity_id
            CHECK (entity_id IN ('SG','HK','CH'));
    END IF;
END$$;

-- 2. portfolio
ALTER TABLE portfolio ADD COLUMN IF NOT EXISTS entity_id CHAR(2);
UPDATE portfolio SET entity_id = 'SG' WHERE entity_id IS NULL;
ALTER TABLE portfolio ALTER COLUMN entity_id SET NOT NULL;
ALTER TABLE portfolio ALTER COLUMN base_currency  DROP DEFAULT;
ALTER TABLE portfolio ALTER COLUMN booking_centre DROP DEFAULT;
ALTER TABLE portfolio ALTER COLUMN mgmt_fee_bps   DROP DEFAULT;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname='chk_portfolio_entity_id' AND conrelid='portfolio'::regclass
    ) THEN
        ALTER TABLE portfolio ADD CONSTRAINT chk_portfolio_entity_id
            CHECK (entity_id IN ('SG','HK','CH'));
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname='chk_portfolio_base_currency' AND conrelid='portfolio'::regclass
    ) THEN
        ALTER TABLE portfolio ADD CONSTRAINT chk_portfolio_base_currency
            CHECK (base_currency IN ('SGD','HKD','CHF'));
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname='chk_portfolio_booking_centre' AND conrelid='portfolio'::regclass
    ) THEN
        ALTER TABLE portfolio ADD CONSTRAINT chk_portfolio_booking_centre
            CHECK (booking_centre IN ('Singapore','Hong Kong','Zurich'));
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname='chk_portfolio_mgmt_fee_bps' AND conrelid='portfolio'::regclass
    ) THEN
        ALTER TABLE portfolio ADD CONSTRAINT chk_portfolio_mgmt_fee_bps
            CHECK (mgmt_fee_bps IN (50,60,80));
    END IF;
END$$;

-- 3. holding
ALTER TABLE holding ADD COLUMN IF NOT EXISTS entity_id CHAR(2);
UPDATE holding h
   SET entity_id = p.entity_id
  FROM portfolio p
 WHERE h.portfolio_id = p.portfolio_id
   AND h.entity_id IS NULL;
UPDATE holding SET entity_id = 'SG' WHERE entity_id IS NULL;
ALTER TABLE holding ALTER COLUMN entity_id SET NOT NULL;
ALTER TABLE holding ALTER COLUMN currency DROP DEFAULT;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname='chk_holding_entity_id' AND conrelid='holding'::regclass
    ) THEN
        ALTER TABLE holding ADD CONSTRAINT chk_holding_entity_id
            CHECK (entity_id IN ('SG','HK','CH'));
    END IF;
END$$;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
         WHERE conname='chk_holding_currency' AND conrelid='holding'::regclass
    ) THEN
        ALTER TABLE holding ADD CONSTRAINT chk_holding_currency
            CHECK (currency IN ('SGD','HKD','CHF'));
    END IF;
END$$;

-- 4. Composite indexes (idempotent)
CREATE INDEX IF NOT EXISTS idx_client_entity            ON client    (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_entity         ON portfolio (entity_id, portfolio_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_entity_client  ON portfolio (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_holding_entity           ON holding   (entity_id, holding_id);
CREATE INDEX IF NOT EXISTS idx_holding_entity_portfolio ON holding   (entity_id, portfolio_id);

COMMIT;
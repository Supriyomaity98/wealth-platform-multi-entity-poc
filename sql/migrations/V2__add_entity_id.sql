-- Migration V2: Add entity_id to all business tables, backfill SG,
-- create entity reference table, composite indexes, and RLS policies.
-- Dialect: PostgreSQL. Idempotent where possible.
-- Secrets: DB credentials via ${KEYVAULT:wealth-sg-db-connection-string}
--          (and wealth-hk / wealth-ch variants per entity).

BEGIN;

-- 1. Entity reference table
CREATE TABLE IF NOT EXISTS entity (
    entity_id              CHAR(2)      PRIMARY KEY,
    entity_name            VARCHAR(100) NOT NULL,
    currency               CHAR(3)      NOT NULL,
    locale                 VARCHAR(10)  NOT NULL,
    regulator              VARCHAR(20)  NOT NULL,
    booking_centre         VARCHAR(50)  NOT NULL,
    fee_bps                INTEGER      NOT NULL,
    large_position_threshold NUMERIC(18,2) NOT NULL,
    suitability_framework  VARCHAR(50)  NOT NULL,
    kms_vault_name         VARCHAR(50)  NOT NULL,
    CONSTRAINT chk_entity_id CHECK (entity_id IN ('SG','HK','CH'))
);

INSERT INTO entity (entity_id, entity_name, currency, locale, regulator,
    booking_centre, fee_bps, large_position_threshold,
    suitability_framework, kms_vault_name)
VALUES
  ('SG','Singapore','SGD','en_SG','MAS','Singapore',50,250000,
   'MAS_FAA_2002','wealth-sg'),
  ('HK','Hong Kong','HKD','en_HK','SFC','Hong Kong',60,1000000,
   'SFC_COP_2019','wealth-hk'),
  ('CH','Switzerland','CHF','de_CH','FINMA','Zurich',80,5000000,
   'FINMA_LSFin_2020','wealth-ch')
ON CONFLICT (entity_id) DO NOTHING;

-- 2. Add entity_id column to business tables (idempotent)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='client' AND column_name='entity_id'
  ) THEN
    ALTER TABLE client ADD COLUMN entity_id CHAR(2) DEFAULT 'SG';
    UPDATE client SET entity_id = 'SG' WHERE entity_id IS NULL;
    ALTER TABLE client ALTER COLUMN entity_id SET NOT NULL;
    ALTER TABLE client ADD CONSTRAINT chk_client_entity
      CHECK (entity_id IN ('SG','HK','CH'));
    ALTER TABLE client ADD CONSTRAINT fk_client_entity
      FOREIGN KEY (entity_id) REFERENCES entity(entity_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='portfolio' AND column_name='entity_id'
  ) THEN
    ALTER TABLE portfolio ADD COLUMN entity_id CHAR(2) DEFAULT 'SG';
    UPDATE portfolio SET entity_id = 'SG' WHERE entity_id IS NULL;
    ALTER TABLE portfolio ALTER COLUMN entity_id SET NOT NULL;
    ALTER TABLE portfolio ADD CONSTRAINT chk_portfolio_entity
      CHECK (entity_id IN ('SG','HK','CH'));
    ALTER TABLE portfolio ADD CONSTRAINT fk_portfolio_entity
      FOREIGN KEY (entity_id) REFERENCES entity(entity_id);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='holding' AND column_name='entity_id'
  ) THEN
    ALTER TABLE holding ADD COLUMN entity_id CHAR(2) DEFAULT 'SG';
    UPDATE holding SET entity_id = 'SG' WHERE entity_id IS NULL;
    ALTER TABLE holding ALTER COLUMN entity_id SET NOT NULL;
    ALTER TABLE holding ADD CONSTRAINT chk_holding_entity
      CHECK (entity_id IN ('SG','HK','CH'));
    ALTER TABLE holding ADD CONSTRAINT fk_holding_entity
      FOREIGN KEY (entity_id) REFERENCES entity(entity_id);
  END IF;
END $$;

-- 3. Composite indexes (idempotent via IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_client_entity
  ON client (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_entity
  ON portfolio (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_holding_entity
  ON holding (entity_id, portfolio_id);

-- 4. Row-Level Security for regulatory separation
ALTER TABLE client ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio ENABLE ROW LEVEL SECURITY;
ALTER TABLE holding ENABLE ROW LEVEL SECURITY;

-- Drop-if-exists then create (policies lack IF NOT EXISTS)
DO $$ BEGIN
  DROP POLICY IF EXISTS entity_isolation_client ON client;
  CREATE POLICY entity_isolation_client ON client
    USING (entity_id = current_setting('app.current_entity_id', TRUE)::CHAR(2));

  DROP POLICY IF EXISTS entity_isolation_portfolio ON portfolio;
  CREATE POLICY entity_isolation_portfolio ON portfolio
    USING (entity_id = current_setting('app.current_entity_id', TRUE)::CHAR(2));

  DROP POLICY IF EXISTS entity_isolation_holding ON holding;
  CREATE POLICY entity_isolation_holding ON holding
    USING (entity_id = current_setting('app.current_entity_id', TRUE)::CHAR(2));
END $$;

COMMIT;
-- Migration: V2__add_entity_id.sql
-- Dialect: PostgreSQL 14+
-- Purpose: Add entity_id column to all business tables, backfill SG,
--          add CHECK constraints, and add composite indexes.
-- Idempotent: guarded with DO $$ ... IF NOT EXISTS / EXISTS checks.
-- Backfill: all existing rows → entity_id = 'SG' (SG baseline preservation).

DO $$ BEGIN

  -- ================================================================
  -- TABLE: client
  -- ================================================================
  IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'client' AND column_name = 'entity_id'
  ) THEN
      ALTER TABLE client
          ADD COLUMN entity_id CHAR(2) NOT NULL DEFAULT 'SG';
  END IF;

  IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE table_name = 'client'
        AND constraint_name = 'chk_client_entity_id'
  ) THEN
      ALTER TABLE client
          ADD CONSTRAINT chk_client_entity_id
          CHECK (entity_id IN ('SG','HK','CH'));
  END IF;

  UPDATE client SET entity_id = 'SG' WHERE entity_id IS NULL OR entity_id = '';

  -- ================================================================
  -- TABLE: portfolio
  -- ================================================================
  IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'portfolio' AND column_name = 'entity_id'
  ) THEN
      ALTER TABLE portfolio
          ADD COLUMN entity_id CHAR(2) NOT NULL DEFAULT 'SG';
  END IF;

  IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE table_name = 'portfolio'
        AND constraint_name = 'chk_portfolio_entity_id'
  ) THEN
      ALTER TABLE portfolio
          ADD CONSTRAINT chk_portfolio_entity_id
          CHECK (entity_id IN ('SG','HK','CH'));
  END IF;

  UPDATE portfolio SET entity_id = 'SG' WHERE entity_id IS NULL OR entity_id = '';

  -- ================================================================
  -- TABLE: holding
  -- ================================================================
  IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'holding' AND column_name = 'entity_id'
  ) THEN
      ALTER TABLE holding
          ADD COLUMN entity_id CHAR(2) NOT NULL DEFAULT 'SG';
  END IF;

  IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE table_name = 'holding'
        AND constraint_name = 'chk_holding_entity_id'
  ) THEN
      ALTER TABLE holding
          ADD CONSTRAINT chk_holding_entity_id
          CHECK (entity_id IN ('SG','HK','CH'));
  END IF;

  UPDATE holding SET entity_id = 'SG' WHERE entity_id IS NULL OR entity_id = '';

  -- ================================================================
  -- TABLE: transaction (created fresh in V2 if not already present)
  -- ================================================================
  IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_name = 'transaction'
  ) THEN
      CREATE TABLE transaction (
          transaction_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
          entity_id      CHAR(2)     NOT NULL DEFAULT 'SG'
                                     CHECK (entity_id IN ('SG','HK','CH')),
          portfolio_id   UUID        NOT NULL REFERENCES portfolio (portfolio_id),
          trade_date     DATE        NOT NULL,
          settle_date    DATE,
          instrument     VARCHAR(50) NOT NULL,
          quantity       NUMERIC(18, 6) NOT NULL,
          price          NUMERIC(18, 6) NOT NULL,
          currency       CHAR(3)     NOT NULL DEFAULT 'SGD',
          created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
      );
  ELSE
      IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'transaction' AND column_name = 'entity_id'
      ) THEN
          ALTER TABLE transaction
              ADD COLUMN entity_id CHAR(2) NOT NULL DEFAULT 'SG';
      END IF;

      IF NOT EXISTS (
          SELECT 1 FROM information_schema.table_constraints
          WHERE table_name = 'transaction'
            AND constraint_name = 'chk_transaction_entity_id'
      ) THEN
          ALTER TABLE transaction
              ADD CONSTRAINT chk_transaction_entity_id
              CHECK (entity_id IN ('SG','HK','CH'));
      END IF;

      UPDATE transaction SET entity_id = 'SG' WHERE entity_id IS NULL OR entity_id = '';
  END IF;

  -- ================================================================
  -- TABLE: fee (created fresh in V2 if not already present)
  -- ================================================================
  IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_name = 'fee'
  ) THEN
      CREATE TABLE fee (
          fee_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
          entity_id    CHAR(2)     NOT NULL DEFAULT 'SG'
                                   CHECK (entity_id IN ('SG','HK','CH')),
          portfolio_id UUID        NOT NULL REFERENCES portfolio (portfolio_id),
          fee_bps      INTEGER     NOT NULL DEFAULT 50,
          fee_amount   NUMERIC(18, 2) NOT NULL,
          accrual_date DATE        NOT NULL,
          created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
      );
  ELSE
      IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'fee' AND column_name = 'entity_id'
      ) THEN
          ALTER TABLE fee
              ADD COLUMN entity_id CHAR(2) NOT NULL DEFAULT 'SG';
      END IF;

      IF NOT EXISTS (
          SELECT 1 FROM information_schema.table_constraints
          WHERE table_name = 'fee'
            AND constraint_name = 'chk_fee_entity_id'
      ) THEN
          ALTER TABLE fee
              ADD CONSTRAINT chk_fee_entity_id
              CHECK (entity_id IN ('SG','HK','CH'));
      END IF;

      UPDATE fee SET entity_id = 'SG' WHERE entity_id IS NULL OR entity_id = '';
  END IF;

END $$;

-- ================================================================
-- Composite indexes (idempotent via IF NOT EXISTS)
-- ================================================================
CREATE INDEX IF NOT EXISTS idx_client_entity_id           ON client      (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_entity_client    ON portfolio   (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_holding_entity_portfolio   ON holding     (entity_id, portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transaction_entity_portf   ON transaction (entity_id, portfolio_id);
CREATE INDEX IF NOT EXISTS idx_fee_entity_portfolio       ON fee         (entity_id, portfolio_id);
-- Wealth Platform PostgreSQL schema — Multi-entity deployment.
-- Dialect: PostgreSQL (uses gen_random_uuid(), TIMESTAMPTZ, CHECK constraints).
-- Entity-aware: every business table carries entity_id CHAR(2) NOT NULL.
-- SG baseline behaviour is preserved: all defaults match original SG values.

-- =============================================================
-- Entity reference table (canonical entity definitions)
-- =============================================================
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

-- Seed canonical entity values
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

-- =============================================================
-- Business tables
-- =============================================================
CREATE TABLE client (
    client_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)      NOT NULL DEFAULT 'SG',
    full_name         VARCHAR(200) NOT NULL,
    residency_region  VARCHAR(20)  NOT NULL DEFAULT 'ap-southeast-1',
    language          VARCHAR(10)  NOT NULL DEFAULT 'en',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT chk_client_entity CHECK (entity_id IN ('SG','HK','CH')),
    CONSTRAINT fk_client_entity FOREIGN KEY (entity_id) REFERENCES entity(entity_id)
);

CREATE TABLE portfolio (
    portfolio_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)      NOT NULL DEFAULT 'SG',
    client_id         UUID NOT NULL REFERENCES client (client_id),
    base_currency     CHAR(3)      NOT NULL DEFAULT 'SGD',
    booking_centre    VARCHAR(50)  NOT NULL DEFAULT 'Singapore',
    mgmt_fee_bps      INTEGER      NOT NULL DEFAULT 50,
    market_value      NUMERIC(18, 2),
    CONSTRAINT chk_portfolio_entity CHECK (entity_id IN ('SG','HK','CH')),
    CONSTRAINT fk_portfolio_entity FOREIGN KEY (entity_id) REFERENCES entity(entity_id)
);

CREATE TABLE holding (
    holding_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)      NOT NULL DEFAULT 'SG',
    portfolio_id      UUID NOT NULL REFERENCES portfolio (portfolio_id),
    instrument        VARCHAR(50)  NOT NULL,
    currency          CHAR(3)      NOT NULL DEFAULT 'SGD',
    quantity          NUMERIC(18, 6) NOT NULL,
    market_value      NUMERIC(18, 2),
    CONSTRAINT chk_holding_entity CHECK (entity_id IN ('SG','HK','CH')),
    CONSTRAINT fk_holding_entity FOREIGN KEY (entity_id) REFERENCES entity(entity_id)
);

-- Composite indexes: entity_id + original PK-adjacent column
CREATE INDEX idx_client_entity ON client (entity_id, client_id);
CREATE INDEX idx_portfolio_entity ON portfolio (entity_id, client_id);
CREATE INDEX idx_holding_entity ON holding (entity_id, portfolio_id);

-- Original indexes preserved
CREATE INDEX idx_portfolio_client ON portfolio (client_id);
CREATE INDEX idx_holding_portfolio ON holding (portfolio_id);

-- =============================================================
-- Row-Level Security policies for regulatory separation
-- =============================================================
-- App role must set: SET app.current_entity_id = 'SG';
-- Then RLS ensures only matching rows are visible.

ALTER TABLE client ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio ENABLE ROW LEVEL SECURITY;
ALTER TABLE holding ENABLE ROW LEVEL SECURITY;

CREATE POLICY entity_isolation_client ON client
    USING (entity_id = current_setting('app.current_entity_id', TRUE)::CHAR(2));

CREATE POLICY entity_isolation_portfolio ON portfolio
    USING (entity_id = current_setting('app.current_entity_id', TRUE)::CHAR(2));

CREATE POLICY entity_isolation_holding ON holding
    USING (entity_id = current_setting('app.current_entity_id', TRUE)::CHAR(2));
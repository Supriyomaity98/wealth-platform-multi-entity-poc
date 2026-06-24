-- sql/schema.sql
-- Dialect: PostgreSQL 14+
-- Wealth Platform schema — multi-entity baseline.
-- entity_id CHAR(2) scopes every business table to SG | HK | CH.
-- SG defaults preserved exactly for backward compatibility.

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

CREATE TABLE IF NOT EXISTS client (
    client_id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id        CHAR(2)     NOT NULL DEFAULT 'SG' CHECK (entity_id IN ('SG','HK','CH'))
                                 REFERENCES entity_config (entity_id),
    full_name        VARCHAR(200) NOT NULL,
    residency_region VARCHAR(20)  NOT NULL DEFAULT 'ap-southeast-1',
    language         VARCHAR(10)  NOT NULL DEFAULT 'en',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS portfolio (
    portfolio_id  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id     CHAR(2)     NOT NULL DEFAULT 'SG' CHECK (entity_id IN ('SG','HK','CH'))
                              REFERENCES entity_config (entity_id),
    client_id     UUID        NOT NULL REFERENCES client (client_id),
    base_currency CHAR(3)     NOT NULL DEFAULT 'SGD',
    booking_centre VARCHAR(50) NOT NULL DEFAULT 'Singapore',
    mgmt_fee_bps  INTEGER     NOT NULL DEFAULT 50,
    market_value  NUMERIC(18, 2)
);

CREATE TABLE IF NOT EXISTS holding (
    holding_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id    CHAR(2)     NOT NULL DEFAULT 'SG' CHECK (entity_id IN ('SG','HK','CH'))
                             REFERENCES entity_config (entity_id),
    portfolio_id UUID        NOT NULL REFERENCES portfolio (portfolio_id),
    instrument   VARCHAR(50) NOT NULL,
    currency     CHAR(3)     NOT NULL DEFAULT 'SGD',
    quantity     NUMERIC(18, 6) NOT NULL,
    market_value NUMERIC(18, 2)
);

-- Preserved original indexes
CREATE INDEX IF NOT EXISTS idx_portfolio_client  ON portfolio (client_id);
CREATE INDEX IF NOT EXISTS idx_holding_portfolio ON holding   (portfolio_id);

-- Composite entity-scoped indexes for multi-entity query performance
CREATE INDEX IF NOT EXISTS idx_client_entity    ON client    (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_entity ON portfolio (entity_id, portfolio_id);
CREATE INDEX IF NOT EXISTS idx_holding_entity   ON holding   (entity_id, holding_id);
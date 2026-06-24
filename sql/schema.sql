-- Dialect: PostgreSQL 14+
-- Wealth Platform schema — multi-entity (SG, HK, CH).
-- entity_id CHAR(2) enforces per-entity segregation on every business table.
-- Secrets resolved via ${KEYVAULT:wealth-{entity}-db-password} at app layer.

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

CREATE TABLE IF NOT EXISTS client (
    client_id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)      NOT NULL,
    full_name         VARCHAR(200) NOT NULL,
    residency_region  VARCHAR(20)  NOT NULL,
    language          VARCHAR(10)  NOT NULL,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT chk_client_entity_id CHECK (entity_id IN ('SG','HK','CH'))
);

CREATE TABLE IF NOT EXISTS portfolio (
    portfolio_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)      NOT NULL,
    client_id         UUID         NOT NULL REFERENCES client (client_id),
    base_currency     CHAR(3)      NOT NULL,
    booking_centre    VARCHAR(50)  NOT NULL,
    mgmt_fee_bps      INTEGER      NOT NULL,
    market_value      NUMERIC(18,2),
    CONSTRAINT chk_portfolio_entity_id      CHECK (entity_id      IN ('SG','HK','CH')),
    CONSTRAINT chk_portfolio_base_currency  CHECK (base_currency  IN ('SGD','HKD','CHF')),
    CONSTRAINT chk_portfolio_booking_centre CHECK (booking_centre IN ('Singapore','Hong Kong','Zurich')),
    CONSTRAINT chk_portfolio_mgmt_fee_bps   CHECK (mgmt_fee_bps   IN (50,60,80))
);

CREATE TABLE IF NOT EXISTS holding (
    holding_id        UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)       NOT NULL,
    portfolio_id      UUID          NOT NULL REFERENCES portfolio (portfolio_id),
    instrument        VARCHAR(50)   NOT NULL,
    currency          CHAR(3)       NOT NULL,
    quantity          NUMERIC(18,6) NOT NULL,
    market_value      NUMERIC(18,2),
    CONSTRAINT chk_holding_entity_id CHECK (entity_id IN ('SG','HK','CH')),
    CONSTRAINT chk_holding_currency  CHECK (currency   IN ('SGD','HKD','CHF'))
);

CREATE INDEX IF NOT EXISTS idx_portfolio_client           ON portfolio (client_id);
CREATE INDEX IF NOT EXISTS idx_holding_portfolio          ON holding   (portfolio_id);
CREATE INDEX IF NOT EXISTS idx_client_entity             ON client    (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_entity          ON portfolio (entity_id, portfolio_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_entity_client   ON portfolio (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_holding_entity            ON holding   (entity_id, holding_id);
CREATE INDEX IF NOT EXISTS idx_holding_entity_portfolio  ON holding   (entity_id, portfolio_id);
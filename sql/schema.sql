-- Wealth Platform PostgreSQL schema — Multi-entity deployment.
-- Dialect: PostgreSQL (uses gen_random_uuid(), TIMESTAMPTZ, CHECK constraints).
-- Every business table is partitioned logically by entity_id CHAR(2).
-- SG baseline behaviour is preserved: all defaults match original SG values.

CREATE TABLE client (
    client_id         UUID         NOT NULL DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)      NOT NULL DEFAULT 'SG',
    full_name         VARCHAR(200) NOT NULL,
    residency_region  VARCHAR(20)  NOT NULL DEFAULT 'ap-southeast-1',
    language          VARCHAR(10)  NOT NULL DEFAULT 'en',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    PRIMARY KEY (client_id, entity_id),
    CONSTRAINT chk_client_entity CHECK (entity_id IN ('SG', 'HK', 'CH'))
);

CREATE TABLE portfolio (
    portfolio_id      UUID         NOT NULL DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)      NOT NULL DEFAULT 'SG',
    client_id         UUID         NOT NULL,
    base_currency     CHAR(3)      NOT NULL DEFAULT 'SGD',
    booking_centre    VARCHAR(50)  NOT NULL DEFAULT 'Singapore',
    mgmt_fee_bps      INTEGER      NOT NULL DEFAULT 50,
    market_value      NUMERIC(18, 2),
    PRIMARY KEY (portfolio_id, entity_id),
    CONSTRAINT chk_portfolio_entity CHECK (entity_id IN ('SG', 'HK', 'CH')),
    CONSTRAINT fk_portfolio_client
        FOREIGN KEY (client_id, entity_id)
        REFERENCES client (client_id, entity_id)
);

CREATE TABLE holding (
    holding_id        UUID         NOT NULL DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)      NOT NULL DEFAULT 'SG',
    portfolio_id      UUID         NOT NULL,
    instrument        VARCHAR(50)  NOT NULL,
    currency          CHAR(3)      NOT NULL DEFAULT 'SGD',
    quantity          NUMERIC(18, 6) NOT NULL,
    market_value      NUMERIC(18, 2),
    PRIMARY KEY (holding_id, entity_id),
    CONSTRAINT chk_holding_entity CHECK (entity_id IN ('SG', 'HK', 'CH')),
    CONSTRAINT fk_holding_portfolio
        FOREIGN KEY (portfolio_id, entity_id)
        REFERENCES portfolio (portfolio_id, entity_id)
);

-- Composite indexes for entity-scoped queries
CREATE INDEX idx_client_entity ON client (entity_id, client_id);
CREATE INDEX idx_portfolio_entity_client ON portfolio (entity_id, client_id);
CREATE INDEX idx_holding_entity_portfolio ON holding (entity_id, portfolio_id);

-- Entity configuration reference table (canonical values)
CREATE TABLE entity_config (
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
    CONSTRAINT chk_entity_config_id CHECK (entity_id IN ('SG', 'HK', 'CH'))
);

INSERT INTO entity_config
    (entity_id, currency, locale, regulator, booking_centre, fee_bps,
     large_position_threshold, suitability_framework, kms_vault_name)
VALUES
    ('SG', 'SGD', 'en_SG', 'MAS', 'Singapore',  50,   250000, 'MAS_FAA_2002',     'wealth-sg'),
    ('HK', 'HKD', 'en_HK', 'SFC', 'Hong Kong',  60,  1000000, 'SFC_COP_2019',     'wealth-hk'),
    ('CH', 'CHF', 'de_CH', 'FINMA','Zurich',     80,  5000000, 'FINMA_LSFin_2020', 'wealth-ch');
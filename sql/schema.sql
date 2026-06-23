-- Wealth Platform PostgreSQL schema — entity-aware deployment.
-- Every table now carries a mandatory entity_id column to enforce
-- data segregation across entities (SG, HK, CH, etc.).
-- Default values have been removed; the application/entity config
-- supplies all entity-specific values at INSERT time.

CREATE TABLE client (
    client_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         VARCHAR(10)  NOT NULL,
    full_name         VARCHAR(200) NOT NULL,
    residency_region  VARCHAR(50)  NOT NULL,
    language          VARCHAR(10)  NOT NULL DEFAULT 'en',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE portfolio (
    portfolio_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         VARCHAR(10)  NOT NULL,
    client_id         UUID NOT NULL REFERENCES client (client_id),
    base_currency     CHAR(3)      NOT NULL,
    booking_centre    VARCHAR(50)  NOT NULL,
    mgmt_fee_bps      INTEGER      NOT NULL,
    market_value      NUMERIC(18, 2)
);

CREATE TABLE holding (
    holding_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         VARCHAR(10)  NOT NULL,
    portfolio_id      UUID NOT NULL REFERENCES portfolio (portfolio_id),
    instrument        VARCHAR(50)  NOT NULL,
    currency          CHAR(3)      NOT NULL,
    quantity          NUMERIC(18, 6) NOT NULL,
    market_value      NUMERIC(18, 2)
);

CREATE INDEX idx_client_entity ON client (entity_id);
CREATE INDEX idx_portfolio_client ON portfolio (client_id);
CREATE INDEX idx_portfolio_entity ON portfolio (entity_id);
CREATE INDEX idx_holding_portfolio ON holding (portfolio_id);
CREATE INDEX idx_holding_entity ON holding (entity_id);
-- Wealth Platform PostgreSQL schema \u2014 multi-entity deployment.
-- entity_id column on every business table; defaults to 'SG' for backward
-- compatibility with the Singapore baseline.

CREATE TABLE client (
    client_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         VARCHAR(10)  NOT NULL DEFAULT 'SG',
    full_name         VARCHAR(200) NOT NULL,
    residency_region  VARCHAR(50)  NOT NULL DEFAULT 'azure-southeast-asia',
    language          VARCHAR(10)  NOT NULL DEFAULT 'en_SG',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE portfolio (
    portfolio_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         VARCHAR(10)  NOT NULL DEFAULT 'SG',
    client_id         UUID NOT NULL REFERENCES client (client_id),
    base_currency     CHAR(3)      NOT NULL DEFAULT 'SGD',
    booking_centre    VARCHAR(50)  NOT NULL DEFAULT 'Singapore',
    mgmt_fee_bps      INTEGER      NOT NULL DEFAULT 50,
    market_value      NUMERIC(18, 2)
);

CREATE TABLE holding (
    holding_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         VARCHAR(10)  NOT NULL DEFAULT 'SG',
    portfolio_id      UUID NOT NULL REFERENCES portfolio (portfolio_id),
    instrument        VARCHAR(50)  NOT NULL,
    currency          CHAR(3)      NOT NULL DEFAULT 'SGD',
    quantity          NUMERIC(18, 6) NOT NULL,
    market_value      NUMERIC(18, 2)
);

CREATE INDEX idx_portfolio_client ON portfolio (client_id);
CREATE INDEX idx_holding_portfolio ON holding (portfolio_id);
CREATE INDEX idx_client_entity ON client (entity_id);
CREATE INDEX idx_portfolio_entity ON portfolio (entity_id);
CREATE INDEX idx_holding_entity ON holding (entity_id);
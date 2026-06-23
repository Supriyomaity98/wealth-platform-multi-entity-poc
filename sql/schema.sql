-- Wealth Platform PostgreSQL schema — Singapore baseline deployment.
-- There is no entity_id column on any table. Single-entity defaults (SGD,
-- Singapore booking centre, 50 bps) are intentional refactoring targets
-- for the multi-agent workflow that will add entity-aware configuration.

CREATE TABLE client (
    client_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name         VARCHAR(200) NOT NULL,
    residency_region  VARCHAR(20)  NOT NULL DEFAULT 'ap-southeast-1',
    language          VARCHAR(10)  NOT NULL DEFAULT 'en',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE portfolio (
    portfolio_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id         UUID NOT NULL REFERENCES client (client_id),
    base_currency     CHAR(3)      NOT NULL DEFAULT 'SGD',
    booking_centre    VARCHAR(50)  NOT NULL DEFAULT 'Singapore',
    mgmt_fee_bps      INTEGER      NOT NULL DEFAULT 50,
    market_value      NUMERIC(18, 2)
);

CREATE TABLE holding (
    holding_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    portfolio_id      UUID NOT NULL REFERENCES portfolio (portfolio_id),
    instrument        VARCHAR(50)  NOT NULL,
    currency          CHAR(3)      NOT NULL DEFAULT 'SGD',
    quantity          NUMERIC(18, 6) NOT NULL,
    market_value      NUMERIC(18, 2)
);

CREATE INDEX idx_portfolio_client ON portfolio (client_id);
CREATE INDEX idx_holding_portfolio ON holding (portfolio_id);

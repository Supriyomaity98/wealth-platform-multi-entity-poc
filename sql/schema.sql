-- Wealth Platform PostgreSQL schema — multi-entity deployment.
-- Dialect: PostgreSQL 14+
-- Entity segregation via entity_id CHAR(2) on every business table.
-- Canonical entities: SG (Singapore), HK (Hong Kong), CH (Switzerland).
-- SG baseline defaults preserved exactly.

CREATE TABLE IF NOT EXISTS client (
    client_id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)     NOT NULL DEFAULT 'SG'
                                  CHECK (entity_id IN ('SG','HK','CH')),
    full_name         VARCHAR(200) NOT NULL,
    residency_region  VARCHAR(20)  NOT NULL DEFAULT 'ap-southeast-1',
    language          VARCHAR(10)  NOT NULL DEFAULT 'en',
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS portfolio (
    portfolio_id      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)     NOT NULL DEFAULT 'SG'
                                  CHECK (entity_id IN ('SG','HK','CH')),
    client_id         UUID        NOT NULL REFERENCES client (client_id),
    base_currency     CHAR(3)     NOT NULL DEFAULT 'SGD',
    booking_centre    VARCHAR(50) NOT NULL DEFAULT 'Singapore',
    mgmt_fee_bps      INTEGER     NOT NULL DEFAULT 50,
    market_value      NUMERIC(18, 2)
);

CREATE TABLE IF NOT EXISTS holding (
    holding_id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)     NOT NULL DEFAULT 'SG'
                                  CHECK (entity_id IN ('SG','HK','CH')),
    portfolio_id      UUID        NOT NULL REFERENCES portfolio (portfolio_id),
    instrument        VARCHAR(50) NOT NULL,
    currency          CHAR(3)     NOT NULL DEFAULT 'SGD',
    quantity          NUMERIC(18, 6) NOT NULL,
    market_value      NUMERIC(18, 2)
);

CREATE TABLE IF NOT EXISTS transaction (
    transaction_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)     NOT NULL DEFAULT 'SG'
                                  CHECK (entity_id IN ('SG','HK','CH')),
    portfolio_id      UUID        NOT NULL REFERENCES portfolio (portfolio_id),
    trade_date        DATE        NOT NULL,
    settle_date       DATE,
    instrument        VARCHAR(50) NOT NULL,
    quantity          NUMERIC(18, 6) NOT NULL,
    price             NUMERIC(18, 6) NOT NULL,
    currency          CHAR(3)     NOT NULL DEFAULT 'SGD',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fee (
    fee_id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         CHAR(2)     NOT NULL DEFAULT 'SG'
                                  CHECK (entity_id IN ('SG','HK','CH')),
    portfolio_id      UUID        NOT NULL REFERENCES portfolio (portfolio_id),
    fee_bps           INTEGER     NOT NULL DEFAULT 50,
    fee_amount        NUMERIC(18, 2) NOT NULL,
    accrual_date      DATE        NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Base indexes (single-column, pre-existing pattern)
CREATE INDEX IF NOT EXISTS idx_portfolio_client      ON portfolio    (client_id);
CREATE INDEX IF NOT EXISTS idx_holding_portfolio     ON holding      (portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transaction_portfolio ON transaction  (portfolio_id);
CREATE INDEX IF NOT EXISTS idx_fee_portfolio         ON fee          (portfolio_id);

-- Composite entity_id indexes for multi-entity query performance
CREATE INDEX IF NOT EXISTS idx_client_entity_id           ON client      (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_entity_client    ON portfolio   (entity_id, client_id);
CREATE INDEX IF NOT EXISTS idx_holding_entity_portfolio   ON holding     (entity_id, portfolio_id);
CREATE INDEX IF NOT EXISTS idx_transaction_entity_portf   ON transaction (entity_id, portfolio_id);
CREATE INDEX IF NOT EXISTS idx_fee_entity_portfolio       ON fee         (entity_id, portfolio_id);
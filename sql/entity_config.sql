-- Entity reference / lookup table.
-- Dialect: PostgreSQL 14+
-- Source of truth for canonical per-entity values aligned with shared contract.
-- All application layers (Java, Python, COBOL) must treat this table
-- as the canonical registry; do NOT duplicate these constants in code.

CREATE TABLE IF NOT EXISTS entity_config (
    entity_id                    CHAR(2)      PRIMARY KEY
                                              CHECK (entity_id IN ('SG','HK','CH')),
    currency                     CHAR(3)      NOT NULL,
    default_locale               VARCHAR(10)  NOT NULL,
    regulator                    VARCHAR(30)  NOT NULL,
    booking_centre               VARCHAR(50)  NOT NULL,
    advisory_fee_bps             INTEGER      NOT NULL,
    large_position_threshold     NUMERIC(18,2) NOT NULL,
    suitability_framework        VARCHAR(40)  NOT NULL,
    azure_region                 VARCHAR(40)  NOT NULL,
    -- Key Vault URI stored as a reference template; never store secrets inline.
    -- Pattern: ${KEYVAULT:wealth-<entity_id>-<secret-name>}
    kv_vault_uri_template        VARCHAR(100) NOT NULL,
    updated_at                   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Idempotent seed: INSERT ... ON CONFLICT DO UPDATE
INSERT INTO entity_config
    (entity_id, currency, default_locale, regulator, booking_centre,
     advisory_fee_bps, large_position_threshold, suitability_framework,
     azure_region, kv_vault_uri_template)
VALUES
    ('SG', 'SGD', 'en_SG', 'MAS',   'Singapore',  50,  250000.00,
     'MAS_FAA_2002',    'ap-southeast-1',
     '${KEYVAULT:wealth-sg-<secret-name>}'),

    ('HK', 'HKD', 'en_HK', 'SFC',   'Hong Kong',  60, 1000000.00,
     'SFC_COP_2019',    'ap-east-1',
     '${KEYVAULT:wealth-hk-<secret-name>}'),

    ('CH', 'CHF', 'de_CH', 'FINMA', 'Zurich',      80, 5000000.00,
     'FINMA_LSFin_2020','eu-west-1',
     '${KEYVAULT:wealth-ch-<secret-name>}')
ON CONFLICT (entity_id) DO UPDATE SET
    currency                 = EXCLUDED.currency,
    default_locale           = EXCLUDED.default_locale,
    regulator                = EXCLUDED.regulator,
    booking_centre           = EXCLUDED.booking_centre,
    advisory_fee_bps         = EXCLUDED.advisory_fee_bps,
    large_position_threshold = EXCLUDED.large_position_threshold,
    suitability_framework    = EXCLUDED.suitability_framework,
    azure_region             = EXCLUDED.azure_region,
    kv_vault_uri_template    = EXCLUDED.kv_vault_uri_template,
    updated_at               = now();
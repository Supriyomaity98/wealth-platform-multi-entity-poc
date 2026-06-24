-- verify_v2_entity_id.sql
-- Executable assertion script for WP-SQL refactor/sql-entity-context
-- Dialect: PostgreSQL 14+
-- Run via: psql -v ON_ERROR_STOP=1 -f verify_v2_entity_id.sql

\set ON_ERROR_STOP on

-- TEST 1: SG baseline canonical values
DO $$
DECLARE r entity_config%ROWTYPE;
BEGIN
    SELECT * INTO STRICT r FROM entity_config WHERE entity_id = 'SG';
    ASSERT r.currency                 = 'SGD',           'SG currency mismatch';
    ASSERT r.locale                   = 'en_SG',         'SG locale mismatch';
    ASSERT r.regulator                = 'MAS',            'SG regulator mismatch';
    ASSERT r.booking_centre           = 'Singapore',      'SG booking_centre mismatch';
    ASSERT r.fee_bps                  = 50,               'SG fee_bps mismatch';
    ASSERT r.large_position_threshold = 250000,           'SG large_position_threshold mismatch';
    ASSERT r.suitability_framework    = 'MAS_FAA_2002',  'SG suitability_framework mismatch';
    ASSERT r.kms_vault_name           = 'wealth-sg',     'SG kms_vault_name mismatch';
    RAISE NOTICE 'TEST 1 PASS: SG baseline canonical values';
END $$;

-- TEST 2: HK canonical values
DO $$
DECLARE r entity_config%ROWTYPE;
BEGIN
    SELECT * INTO STRICT r FROM entity_config WHERE entity_id = 'HK';
    ASSERT r.currency                 = 'HKD',           'HK currency mismatch';
    ASSERT r.locale                   = 'en_HK',         'HK locale mismatch';
    ASSERT r.regulator                = 'SFC',            'HK regulator mismatch';
    ASSERT r.booking_centre           = 'Hong Kong',      'HK booking_centre mismatch';
    ASSERT r.fee_bps                  = 60,               'HK fee_bps mismatch';
    ASSERT r.large_position_threshold = 1000000,          'HK large_position_threshold mismatch';
    ASSERT r.suitability_framework    = 'SFC_COP_2019',  'HK suitability_framework mismatch';
    ASSERT r.kms_vault_name           = 'wealth-hk',     'HK kms_vault_name mismatch';
    RAISE NOTICE 'TEST 2 PASS: HK canonical values';
END $$;

-- TEST 3: CH canonical values
DO $$
DECLARE r entity_config%ROWTYPE;
BEGIN
    SELECT * INTO STRICT r FROM entity_config WHERE entity_id = 'CH';
    ASSERT r.currency                 = 'CHF',                'CH currency mismatch';
    ASSERT r.locale                   = 'de_CH',              'CH locale mismatch';
    ASSERT r.regulator                = 'FINMA',              'CH regulator mismatch';
    ASSERT r.booking_centre           = 'Zurich',             'CH booking_centre mismatch';
    ASSERT r.fee_bps                  = 80,                   'CH fee_bps mismatch';
    ASSERT r.large_position_threshold = 5000000,              'CH large_position_threshold mismatch';
    ASSERT r.suitability_framework    = 'FINMA_LSFin_2020',  'CH suitability_framework mismatch';
    ASSERT r.kms_vault_name           = 'wealth-ch',          'CH kms_vault_name mismatch';
    RAISE NOTICE 'TEST 3 PASS: CH canonical values';
END $$;

-- TEST 4: entity_id column exists, is CHAR(2), NOT NULL, DEFAULT SG on all 3 business tables
DO $$
DECLARE col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_schema            = 'public'
      AND table_name              IN ('client','portfolio','holding')
      AND column_name             = 'entity_id'
      AND data_type               = 'character'
      AND character_maximum_length = 2
      AND column_default          LIKE '%SG%'
      AND is_nullable             = 'NO';
    ASSERT col_count = 3,
        FORMAT('entity_id column missing/misconfigured on business tables; found %s/3', col_count);
    RAISE NOTICE 'TEST 4 PASS: entity_id column present, CHAR(2), NOT NULL, DEFAULT SG on all 3 tables';
END $$;

-- TEST 5: CHECK constraint rejects invalid entity_id value
DO $$
BEGIN
    BEGIN
        INSERT INTO entity_config
            (entity_id, currency, locale, regulator, booking_centre,
             fee_bps, large_position_threshold, suitability_framework, kms_vault_name)
        VALUES
            ('XX','USD','en_US','SEC','New York',10,100000,'SEC_TEST','vault-xx');
        RAISE EXCEPTION 'TEST 5 FAIL: CHECK constraint did not reject entity_id=XX';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'TEST 5 PASS: CHECK constraint correctly rejected entity_id=XX';
    END;
END $$;

-- TEST 6: V2 backfill — zero rows with null or invalid entity_id across all business tables
DO $$
DECLARE orphan_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO orphan_count FROM client
    WHERE entity_id IS NULL OR entity_id NOT IN ('SG','HK','CH');
    ASSERT orphan_count = 0,
        FORMAT('TEST 6 FAIL: %s client rows have null/invalid entity_id after V2 backfill', orphan_count);

    SELECT COUNT(*) INTO orphan_count FROM portfolio
    WHERE entity_id IS NULL OR entity_id NOT IN ('SG','HK','CH');
    ASSERT orphan_count = 0,
        FORMAT('TEST 6 FAIL: %s portfolio rows have null/invalid entity_id after V2 backfill', orphan_count);

    SELECT COUNT(*) INTO orphan_count FROM holding
    WHERE entity_id IS NULL OR entity_id NOT IN ('SG','HK','CH');
    ASSERT orphan_count = 0,
        FORMAT('TEST 6 FAIL: %s holding rows have null/invalid entity_id after V2 backfill', orphan_count);

    RAISE NOTICE 'TEST 6 PASS: all business table rows have valid entity_id after V2 backfill';
END $$;

\echo '====== ALL 6 WP-SQL ENTITY_ID ASSERTIONS PASSED ======'
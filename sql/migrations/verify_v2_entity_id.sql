-- sql/migrations/verify_v2_entity_id.sql
-- Executable assertion script for V2 migration (entity_id refactor)
-- Run against PostgreSQL 14+ after applying V2__add_entity_id.sql
-- Each DO block ASSERTs; any failure raises EXCEPTION and aborts.
-- Usage: psql -v ON_ERROR_STOP=1 -f verify_v2_entity_id.sql

\set VERBOSITY verbose

-- ============================================================
-- TEST 1 (SG Baseline): entity_config row for SG matches EXACT canonical values
-- ============================================================
DO $$
DECLARE
    r entity_config%ROWTYPE;
BEGIN
    SELECT * INTO STRICT r FROM entity_config WHERE entity_id = 'SG';
    ASSERT r.currency_code            = 'SGD',           'FAIL T1: SG currency_code != SGD got ' || r.currency_code;
    ASSERT r.default_locale           = 'en_SG',         'FAIL T1: SG locale != en_SG got ' || r.default_locale;
    ASSERT r.primary_regulator        = 'MAS',           'FAIL T1: SG regulator != MAS got ' || r.primary_regulator;
    ASSERT r.booking_centre           = 'Singapore',     'FAIL T1: SG booking_centre != Singapore';
    ASSERT r.fee_bps                  = 50,              'FAIL T1: SG fee_bps != 50 got ' || r.fee_bps;
    ASSERT r.large_position_threshold = 250000,          'FAIL T1: SG large_position_threshold != 250000';
    ASSERT r.suitability_framework    = 'MAS_FAA_2002',  'FAIL T1: SG suitability_framework != MAS_FAA_2002';
    ASSERT r.key_vault_name           = 'wealth-sg',     'FAIL T1: SG key_vault_name != wealth-sg';
    RAISE NOTICE 'TEST 1 PASSED: SG baseline entity_config values correct';
END $$;

-- ============================================================
-- TEST 2 (HK Switch): entity_config row for HK matches EXACT canonical values
-- ============================================================
DO $$
DECLARE
    r entity_config%ROWTYPE;
BEGIN
    SELECT * INTO STRICT r FROM entity_config WHERE entity_id = 'HK';
    ASSERT r.currency_code            = 'HKD',           'FAIL T2: HK currency_code != HKD got ' || r.currency_code;
    ASSERT r.default_locale           = 'en_HK',         'FAIL T2: HK locale != en_HK got ' || r.default_locale;
    ASSERT r.primary_regulator        = 'SFC',           'FAIL T2: HK regulator != SFC got ' || r.primary_regulator;
    ASSERT r.booking_centre           = 'Hong Kong',     'FAIL T2: HK booking_centre != Hong Kong';
    ASSERT r.fee_bps                  = 60,              'FAIL T2: HK fee_bps != 60 got ' || r.fee_bps;
    ASSERT r.large_position_threshold = 1000000,         'FAIL T2: HK large_position_threshold != 1000000';
    ASSERT r.suitability_framework    = 'SFC_COP_2019',  'FAIL T2: HK suitability_framework != SFC_COP_2019';
    ASSERT r.key_vault_name           = 'wealth-hk',     'FAIL T2: HK key_vault_name != wealth-hk';
    RAISE NOTICE 'TEST 2 PASSED: HK entity_config values correct';
END $$;

-- ============================================================
-- TEST 3 (CH Switch): entity_config row for CH matches EXACT canonical values
-- ============================================================
DO $$
DECLARE
    r entity_config%ROWTYPE;
BEGIN
    SELECT * INTO STRICT r FROM entity_config WHERE entity_id = 'CH';
    ASSERT r.currency_code            = 'CHF',              'FAIL T3: CH currency_code != CHF got ' || r.currency_code;
    ASSERT r.default_locale           = 'de_CH',            'FAIL T3: CH locale != de_CH got ' || r.default_locale;
    ASSERT r.primary_regulator        = 'FINMA',            'FAIL T3: CH regulator != FINMA got ' || r.primary_regulator;
    ASSERT r.booking_centre           = 'Zurich',           'FAIL T3: CH booking_centre != Zurich';
    ASSERT r.fee_bps                  = 80,                 'FAIL T3: CH fee_bps != 80 got ' || r.fee_bps;
    ASSERT r.large_position_threshold = 5000000,            'FAIL T3: CH large_position_threshold != 5000000';
    ASSERT r.suitability_framework    = 'FINMA_LSFin_2020', 'FAIL T3: CH suitability_framework != FINMA_LSFin_2020';
    ASSERT r.key_vault_name           = 'wealth-ch',        'FAIL T3: CH key_vault_name != wealth-ch';
    RAISE NOTICE 'TEST 3 PASSED: CH entity_config values correct';
END $$;

-- ============================================================
-- TEST 4: entity_id CHAR(2) NOT NULL exists on client, portfolio, holding
-- ============================================================
DO $$
DECLARE
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_schema = current_schema()
      AND table_name   IN ('client','portfolio','holding')
      AND column_name  = 'entity_id'
      AND data_type    = 'character'
      AND character_maximum_length = 2
      AND is_nullable  = 'NO';
    ASSERT col_count = 3,
        'FAIL T4: entity_id CHAR(2) NOT NULL missing; found on ' || col_count || ' of 3 tables';
    RAISE NOTICE 'TEST 4 PASSED: entity_id CHAR(2) NOT NULL present on all 3 business tables';
END $$;

-- ============================================================
-- TEST 5 (SG backfill): all pre-existing rows in business tables have entity_id='SG'
-- ============================================================
DO $$
DECLARE
    non_sg_count BIGINT;
BEGIN
    SELECT (SELECT COUNT(*) FROM client    WHERE entity_id <> 'SG')
         + (SELECT COUNT(*) FROM portfolio WHERE entity_id <> 'SG')
         + (SELECT COUNT(*) FROM holding   WHERE entity_id <> 'SG')
    INTO non_sg_count;
    ASSERT non_sg_count = 0,
        'FAIL T5: ' || non_sg_count || ' rows not backfilled to SG after migration';
    RAISE NOTICE 'TEST 5 PASSED: all existing rows correctly backfilled to entity_id=SG';
END $$;

-- ============================================================
-- TEST 6 (Negative): INSERT with invalid entity_id must raise check_violation
-- ============================================================
DO $$
BEGIN
    BEGIN
        INSERT INTO entity_config
            (entity_id,currency_code,default_locale,fee_bps,
             large_position_threshold,booking_centre,suitability_framework,
             primary_regulator,data_region,key_vault_name)
        VALUES ('XX','XXX','xx_XX',99,1,'Nowhere','NONE','NONE','none','vault-xx');
        ASSERT false, 'FAIL T6: invalid entity_id XX was accepted — CHECK constraint not enforced';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'TEST 6 PASSED: invalid entity_id XX correctly rejected by CHECK constraint';
    END;
END $$;

RAISE NOTICE '=== ALL verify_v2_entity_id TESTS PASSED ===';
-- =============================================================
-- verify_v2_entity_id.sql
-- Assertion script for V2__add_entity_id.sql migration.
-- Each DO block raises EXCEPTION on failure; silent = pass.
-- Run after applying schema.sql + V2 migration.
-- =============================================================

-- TEST 1: SG baseline canonical values in entity table
DO $$
DECLARE
  r entity%ROWTYPE;
BEGIN
  SELECT * INTO STRICT r FROM entity WHERE entity_id = 'SG';
  ASSERT r.currency               = 'SGD',            'SG currency mismatch';
  ASSERT r.locale                 = 'en_SG',           'SG locale mismatch';
  ASSERT r.regulator              = 'MAS',             'SG regulator mismatch';
  ASSERT r.booking_centre         = 'Singapore',       'SG booking_centre mismatch';
  ASSERT r.fee_bps                = 50,                'SG fee_bps mismatch';
  ASSERT r.large_position_threshold = 250000,          'SG large_position_threshold mismatch';
  ASSERT r.suitability_framework  = 'MAS_FAA_2002',   'SG suitability_framework mismatch';
  ASSERT r.kms_vault_name         = 'wealth-sg',       'SG kms_vault_name mismatch';
  RAISE NOTICE 'TEST 1 PASSED: SG canonical values correct';
EXCEPTION WHEN no_data_found THEN
  RAISE EXCEPTION 'TEST 1 FAILED: SG row missing from entity table';
END;
$$;

-- TEST 2: HK canonical values
DO $$
DECLARE
  r entity%ROWTYPE;
BEGIN
  SELECT * INTO STRICT r FROM entity WHERE entity_id = 'HK';
  ASSERT r.currency               = 'HKD',            'HK currency mismatch';
  ASSERT r.locale                 = 'en_HK',           'HK locale mismatch';
  ASSERT r.regulator              = 'SFC',             'HK regulator mismatch';
  ASSERT r.booking_centre         = 'Hong Kong',       'HK booking_centre mismatch';
  ASSERT r.fee_bps                = 60,                'HK fee_bps mismatch';
  ASSERT r.large_position_threshold = 1000000,         'HK large_position_threshold mismatch';
  ASSERT r.suitability_framework  = 'SFC_COP_2019',   'HK suitability_framework mismatch';
  ASSERT r.kms_vault_name         = 'wealth-hk',       'HK kms_vault_name mismatch';
  RAISE NOTICE 'TEST 2 PASSED: HK canonical values correct';
EXCEPTION WHEN no_data_found THEN
  RAISE EXCEPTION 'TEST 2 FAILED: HK row missing from entity table';
END;
$$;

-- TEST 3: CH canonical values
DO $$
DECLARE
  r entity%ROWTYPE;
BEGIN
  SELECT * INTO STRICT r FROM entity WHERE entity_id = 'CH';
  ASSERT r.currency               = 'CHF',             'CH currency mismatch';
  ASSERT r.locale                 = 'de_CH',           'CH locale mismatch';
  ASSERT r.regulator              = 'FINMA',           'CH regulator mismatch';
  ASSERT r.booking_centre         = 'Zurich',          'CH booking_centre mismatch';
  ASSERT r.fee_bps                = 80,                'CH fee_bps mismatch';
  ASSERT r.large_position_threshold = 5000000,         'CH large_position_threshold mismatch';
  ASSERT r.suitability_framework  = 'FINMA_LSFin_2020','CH suitability_framework mismatch';
  ASSERT r.kms_vault_name         = 'wealth-ch',       'CH kms_vault_name mismatch';
  RAISE NOTICE 'TEST 3 PASSED: CH canonical values correct';
EXCEPTION WHEN no_data_found THEN
  RAISE EXCEPTION 'TEST 3 FAILED: CH row missing from entity table';
END;
$$;

-- TEST 4: entity_id column exists on all three business tables
DO $$
DECLARE
  col_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO col_count
  FROM information_schema.columns
  WHERE table_schema = current_schema()
    AND table_name IN ('client','portfolio','holding')
    AND column_name = 'entity_id'
    AND data_type = 'character'
    AND character_maximum_length = 2
    AND is_nullable = 'NO';
  ASSERT col_count = 3,
    'TEST 4 FAILED: entity_id CHAR(2) NOT NULL missing from one or more business tables (found ' || col_count || '/3)';
  RAISE NOTICE 'TEST 4 PASSED: entity_id column present on all business tables';
END;
$$;

-- TEST 5: CHECK constraint rejects invalid entity_id values
DO $$
BEGIN
  -- Attempt insert of invalid entity into entity table itself
  BEGIN
    INSERT INTO entity (entity_id, entity_name, currency, locale, regulator,
      booking_centre, fee_bps, large_position_threshold,
      suitability_framework, kms_vault_name)
    VALUES ('XX','Bad','USD','en_US','SEC','New York',0,0,'NONE','none');
    RAISE EXCEPTION 'TEST 5 FAILED: CHECK constraint did not reject invalid entity_id XX';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST 5 PASSED: CHECK constraint correctly rejects invalid entity_id';
  END;
END;
$$;

-- TEST 6: All existing rows in business tables are backfilled to SG
DO $$
DECLARE
  non_sg_clients    INTEGER;
  non_sg_portfolios INTEGER;
  non_sg_holdings   INTEGER;
BEGIN
  SELECT COUNT(*) INTO non_sg_clients    FROM client    WHERE entity_id != 'SG';
  SELECT COUNT(*) INTO non_sg_portfolios FROM portfolio WHERE entity_id != 'SG';
  SELECT COUNT(*) INTO non_sg_holdings   FROM holding   WHERE entity_id != 'SG';
  ASSERT non_sg_clients    = 0,
    'TEST 6 FAILED: ' || non_sg_clients || ' client rows not backfilled to SG';
  ASSERT non_sg_portfolios = 0,
    'TEST 6 FAILED: ' || non_sg_portfolios || ' portfolio rows not backfilled to SG';
  ASSERT non_sg_holdings   = 0,
    'TEST 6 FAILED: ' || non_sg_holdings || ' holding rows not backfilled to SG';
  RAISE NOTICE 'TEST 6 PASSED: All existing rows backfilled to entity_id=SG';
END;
$$;

-- Cross-entity differ: confirm SG/HK/CH all differ on fee_bps
DO $$
DECLARE
  sg_fee INTEGER;
  hk_fee INTEGER;
  ch_fee INTEGER;
BEGIN
  SELECT fee_bps INTO sg_fee FROM entity WHERE entity_id = 'SG';
  SELECT fee_bps INTO hk_fee FROM entity WHERE entity_id = 'HK';
  SELECT fee_bps INTO ch_fee FROM entity WHERE entity_id = 'CH';
  ASSERT sg_fee != hk_fee AND hk_fee != ch_fee AND sg_fee != ch_fee,
    'DIFFER CHECK FAILED: fee_bps values are not distinct across entities';
  RAISE NOTICE 'DIFFER CHECK PASSED: SG=%, HK=%, CH=% fee_bps all distinct', sg_fee, hk_fee, ch_fee;
END;
$$;

-- Summary
SELECT 'ALL ASSERTIONS PASSED — V2 migration verified' AS result;
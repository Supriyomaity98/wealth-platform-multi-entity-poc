-- =============================================================================
-- verify_v2_entity_id.sql — QA assertion script for V2 migration & schema.sql
-- Run against the target PostgreSQL 14+ database AFTER applying schema.sql
-- and V2__add_entity_id.sql. Every DO block raises an EXCEPTION on failure.
-- =============================================================================

-- ============================================================
-- TEST 1: assert entity_id column exists on all business tables
-- ============================================================
DO $$
DECLARE
  _tbl TEXT;
  _missing TEXT := '';
BEGIN
  FOR _tbl IN SELECT unnest(ARRAY['client','portfolio','holding','transaction','fee'])
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name   = _tbl
         AND column_name  = 'entity_id'
         AND data_type    = 'character'
         AND character_maximum_length = 2
    ) THEN
      _missing := _missing || _tbl || ' ';
    END IF;
  END LOOP;
  IF _missing <> '' THEN
    RAISE EXCEPTION 'TEST 1 FAIL: entity_id column missing or wrong type on: %', _missing;
  END IF;
  RAISE NOTICE 'TEST 1 PASS: entity_id CHAR(2) exists on all 5 business tables';
END $$;

-- ============================================================
-- TEST 2: assert CHECK constraint allows only SG, HK, CH
-- ============================================================
DO $$
BEGIN
  -- Attempt to insert an invalid entity_id into client; must fail.
  BEGIN
    INSERT INTO client (entity_id, full_name) VALUES ('XX', 'Bad Entity Test');
    -- If we reach here, constraint is missing
    RAISE EXCEPTION 'TEST 2 FAIL: INSERT with entity_id=XX should have been rejected on client';
  EXCEPTION
    WHEN check_violation THEN
      RAISE NOTICE 'TEST 2a PASS: client rejects invalid entity_id XX';
  END;

  -- Verify valid entities are accepted
  BEGIN
    INSERT INTO client (entity_id, full_name) VALUES ('HK', 'HK Test Client');
    INSERT INTO client (entity_id, full_name) VALUES ('CH', 'CH Test Client');
    RAISE NOTICE 'TEST 2b PASS: client accepts HK and CH entity_id values';
    -- Cleanup
    DELETE FROM client WHERE full_name IN ('HK Test Client','CH Test Client');
  END;
END $$;

-- ============================================================
-- TEST 3: assert existing rows are backfilled to SG
-- ============================================================
DO $$
DECLARE
  _tbl TEXT;
  _cnt BIGINT;
BEGIN
  FOR _tbl IN SELECT unnest(ARRAY['client','portfolio','holding','transaction','fee'])
  LOOP
    EXECUTE format(
      'SELECT count(*) FROM %I WHERE entity_id IS NULL OR entity_id <> ''SG''',
      _tbl
    ) INTO _cnt;
    -- After backfill, no pre-existing row should have entity_id != 'SG'
    -- (ignoring rows we may have just inserted in test 2 — they were deleted)
    IF _cnt > 0 THEN
      RAISE EXCEPTION 'TEST 3 FAIL: table % has % rows with entity_id <> SG', _tbl, _cnt;
    END IF;
  END LOOP;
  RAISE NOTICE 'TEST 3 PASS: all existing rows backfilled to SG';
END $$;

-- ============================================================
-- TEST 4: assert entity_config canonical values (SG, HK, CH)
-- ============================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  -- SG assertions
  SELECT * INTO r FROM entity_config WHERE entity_id = 'SG';
  IF NOT FOUND THEN RAISE EXCEPTION 'TEST 4 FAIL: SG row missing from entity_config'; END IF;
  IF r.base_currency        <> 'SGD'               THEN RAISE EXCEPTION 'TEST 4 FAIL: SG currency expected SGD got %', r.base_currency; END IF;
  IF r.locale               <> 'en_SG'             THEN RAISE EXCEPTION 'TEST 4 FAIL: SG locale expected en_SG got %', r.locale; END IF;
  IF r.regulator            <> 'MAS'               THEN RAISE EXCEPTION 'TEST 4 FAIL: SG regulator expected MAS got %', r.regulator; END IF;
  IF r.booking_centre       <> 'Singapore'          THEN RAISE EXCEPTION 'TEST 4 FAIL: SG booking_centre expected Singapore got %', r.booking_centre; END IF;
  IF r.fee_bps              <> 50                   THEN RAISE EXCEPTION 'TEST 4 FAIL: SG fee_bps expected 50 got %', r.fee_bps; END IF;
  IF r.large_position_threshold <> 250000           THEN RAISE EXCEPTION 'TEST 4 FAIL: SG threshold expected 250000 got %', r.large_position_threshold; END IF;
  IF r.suitability_framework <> 'MAS_FAA_2002'     THEN RAISE EXCEPTION 'TEST 4 FAIL: SG framework expected MAS_FAA_2002 got %', r.suitability_framework; END IF;

  -- HK assertions
  SELECT * INTO r FROM entity_config WHERE entity_id = 'HK';
  IF NOT FOUND THEN RAISE EXCEPTION 'TEST 4 FAIL: HK row missing from entity_config'; END IF;
  IF r.base_currency        <> 'HKD'               THEN RAISE EXCEPTION 'TEST 4 FAIL: HK currency expected HKD got %', r.base_currency; END IF;
  IF r.locale               <> 'en_HK'             THEN RAISE EXCEPTION 'TEST 4 FAIL: HK locale expected en_HK got %', r.locale; END IF;
  IF r.regulator            <> 'SFC'               THEN RAISE EXCEPTION 'TEST 4 FAIL: HK regulator expected SFC got %', r.regulator; END IF;
  IF r.booking_centre       <> 'Hong Kong'          THEN RAISE EXCEPTION 'TEST 4 FAIL: HK booking_centre expected Hong Kong got %', r.booking_centre; END IF;
  IF r.fee_bps              <> 60                   THEN RAISE EXCEPTION 'TEST 4 FAIL: HK fee_bps expected 60 got %', r.fee_bps; END IF;
  IF r.large_position_threshold <> 1000000          THEN RAISE EXCEPTION 'TEST 4 FAIL: HK threshold expected 1000000 got %', r.large_position_threshold; END IF;
  IF r.suitability_framework <> 'SFC_COP_2019'     THEN RAISE EXCEPTION 'TEST 4 FAIL: HK framework expected SFC_COP_2019 got %', r.suitability_framework; END IF;

  -- CH assertions
  SELECT * INTO r FROM entity_config WHERE entity_id = 'CH';
  IF NOT FOUND THEN RAISE EXCEPTION 'TEST 4 FAIL: CH row missing from entity_config'; END IF;
  IF r.base_currency        <> 'CHF'               THEN RAISE EXCEPTION 'TEST 4 FAIL: CH currency expected CHF got %', r.base_currency; END IF;
  IF r.locale               <> 'de_CH'             THEN RAISE EXCEPTION 'TEST 4 FAIL: CH locale expected de_CH got %', r.locale; END IF;
  IF r.regulator            <> 'FINMA'             THEN RAISE EXCEPTION 'TEST 4 FAIL: CH regulator expected FINMA got %', r.regulator; END IF;
  IF r.booking_centre       <> 'Zurich'            THEN RAISE EXCEPTION 'TEST 4 FAIL: CH booking_centre expected Zurich got %', r.booking_centre; END IF;
  IF r.fee_bps              <> 80                   THEN RAISE EXCEPTION 'TEST 4 FAIL: CH fee_bps expected 80 got %', r.fee_bps; END IF;
  IF r.large_position_threshold <> 5000000          THEN RAISE EXCEPTION 'TEST 4 FAIL: CH threshold expected 5000000 got %', r.large_position_threshold; END IF;
  IF r.suitability_framework <> 'FINMA_LSFin_2020' THEN RAISE EXCEPTION 'TEST 4 FAIL: CH framework expected FINMA_LSFin_2020 got %', r.suitability_framework; END IF;

  RAISE NOTICE 'TEST 4 PASS: all entity_config canonical values match spec';
END $$;

-- ============================================================
-- TEST 5: assert composite indexes exist on all business tables
-- ============================================================
DO $$
DECLARE
  _tbl TEXT;
  _found BOOLEAN;
BEGIN
  FOR _tbl IN SELECT unnest(ARRAY['client','portfolio','holding','transaction','fee'])
  LOOP
    SELECT EXISTS (
      SELECT 1
        FROM pg_indexes
       WHERE schemaname = 'public'
         AND tablename  = _tbl
         AND indexdef ILIKE '%entity_id%'
    ) INTO _found;
    IF NOT _found THEN
      RAISE EXCEPTION 'TEST 5 FAIL: no composite index containing entity_id on table %', _tbl;
    END IF;
  END LOOP;
  RAISE NOTICE 'TEST 5 PASS: composite entity_id indexes present on all 5 tables';
END $$;

-- ============================================================
-- TEST 6: assert SG default preservation — INSERT without
--         explicit entity_id defaults to SG with SG values
-- ============================================================
DO $$
DECLARE
  _cid UUID;
  _pid UUID;
  _eid CHAR(2);
  _cur CHAR(3);
  _bc  VARCHAR(50);
  _fee INTEGER;
BEGIN
  INSERT INTO client (full_name) VALUES ('SG Default Test')
    RETURNING client_id INTO _cid;
  SELECT entity_id INTO _eid FROM client WHERE client_id = _cid;
  IF _eid <> 'SG' THEN
    RAISE EXCEPTION 'TEST 6 FAIL: client default entity_id expected SG got %', _eid;
  END IF;

  INSERT INTO portfolio (client_id) VALUES (_cid)
    RETURNING portfolio_id INTO _pid;
  SELECT entity_id, base_currency, booking_centre, mgmt_fee_bps
    INTO _eid, _cur, _bc, _fee
    FROM portfolio WHERE portfolio_id = _pid;
  IF _eid <> 'SG'        THEN RAISE EXCEPTION 'TEST 6 FAIL: portfolio default entity_id expected SG got %', _eid; END IF;
  IF _cur <> 'SGD'       THEN RAISE EXCEPTION 'TEST 6 FAIL: portfolio default currency expected SGD got %', _cur; END IF;
  IF _bc  <> 'Singapore' THEN RAISE EXCEPTION 'TEST 6 FAIL: portfolio default booking_centre expected Singapore got %', _bc; END IF;
  IF _fee <> 50          THEN RAISE EXCEPTION 'TEST 6 FAIL: portfolio default fee_bps expected 50 got %', _fee; END IF;

  -- Cleanup
  DELETE FROM portfolio WHERE portfolio_id = _pid;
  DELETE FROM client WHERE client_id = _cid;

  RAISE NOTICE 'TEST 6 PASS: SG defaults preserved — INSERT without entity_id yields SG/SGD/Singapore/50bps';
END $$;

-- ============================================================
SELECT 'ALL 6 TESTS PASSED' AS verification_result;
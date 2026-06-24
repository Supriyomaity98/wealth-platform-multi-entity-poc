-- =============================================================
-- verify_v2_entity_id.sql
-- Assertion script for V2 migration: entity_id column, CHECK
-- constraints, SG backfill, composite PKs/FKs, entity_config.
-- Run with: psql -v ON_ERROR_STOP=1 -f verify_v2_entity_id.sql
-- Every DO block raises EXCEPTION on failure; silence = pass.
-- =============================================================

-- ---------------------------------------------------------------
-- TC-1: entity_id column exists on all three business tables
-- ---------------------------------------------------------------
DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY['client','portfolio','holding'] LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = tbl
              AND column_name = 'entity_id'
              AND data_type = 'character'
              AND character_maximum_length = 2
              AND column_default LIKE '%SG%'
        ) THEN
            RAISE EXCEPTION 'TC-1 FAIL: entity_id column missing or wrong spec on table %', tbl;
        END IF;
    END LOOP;
    RAISE NOTICE 'TC-1 PASS: entity_id column present and correct on all tables';
END $$;

-- ---------------------------------------------------------------
-- TC-2: CHECK constraint rejects invalid entity_id ('XX')
-- ---------------------------------------------------------------
DO $$
BEGIN
    BEGIN
        INSERT INTO client (full_name, entity_id)
        VALUES ('Test Reject', 'XX');
        RAISE EXCEPTION 'TC-2 FAIL: INSERT with entity_id=XX should have been rejected';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'TC-2 PASS: CHECK constraint correctly rejected entity_id=XX';
    END;
END $$;

-- ---------------------------------------------------------------
-- TC-3: All existing rows backfilled to entity_id = SG
-- ---------------------------------------------------------------
DO $$
DECLARE
    bad_count INTEGER;
    tbl       TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY['client','portfolio','holding'] LOOP
        EXECUTE format(
            'SELECT COUNT(*) FROM %I WHERE entity_id <> ''SG''', tbl
        ) INTO bad_count;
        IF bad_count > 0 THEN
            RAISE EXCEPTION 'TC-3 FAIL: % rows in % have entity_id != SG after backfill', bad_count, tbl;
        END IF;
    END LOOP;
    RAISE NOTICE 'TC-3 PASS: All existing rows backfilled to entity_id=SG';
END $$;

-- ---------------------------------------------------------------
-- TC-4: entity_config canonical values for SG, HK, CH
-- ---------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    -- SG
    SELECT * INTO r FROM entity_config WHERE entity_id = 'SG';
    IF r.currency               <> 'SGD'              THEN RAISE EXCEPTION 'TC-4 FAIL SG currency: got %', r.currency; END IF;
    IF r.locale                 <> 'en_SG'            THEN RAISE EXCEPTION 'TC-4 FAIL SG locale: got %', r.locale; END IF;
    IF r.regulator              <> 'MAS'              THEN RAISE EXCEPTION 'TC-4 FAIL SG regulator: got %', r.regulator; END IF;
    IF r.booking_centre         <> 'Singapore'        THEN RAISE EXCEPTION 'TC-4 FAIL SG booking_centre: got %', r.booking_centre; END IF;
    IF r.fee_bps                <> 50                 THEN RAISE EXCEPTION 'TC-4 FAIL SG fee_bps: got %', r.fee_bps; END IF;
    IF r.large_position_threshold <> 250000           THEN RAISE EXCEPTION 'TC-4 FAIL SG large_position_threshold: got %', r.large_position_threshold; END IF;
    IF r.suitability_framework  <> 'MAS_FAA_2002'    THEN RAISE EXCEPTION 'TC-4 FAIL SG suitability_framework: got %', r.suitability_framework; END IF;
    IF r.kms_vault_name         <> 'wealth-sg'       THEN RAISE EXCEPTION 'TC-4 FAIL SG kms_vault_name: got %', r.kms_vault_name; END IF;
    -- HK
    SELECT * INTO r FROM entity_config WHERE entity_id = 'HK';
    IF r.currency               <> 'HKD'              THEN RAISE EXCEPTION 'TC-4 FAIL HK currency: got %', r.currency; END IF;
    IF r.locale                 <> 'en_HK'            THEN RAISE EXCEPTION 'TC-4 FAIL HK locale: got %', r.locale; END IF;
    IF r.regulator              <> 'SFC'              THEN RAISE EXCEPTION 'TC-4 FAIL HK regulator: got %', r.regulator; END IF;
    IF r.booking_centre         <> 'Hong Kong'        THEN RAISE EXCEPTION 'TC-4 FAIL HK booking_centre: got %', r.booking_centre; END IF;
    IF r.fee_bps                <> 60                 THEN RAISE EXCEPTION 'TC-4 FAIL HK fee_bps: got %', r.fee_bps; END IF;
    IF r.large_position_threshold <> 1000000          THEN RAISE EXCEPTION 'TC-4 FAIL HK large_position_threshold: got %', r.large_position_threshold; END IF;
    IF r.suitability_framework  <> 'SFC_COP_2019'    THEN RAISE EXCEPTION 'TC-4 FAIL HK suitability_framework: got %', r.suitability_framework; END IF;
    IF r.kms_vault_name         <> 'wealth-hk'       THEN RAISE EXCEPTION 'TC-4 FAIL HK kms_vault_name: got %', r.kms_vault_name; END IF;
    -- CH
    SELECT * INTO r FROM entity_config WHERE entity_id = 'CH';
    IF r.currency               <> 'CHF'              THEN RAISE EXCEPTION 'TC-4 FAIL CH currency: got %', r.currency; END IF;
    IF r.locale                 <> 'de_CH'            THEN RAISE EXCEPTION 'TC-4 FAIL CH locale: got %', r.locale; END IF;
    IF r.regulator              <> 'FINMA'            THEN RAISE EXCEPTION 'TC-4 FAIL CH regulator: got %', r.regulator; END IF;
    IF r.booking_centre         <> 'Zurich'           THEN RAISE EXCEPTION 'TC-4 FAIL CH booking_centre: got %', r.booking_centre; END IF;
    IF r.fee_bps                <> 80                 THEN RAISE EXCEPTION 'TC-4 FAIL CH fee_bps: got %', r.fee_bps; END IF;
    IF r.large_position_threshold <> 5000000          THEN RAISE EXCEPTION 'TC-4 FAIL CH large_position_threshold: got %', r.large_position_threshold; END IF;
    IF r.suitability_framework  <> 'FINMA_LSFin_2020' THEN RAISE EXCEPTION 'TC-4 FAIL CH suitability_framework: got %', r.suitability_framework; END IF;
    IF r.kms_vault_name         <> 'wealth-ch'       THEN RAISE EXCEPTION 'TC-4 FAIL CH kms_vault_name: got %', r.kms_vault_name; END IF;
    RAISE NOTICE 'TC-4 PASS: entity_config canonical values correct for SG, HK, CH';
END $$;

-- ---------------------------------------------------------------
-- TC-5: Composite PK defined on (original_pk, entity_id) and
--        FK on portfolio references client composite PK
-- ---------------------------------------------------------------
DO $$
DECLARE
    pk_col_count INTEGER;
    fk_count     INTEGER;
BEGIN
    -- portfolio PK must include both portfolio_id and entity_id
    SELECT COUNT(*) INTO pk_col_count
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
         ON tc.constraint_name = kcu.constraint_name
         AND tc.table_name     = kcu.table_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_name      = 'portfolio'
      AND kcu.column_name    IN ('portfolio_id','entity_id');
    IF pk_col_count <> 2 THEN
        RAISE EXCEPTION 'TC-5 FAIL: portfolio composite PK missing cols, found % of 2', pk_col_count;
    END IF;
    -- FK fk_portfolio_client must exist
    SELECT COUNT(*) INTO fk_count
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_name      = 'portfolio'
      AND constraint_name = 'fk_portfolio_client';
    IF fk_count <> 1 THEN
        RAISE EXCEPTION 'TC-5 FAIL: fk_portfolio_client not found';
    END IF;
    RAISE NOTICE 'TC-5 PASS: Composite PK and FK structure correct on portfolio';
END $$;

-- ---------------------------------------------------------------
-- TC-6: SG defaults preserved — bare INSERT produces SGD/Singapore/50
-- ---------------------------------------------------------------
DO $$
DECLARE
    v_client_id    UUID;
    v_portfolio_id UUID;
    v_currency     CHAR(3);
    v_centre       VARCHAR(50);
    v_fee          INTEGER;
BEGIN
    INSERT INTO client (full_name)
    VALUES ('SG Default Test Client')
    RETURNING client_id INTO v_client_id;

    INSERT INTO portfolio (client_id)
    VALUES (v_client_id)
    RETURNING portfolio_id, base_currency, booking_centre, mgmt_fee_bps
    INTO v_portfolio_id, v_currency, v_centre, v_fee;

    IF v_currency <> 'SGD'       THEN RAISE EXCEPTION 'TC-6 FAIL: default currency % != SGD', v_currency; END IF;
    IF v_centre   <> 'Singapore' THEN RAISE EXCEPTION 'TC-6 FAIL: default booking_centre % != Singapore', v_centre; END IF;
    IF v_fee      <> 50          THEN RAISE EXCEPTION 'TC-6 FAIL: default mgmt_fee_bps % != 50', v_fee; END IF;

    -- clean up
    DELETE FROM portfolio WHERE portfolio_id = v_portfolio_id AND entity_id = 'SG';
    DELETE FROM client    WHERE client_id    = v_client_id    AND entity_id = 'SG';

    RAISE NOTICE 'TC-6 PASS: SG defaults (SGD / Singapore / 50) preserved on bare INSERT';
END $$;
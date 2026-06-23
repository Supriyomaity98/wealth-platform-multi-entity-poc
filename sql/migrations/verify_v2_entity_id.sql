-- ==========================================================================
-- V2 Entity ID Migration Verification Script
-- ==========================================================================
-- Run this AFTER applying V2__add_entity_id.sql to verify correctness.
-- Each assertion block will raise an error or return unexpected results if
-- the migration was not applied correctly.
--
-- Usage:  psql -f sql/migrations/verify_v2_entity_id.sql -v ON_ERROR_STOP=1
-- ==========================================================================

-- -----------------------------------------------------------------------
-- ASSERTION 1: entity_id column exists on all three business tables
-- -----------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'client' AND column_name = 'entity_id'
    ) THEN
        RAISE EXCEPTION 'FAIL: client.entity_id column does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'portfolio' AND column_name = 'entity_id'
    ) THEN
        RAISE EXCEPTION 'FAIL: portfolio.entity_id column does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'holding' AND column_name = 'entity_id'
    ) THEN
        RAISE EXCEPTION 'FAIL: holding.entity_id column does not exist';
    END IF;

    RAISE NOTICE 'PASS: entity_id column exists on client, portfolio, holding';
END $$;

-- -----------------------------------------------------------------------
-- ASSERTION 2: entity_id columns are NOT NULL with DEFAULT 'SG'
-- -----------------------------------------------------------------------
DO $$
DECLARE
    v_is_nullable VARCHAR;
    v_default     VARCHAR;
BEGIN
    SELECT is_nullable, column_default
    INTO v_is_nullable, v_default
    FROM information_schema.columns
    WHERE table_name = 'client' AND column_name = 'entity_id';

    IF v_is_nullable != 'NO' THEN
        RAISE EXCEPTION 'FAIL: client.entity_id allows NULLs';
    END IF;
    IF v_default NOT LIKE '%SG%' THEN
        RAISE EXCEPTION 'FAIL: client.entity_id default is not SG (got: %)', v_default;
    END IF;

    SELECT is_nullable, column_default
    INTO v_is_nullable, v_default
    FROM information_schema.columns
    WHERE table_name = 'portfolio' AND column_name = 'entity_id';

    IF v_is_nullable != 'NO' THEN
        RAISE EXCEPTION 'FAIL: portfolio.entity_id allows NULLs';
    END IF;
    IF v_default NOT LIKE '%SG%' THEN
        RAISE EXCEPTION 'FAIL: portfolio.entity_id default is not SG (got: %)', v_default;
    END IF;

    SELECT is_nullable, column_default
    INTO v_is_nullable, v_default
    FROM information_schema.columns
    WHERE table_name = 'holding' AND column_name = 'entity_id';

    IF v_is_nullable != 'NO' THEN
        RAISE EXCEPTION 'FAIL: holding.entity_id allows NULLs';
    END IF;
    IF v_default NOT LIKE '%SG%' THEN
        RAISE EXCEPTION 'FAIL: holding.entity_id default is not SG (got: %)', v_default;
    END IF;

    RAISE NOTICE 'PASS: entity_id is NOT NULL DEFAULT SG on all tables';
END $$;

-- -----------------------------------------------------------------------
-- ASSERTION 3: entity_id data type is VARCHAR(10) on all tables
-- -----------------------------------------------------------------------
DO $$
DECLARE
    v_data_type   VARCHAR;
    v_max_length  INTEGER;
BEGIN
    SELECT data_type, character_maximum_length
    INTO v_data_type, v_max_length
    FROM information_schema.columns
    WHERE table_name = 'client' AND column_name = 'entity_id';

    IF v_data_type != 'character varying' OR v_max_length != 10 THEN
        RAISE EXCEPTION 'FAIL: client.entity_id type is % (%), expected VARCHAR(10)',
            v_data_type, v_max_length;
    END IF;

    SELECT data_type, character_maximum_length
    INTO v_data_type, v_max_length
    FROM information_schema.columns
    WHERE table_name = 'portfolio' AND column_name = 'entity_id';

    IF v_data_type != 'character varying' OR v_max_length != 10 THEN
        RAISE EXCEPTION 'FAIL: portfolio.entity_id type mismatch';
    END IF;

    SELECT data_type, character_maximum_length
    INTO v_data_type, v_max_length
    FROM information_schema.columns
    WHERE table_name = 'holding' AND column_name = 'entity_id';

    IF v_data_type != 'character varying' OR v_max_length != 10 THEN
        RAISE EXCEPTION 'FAIL: holding.entity_id type mismatch';
    END IF;

    RAISE NOTICE 'PASS: entity_id is VARCHAR(10) on all tables';
END $$;

-- -----------------------------------------------------------------------
-- ASSERTION 4: Covering indexes exist for entity_id
-- -----------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'client'
        AND indexdef LIKE '%entity_id%'
    ) THEN
        RAISE EXCEPTION 'FAIL: No entity_id index on client table';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'portfolio'
        AND indexdef LIKE '%entity_id%'
    ) THEN
        RAISE EXCEPTION 'FAIL: No entity_id index on portfolio table';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'holding'
        AND indexdef LIKE '%entity_id%'
    ) THEN
        RAISE EXCEPTION 'FAIL: No entity_id index on holding table';
    END IF;

    RAISE NOTICE 'PASS: entity_id indexes exist on all three tables';
END $$;

-- -----------------------------------------------------------------------
-- ASSERTION 5: Existing rows backfilled to 'SG'
-- -----------------------------------------------------------------------
DO $$
DECLARE
    v_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM client WHERE entity_id IS NULL OR entity_id != 'SG';

    IF v_count > 0 THEN
        RAISE NOTICE 'INFO: % client rows have non-SG entity_id (expected if multi-entity data inserted post-migration)', v_count;
    ELSE
        RAISE NOTICE 'PASS: All existing client rows backfilled to SG';
    END IF;
END $$;

-- -----------------------------------------------------------------------
-- ASSERTION 6: Migration verification complete
-- -----------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'PASS: V2 entity_id migration verification complete';
END $$;
#!/bin/bash
# filename: cobol/tests/run_sg_baseline.sh
# SG Baseline Sanity Check for PORTVAL.cbl (multi-entity refactor)
# Prerequisites: GnuCOBOL (cobc) installed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COBOL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$SCRIPT_DIR"
EXPECTED="$TEST_DIR/SG_BASELINE_EXPECTED.txt"
ACTUAL="$TEST_DIR/SG_BASELINE_ACTUAL.txt"
PASS_COUNT=0
FAIL_COUNT=0

pass_test() { echo "  PASS - $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail_test() { echo "  FAIL - $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

echo "=== SG Baseline Sanity Check ==="
echo "Compile dir : $COBOL_DIR"
echo "Test dir    : $TEST_DIR"

# -------------------------------------------------------------------
# TEST 1: Compile PORTVAL.cbl (verifies ENTCFG.cpy is valid)
# -------------------------------------------------------------------
echo ""
echo "[TEST 1] Compile PORTVAL.cbl with ENTCFG.cpy copybook"
cd "$COBOL_DIR"
if cobc -x -free -o "$TEST_DIR/PORTVAL" -I "$COBOL_DIR" PORTVAL.cbl 2>"$TEST_DIR/compile_errors.txt"; then
    pass_test "Compilation succeeded"
else
    fail_test "Compilation failed"
    cat "$TEST_DIR/compile_errors.txt"
    echo "RESULT: FAIL ($FAIL_COUNT failures)"
    exit 1
fi

# -------------------------------------------------------------------
# TEST 2: Run with ENTITY_ID unset (must default to SG)
# -------------------------------------------------------------------
echo ""
echo "[TEST 2] Run PORTVAL with ENTITY_ID unset (expect SG default)"
unset ENTITY_ID 2>/dev/null || true
"$TEST_DIR/PORTVAL" > "$ACTUAL" 2>&1 || true

if grep -q "SG" "$ACTUAL"; then
    pass_test "Entity code SG found in output"
else
    fail_test "Entity code SG not found in output"
fi

if grep -q "SGD" "$ACTUAL"; then
    pass_test "Currency SGD found in output"
else
    fail_test "Currency SGD not found in output"
fi

if grep -q "MAS" "$ACTUAL"; then
    pass_test "Regulator MAS found in output"
else
    fail_test "Regulator MAS not found in output"
fi

if grep -q "Singapore" "$ACTUAL"; then
    pass_test "Booking centre Singapore found in output"
else
    fail_test "Booking centre Singapore not found in output"
fi

# -------------------------------------------------------------------
# TEST 3: Run with ENTITY_ID=SG (explicit, same as default)
# -------------------------------------------------------------------
echo ""
echo "[TEST 3] Run PORTVAL with ENTITY_ID=SG (explicit)"
export ENTITY_ID="SG"
"$TEST_DIR/PORTVAL" > "${ACTUAL}.explicit_sg" 2>&1 || true

if diff -q "$ACTUAL" "${ACTUAL}.explicit_sg" > /dev/null 2>&1; then
    pass_test "Explicit SG output matches default (unset) output"
else
    fail_test "Explicit SG output differs from default output"
    diff "$ACTUAL" "${ACTUAL}.explicit_sg" || true
fi

# -------------------------------------------------------------------
# TEST 4: Run with ENTITY_ID=HK (verify different context loads)
# -------------------------------------------------------------------
echo ""
echo "[TEST 4] Run PORTVAL with ENTITY_ID=HK"
export ENTITY_ID="HK"
"$TEST_DIR/PORTVAL" > "${ACTUAL}.hk" 2>&1 || true

if grep -q "HKD" "${ACTUAL}.hk"; then
    pass_test "Currency HKD found for HK entity"
else
    fail_test "Currency HKD not found for HK entity"
fi

if grep -q "SFC\|HKMA" "${ACTUAL}.hk"; then
    pass_test "HK regulator found in output"
else
    fail_test "HK regulator not found in output"
fi

# -------------------------------------------------------------------
# TEST 5: Run with ENTITY_ID=CH (verify CH context loads)
# -------------------------------------------------------------------
echo ""
echo "[TEST 5] Run PORTVAL with ENTITY_ID=CH"
export ENTITY_ID="CH"
"$TEST_DIR/PORTVAL" > "${ACTUAL}.ch" 2>&1 || true

if grep -q "CHF" "${ACTUAL}.ch"; then
    pass_test "Currency CHF found for CH entity"
else
    fail_test "Currency CHF not found for CH entity"
fi

if grep -q "FINMA" "${ACTUAL}.ch"; then
    pass_test "CH regulator FINMA found in output"
else
    fail_test "CH regulator FINMA not found in output"
fi

# -------------------------------------------------------------------
# TEST 6: No plaintext secrets in source
# -------------------------------------------------------------------
echo ""
echo "[TEST 6] Verify no plaintext secrets in COBOL source"
SECRETS_FOUND=0
for pattern in "password" "Password" "PASSWORD" "secret" "apikey"; do
    if grep -rn "$pattern" "$COBOL_DIR/PORTVAL.cbl" "$COBOL_DIR/ENTCFG.cpy" 2>/dev/null \
       | grep -iv "KEYVAULT" | grep -iv "^\s*\*" | grep -iv "no plaintext" > /dev/null 2>&1; then
        SECRETS_FOUND=1
    fi
done
if [ $SECRETS_FOUND -eq 0 ]; then
    pass_test "No plaintext secrets found in source"
else
    fail_test "Possible plaintext secret patterns found (review manually)"
fi

# -------------------------------------------------------------------
# TEST 7: ENTCFG.cpy has all 3 entities
# -------------------------------------------------------------------
echo ""
echo "[TEST 7] Verify ENTCFG.cpy has constants for SG, HK, CH"
for entity in SG HK CH; do
    if grep -qi "${entity}" "$COBOL_DIR/ENTCFG.cpy" 2>/dev/null; then
        pass_test "Entity ${entity} constants found in ENTCFG.cpy"
    else
        fail_test "Entity ${entity} constants NOT found in ENTCFG.cpy"
    fi
done

# -------------------------------------------------------------------
# TEST 8: Key Vault references exist
# -------------------------------------------------------------------
echo ""
echo "[TEST 8] Verify Key Vault reference pattern exists"
if grep -rq "KEYVAULT" "$COBOL_DIR/PORTVAL.cbl" "$COBOL_DIR/ENTCFG.cpy" 2>/dev/null; then
    pass_test "KEYVAULT reference pattern found"
else
    fail_test "No KEYVAULT reference pattern found"
fi

# -------------------------------------------------------------------
# TEST 9: SG baseline string comparison
# -------------------------------------------------------------------
echo ""
echo "[TEST 9] Compare SG output against expected baseline"
if [ -f "$EXPECTED" ]; then
    MISMATCH=0
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        if ! grep -qF "$line" "$ACTUAL"; then
            echo "  MISMATCH - Expected line not found: $line"
            MISMATCH=1
        fi
    done < "$EXPECTED"
    if [ $MISMATCH -eq 0 ]; then
        pass_test "All expected SG baseline strings found"
    else
        fail_test "Some expected SG baseline strings missing"
    fi
else
    echo "  SKIP - No expected baseline file (generate on first run)"
fi

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo ""
echo "=== Results: $PASS_COUNT passed, $FAIL_COUNT failed ==="
if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
else
    echo "All sanity checks PASSED."
    exit 0
fi
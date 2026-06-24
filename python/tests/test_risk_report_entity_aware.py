"""Behaviour-preservation tests for risk_report.py entity-aware refactor.

Uses importlib.reload to switch ENTITY_ID between test cases.
All expected values are pinned to canonical constants supplied in task spec.
"""
import importlib
import os
import sys
from decimal import Decimal

import pytest


def _load_module(entity_id: str):
    """Set ENTITY_ID env var and (re)load risk_report, returning the module."""
    os.environ["ENTITY_ID"] = entity_id
    # Ensure a clean reload so module-level code re-executes.
    if "risk_report" in sys.modules:
        del sys.modules["risk_report"]
    import risk_report  # noqa: PLC0415  (intentional late import)
    return risk_report


@pytest.fixture(autouse=True)
def _cleanup_env_and_module():
    """Restore original ENTITY_ID and evict module after every test."""
    original = os.environ.get("ENTITY_ID")
    yield
    if original is None:
        os.environ.pop("ENTITY_ID", None)
    else:
        os.environ["ENTITY_ID"] = original
    sys.modules.pop("risk_report", None)


# ---------------------------------------------------------------------------
# 1. SG baseline — canonical values must be preserved exactly
# ---------------------------------------------------------------------------
def test_sg_baseline_canonical_values():
    m = _load_module("SG")

    assert m.CURRENCY == "SGD"
    assert m.LOCALE == "en_SG"
    assert m.REGULATOR == "MAS"
    assert m.BOOKING_CENTRE == "Singapore"
    assert m.MGMT_FEE_BPS == Decimal("50")
    assert m.LARGE_POSITION_THRESHOLD == Decimal("250000")
    assert m.SUITABILITY_FRAMEWORK == "MAS_FAA_2002"


# ---------------------------------------------------------------------------
# 2. HK entity switch — canonical values
# ---------------------------------------------------------------------------
def test_hk_entity_switch_canonical_values():
    m = _load_module("HK")

    assert m.CURRENCY == "HKD"
    assert m.LOCALE == "en_HK"
    assert m.REGULATOR == "SFC"
    assert m.BOOKING_CENTRE == "Hong Kong"
    assert m.MGMT_FEE_BPS == Decimal("60")
    assert m.LARGE_POSITION_THRESHOLD == Decimal("1000000")
    assert m.SUITABILITY_FRAMEWORK == "SFC_COP_2019"


# ---------------------------------------------------------------------------
# 3. CH entity switch — canonical values
# ---------------------------------------------------------------------------
def test_ch_entity_switch_canonical_values():
    m = _load_module("CH")

    assert m.CURRENCY == "CHF"
    assert m.LOCALE == "de_CH"
    assert m.REGULATOR == "FINMA"
    assert m.BOOKING_CENTRE == "Zurich"
    assert m.MGMT_FEE_BPS == Decimal("80")
    assert m.LARGE_POSITION_THRESHOLD == Decimal("5000000")
    assert m.SUITABILITY_FRAMEWORK == "FINMA_LSFin_2020"


# ---------------------------------------------------------------------------
# 4. Invalid entity raises ValueError (negative path)
# ---------------------------------------------------------------------------
def test_invalid_entity_raises_value_error():
    os.environ["ENTITY_ID"] = "XX"
    sys.modules.pop("risk_report", None)
    with pytest.raises(ValueError, match="Invalid ENTITY_ID 'XX'"):
        import risk_report  # noqa: F401


# ---------------------------------------------------------------------------
# 5. DB_CONNECTION_SECRET uses Key Vault reference pattern — no plaintext
# ---------------------------------------------------------------------------
def test_sg_db_connection_secret_format():
    m = _load_module("SG")
    secret = m.DB_CONNECTION_SECRET

    # Must follow the ${KEYVAULT:...} reference pattern
    assert secret.startswith("${KEYVAULT:"), f"Bad prefix: {secret}"
    assert secret.endswith("-db-connection-string}"), f"Bad suffix: {secret}"
    # Vault name fragment must contain the canonical SG vault name
    assert "wealth-sg" in secret, f"Expected 'wealth-sg' in secret ref: {secret}"
    # Must NOT contain any plaintext password or connection-string value
    assert "password" not in secret.lower()
    assert "jdbc" not in secret.lower()


# ---------------------------------------------------------------------------
# 6. Cross-entity: thresholds and fees must all differ from each other
# ---------------------------------------------------------------------------
def test_cross_entity_thresholds_differ():
    sg = _load_module("SG")
    sg_threshold = sg.LARGE_POSITION_THRESHOLD
    sg_fee = sg.MGMT_FEE_BPS

    hk = _load_module("HK")
    hk_threshold = hk.LARGE_POSITION_THRESHOLD
    hk_fee = hk.MGMT_FEE_BPS

    ch = _load_module("CH")
    ch_threshold = ch.LARGE_POSITION_THRESHOLD
    ch_fee = ch.MGMT_FEE_BPS

    # Thresholds must all be distinct
    assert sg_threshold != hk_threshold, "SG and HK thresholds must differ"
    assert hk_threshold != ch_threshold, "HK and CH thresholds must differ"
    assert sg_threshold != ch_threshold, "SG and CH thresholds must differ"

    # Fees must all be distinct
    assert sg_fee != hk_fee, "SG and HK fees must differ"
    assert hk_fee != ch_fee, "HK and CH fees must differ"
    assert sg_fee != ch_fee, "SG and CH fees must differ"

    # Canonical ordering: SG(50) < HK(60) < CH(80), SG < HK < CH thresholds
    assert sg_fee < hk_fee < ch_fee
    assert sg_threshold < hk_threshold < ch_threshold
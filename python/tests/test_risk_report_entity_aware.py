"""Behaviour-preservation tests for risk_report + entity_context (WP-PYTHON).

Uses importlib.reload to switch entities between tests.
All expected values are pinned to canonical spec.
"""
import importlib
import os
from decimal import Decimal

import pytest


def _reload_modules(entity_id: str):
    """Set ACME_ENTITY_ID and reload both modules; return fresh risk_report."""
    os.environ["ACME_ENTITY_ID"] = entity_id
    import python.entity_context as ec
    import python.risk_report as rr
    importlib.reload(ec)
    importlib.reload(rr)
    return rr


@pytest.fixture(autouse=True)
def _restore_env():
    original = os.environ.get("ACME_ENTITY_ID", "SG")
    yield
    os.environ["ACME_ENTITY_ID"] = original
    import python.entity_context as ec
    import python.risk_report as rr
    importlib.reload(ec)
    importlib.reload(rr)


# ---------------------------------------------------------------------------
# 1. SG baseline preservation
# ---------------------------------------------------------------------------
def test_sg_baseline_module_level_symbols():
    rr = _reload_modules("SG")
    assert rr.CURRENCY == "SGD"
    assert rr.LOCALE == "en_SG"
    assert rr.REGULATOR == "MAS"
    assert rr.BOOKING_CENTRE == "Singapore"
    assert rr.MGMT_FEE_BPS == Decimal("50")
    assert rr.LARGE_POSITION_THRESHOLD == Decimal("250000")
    assert rr.SUITABILITY_FRAMEWORK == "MAS_FAA_2002"


# ---------------------------------------------------------------------------
# 2. HK entity switch
# ---------------------------------------------------------------------------
def test_hk_entity_switch():
    rr = _reload_modules("HK")
    assert rr.CURRENCY == "HKD"
    assert rr.LOCALE == "en_HK"
    assert rr.REGULATOR == "SFC"
    assert rr.BOOKING_CENTRE == "Hong Kong"
    assert rr.MGMT_FEE_BPS == Decimal("60")
    assert rr.LARGE_POSITION_THRESHOLD == Decimal("1000000")
    assert rr.SUITABILITY_FRAMEWORK == "SFC_COP_2019"


# ---------------------------------------------------------------------------
# 3. CH entity switch
# ---------------------------------------------------------------------------
def test_ch_entity_switch():
    rr = _reload_modules("CH")
    assert rr.CURRENCY == "CHF"
    assert rr.LOCALE == "de_CH"
    assert rr.REGULATOR == "FINMA"
    assert rr.BOOKING_CENTRE == "Zurich"
    assert rr.MGMT_FEE_BPS == Decimal("80")
    assert rr.LARGE_POSITION_THRESHOLD == Decimal("5000000")
    assert rr.SUITABILITY_FRAMEWORK == "FINMA_LSFin_2020"


# ---------------------------------------------------------------------------
# 4. Unknown entity falls back to SG (default)
# ---------------------------------------------------------------------------
def test_unknown_entity_falls_back_to_sg():
    """Unset env var should default to SG per module docstring contract."""
    os.environ.pop("ACME_ENTITY_ID", None)
    import python.entity_context as ec
    import python.risk_report as rr
    importlib.reload(ec)
    importlib.reload(rr)
    assert rr.CURRENCY == "SGD"
    assert rr.REGULATOR == "MAS"
    assert rr.LARGE_POSITION_THRESHOLD == Decimal("250000")


# ---------------------------------------------------------------------------
# 5. is_large_position threshold boundary (SG)
# ---------------------------------------------------------------------------
def test_is_large_position_threshold_boundary():
    rr = _reload_modules("SG")
    threshold = Decimal("250000")
    assert rr.is_large_position(threshold) is True          # at boundary
    assert rr.is_large_position(threshold + 1) is True      # above
    assert rr.is_large_position(threshold - 1) is False     # below


# ---------------------------------------------------------------------------
# 6. DB_CONNECTION_SECRET uses KeyVault reference pattern
# ---------------------------------------------------------------------------
def test_db_connection_secret_keyvault_pattern():
    for entity, vault in (("SG", "wealth-sg"), ("HK", "wealth-hk"), ("CH", "wealth-ch")):
        rr = _reload_modules(entity)
        secret = rr.DB_CONNECTION_SECRET
        expected_fragment = f"${{KEYVAULT:{vault}-db-connection-string}}"
        assert expected_fragment == secret, (
            f"Entity {entity}: expected '{expected_fragment}', got '{secret}'"
        )
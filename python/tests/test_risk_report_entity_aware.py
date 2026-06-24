# filename: python/tests/test_risk_report_entity_aware.py
"""
QA iteration: WP-PYTHON — entity-aware risk_report.py
Canonical values are HARD-PINNED from task specification.
MAX 6 test cases.
"""
import importlib
import os
import sys
from decimal import Decimal
from pathlib import Path
from unittest import mock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))


def _reload_for_entity(entity_id: str):
    """Reload risk_report under a specific ENTITY_ID env var."""
    with mock.patch.dict(os.environ, {"ENTITY_ID": entity_id}, clear=False):
        import risk_report
        importlib.reload(risk_report)
        return risk_report


# ---------------------------------------------------------------------------
# TEST 1: SG baseline preservation — all five original SG values exact
# ---------------------------------------------------------------------------
def test_sg_baseline_module_symbols():
    mod = _reload_for_entity("SG")
    assert mod.CURRENCY == "SGD"
    assert mod.LOCALE == "en_SG"
    assert mod.REGULATOR == "MAS"
    assert mod.BOOKING_CENTRE == "Singapore"
    assert mod.MGMT_FEE_BPS == 50
    assert mod.LARGE_POSITION_THRESHOLD == Decimal("250000")
    assert mod.SUITABILITY_FRAMEWORK == "MAS_FAA_2002"
    assert mod.management_fee(Decimal("1000000")) == Decimal("5000")
    assert mod.management_fee(Decimal("0")) == Decimal("0.00")
    assert mod.is_large_position(Decimal("250000")) is True
    assert mod.is_large_position(Decimal("249999.99")) is False
    # backward-compat alias must still exist and work
    assert callable(mod.is_reportable)
    assert mod.is_reportable(Decimal("250000")) is True


# ---------------------------------------------------------------------------
# TEST 2: HK entity switch — canonical hard-pinned values
# ---------------------------------------------------------------------------
def test_hk_entity_symbols():
    mod = _reload_for_entity("HK")
    assert mod.CURRENCY == "HKD"
    assert mod.LOCALE == "en_HK"
    assert mod.REGULATOR == "SFC"
    assert mod.BOOKING_CENTRE == "Hong Kong"
    assert mod.MGMT_FEE_BPS == 60
    assert mod.LARGE_POSITION_THRESHOLD == Decimal("1000000")
    assert mod.SUITABILITY_FRAMEWORK == "SFC_COP_2019"
    # fee: 1_000_000 * 60 / 10_000 = 6_000
    assert mod.management_fee(Decimal("1000000")) == Decimal("6000")
    assert mod.is_large_position(Decimal("1000000")) is True
    assert mod.is_large_position(Decimal("999999.99")) is False


# ---------------------------------------------------------------------------
# TEST 3: CH entity switch — canonical hard-pinned values
# ---------------------------------------------------------------------------
def test_ch_entity_symbols():
    mod = _reload_for_entity("CH")
    assert mod.CURRENCY == "CHF"
    assert mod.LOCALE == "de_CH"
    assert mod.REGULATOR == "FINMA"
    assert mod.BOOKING_CENTRE == "Zurich"
    assert mod.MGMT_FEE_BPS == 80
    assert mod.LARGE_POSITION_THRESHOLD == Decimal("5000000")
    assert mod.SUITABILITY_FRAMEWORK == "FINMA_LSFin_2020"
    # fee: 5_000_000 * 80 / 10_000 = 40_000
    assert mod.management_fee(Decimal("5000000")) == Decimal("40000")
    assert mod.is_large_position(Decimal("5000000")) is True
    assert mod.is_large_position(Decimal("4999999.99")) is False


# ---------------------------------------------------------------------------
# TEST 4: Negative path — invalid ENTITY_ID must raise ValueError loudly
# ---------------------------------------------------------------------------
def test_invalid_entity_raises_value_error():
    with mock.patch.dict(os.environ, {"ENTITY_ID": "XX"}, clear=False):
        import risk_report
        with pytest.raises(ValueError, match="ENTITY_ID"):
            importlib.reload(risk_report)


# ---------------------------------------------------------------------------
# TEST 5: Cross-entity differ — SG vs HK threshold divergence
# 500 000 is LARGE for SG but NOT LARGE for HK
# ---------------------------------------------------------------------------
def test_sg_hk_large_position_threshold_differs():
    sg = _reload_for_entity("SG")
    hk = _reload_for_entity("HK")
    assert sg.LARGE_POSITION_THRESHOLD == Decimal("250000")
    assert hk.LARGE_POSITION_THRESHOLD == Decimal("1000000")
    mid = Decimal("500000")
    assert sg.is_large_position(mid) is True
    assert hk.is_large_position(mid) is False


# ---------------------------------------------------------------------------
# TEST 6: Cross-entity differ — fee_bps strictly escalates SG < HK < CH
# Same notional must produce different fees per entity
# ---------------------------------------------------------------------------
def test_fee_bps_escalation_sg_lt_hk_lt_ch():
    sg = _reload_for_entity("SG")
    hk = _reload_for_entity("HK")
    ch = _reload_for_entity("CH")
    assert sg.MGMT_FEE_BPS == 50
    assert hk.MGMT_FEE_BPS == 60
    assert ch.MGMT_FEE_BPS == 80
    assert sg.MGMT_FEE_BPS < hk.MGMT_FEE_BPS < ch.MGMT_FEE_BPS
    notional = Decimal("1000000")
    assert sg.management_fee(notional) == Decimal("5000")
    assert hk.management_fee(notional) == Decimal("6000")
    assert ch.management_fee(notional) == Decimal("8000")
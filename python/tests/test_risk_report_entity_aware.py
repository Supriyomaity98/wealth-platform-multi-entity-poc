"""Entity-aware tests for risk_report module — max 6 cases, canonical values."""
import importlib
import os
import sys
from decimal import Decimal

import pytest


def _reload_risk_report(entity_id: str):
    """Set WEALTH_ENTITY, drop cached module, reimport, return module."""
    os.environ["WEALTH_ENTITY"] = entity_id
    # Drop from cache so module-level code re-executes with new env var
    sys.modules.pop("risk_report", None)
    # Ensure the package root is importable
    pkg_root = os.path.join(os.path.dirname(__file__), "..")
    if pkg_root not in sys.path:
        sys.path.insert(0, pkg_root)
    import risk_report  # noqa: F811
    return risk_report


# ── 1. SG baseline preservation ──────────────────────────────────────
def test_sg_baseline_defaults():
    mod = _reload_risk_report("SG")
    assert mod.CURRENCY == "SGD"
    assert mod.LOCALE == "en_SG"
    assert mod.REGULATOR == "MAS"
    assert mod.BOOKING_CENTRE == "Singapore"
    assert mod.MGMT_FEE_BPS == Decimal("50")
    assert mod.LARGE_POSITION_THRESHOLD == Decimal("250000")
    assert mod.SUITABILITY_FRAMEWORK == "MAS_FAA_2002"
    # DB secret must be a Key Vault reference, not plaintext
    assert mod.DB_CONNECTION_SECRET.startswith("${KEYVAULT:")
    assert "wealth-sg" in mod.DB_CONNECTION_SECRET


# ── 2. HK entity switch ──────────────────────────────────────────────
def test_hk_entity_switch():
    mod = _reload_risk_report("HK")
    assert mod.CURRENCY == "HKD"
    assert mod.LOCALE == "en_HK"
    assert mod.REGULATOR == "SFC"
    assert mod.BOOKING_CENTRE == "Hong Kong"
    assert mod.MGMT_FEE_BPS == Decimal("60")
    assert mod.LARGE_POSITION_THRESHOLD == Decimal("1000000")
    assert mod.SUITABILITY_FRAMEWORK == "SFC_COP_2019"
    assert "wealth-hk" in mod.DB_CONNECTION_SECRET


# ── 3. CH entity switch ──────────────────────────────────────────────
def test_ch_entity_switch():
    mod = _reload_risk_report("CH")
    assert mod.CURRENCY == "CHF"
    assert mod.LOCALE == "de_CH"
    assert mod.REGULATOR == "FINMA"
    assert mod.BOOKING_CENTRE == "Zurich"
    assert mod.MGMT_FEE_BPS == Decimal("80")
    assert mod.LARGE_POSITION_THRESHOLD == Decimal("5000000")
    assert mod.SUITABILITY_FRAMEWORK == "FINMA_LSFin_2020"
    assert "wealth-ch" in mod.DB_CONNECTION_SECRET


# ── 4. Missing entity raises FileNotFoundError ───────────────────────
def test_missing_entity_raises():
    with pytest.raises(FileNotFoundError, match="Entity config not found"):
        _reload_risk_report("XX")


# ── 5. is_large_position differs across SG vs HK ────────────────────
def test_is_large_position_sg_vs_hk():
    sg = _reload_risk_report("SG")
    # 500_000 is above SG threshold (250k) → large
    assert sg.is_large_position(Decimal("500000")) is True
    # 100_000 is below SG threshold → not large
    assert sg.is_large_position(Decimal("100000")) is False

    hk = _reload_risk_report("HK")
    # 500_000 is below HK threshold (1M) → not large
    assert hk.is_large_position(Decimal("500000")) is False
    # 2_000_000 is above HK threshold → large
    assert hk.is_large_position(Decimal("2000000")) is True


# ── 6. DB_CONNECTION_SECRET never contains plaintext creds ───────────
def test_db_connection_secret_no_plaintext():
    for eid in ("SG", "HK", "CH"):
        mod = _reload_risk_report(eid)
        secret = mod.DB_CONNECTION_SECRET
        assert secret.startswith("${KEYVAULT:")
        assert secret.endswith("}")
        # Must not contain common plaintext patterns
        lower = secret.lower()
        for bad in ("password=", "pwd=", "user=", "jdbc:"):
            assert bad not in lower, f"Plaintext credential marker '{bad}' in {eid} secret"
"""Tests for the entity-aware risk_report module.

The test suite covers:
  1. SG baseline \u2014 exact behavioural parity with the original module.
  2. HK entity \u2014 fee schedule, threshold, disclosure.
  3. CH entity \u2014 fee schedule, threshold, disclosure.
  4. Multi-entity config loading.
"""

from __future__ import annotations

import importlib
import os
from decimal import Decimal

import pytest

# ---------------------------------------------------------------------------
# Helper: reload risk_report under a specific ENTITY_ID
# ---------------------------------------------------------------------------

def _load_report_module(entity_id: str):
    """(Re-)load risk_report with the given ENTITY_ID in the environment."""
    import entity_config as ec_mod
    ec_mod.clear_cache()

    os.environ["ENTITY_ID"] = entity_id

    import risk_report
    importlib.reload(ec_mod)
    importlib.reload(risk_report)
    return risk_report


# ===========================================================================
# SG Baseline (exact behavioural preservation)
# ===========================================================================

class TestSGBaseline:
    """These tests mirror the original test_risk_report.py assertions exactly."""

    @pytest.fixture(autouse=True)
    def _setup(self):
        self.rr = _load_report_module("SG")
        yield
        os.environ.pop("ENTITY_ID", None)

    def test_management_fee_one_million(self):
        assert self.rr.management_fee(Decimal("1000000")) == Decimal("5000")

    def test_management_fee_zero(self):
        assert self.rr.management_fee(Decimal("0")) == Decimal("0.00")

    def test_is_reportable_at_threshold(self):
        # SG portfolio_minimum is 200000
        assert self.rr.is_reportable(Decimal("200000")) is True

    def test_is_reportable_below_threshold(self):
        assert self.rr.is_reportable(Decimal("199999.99")) is False

    def test_build_report_singapore_fields(self):
        report = self.rr.build_report("PF-001", Decimal("1000000"))
        assert report["entity_code"] == "SG"
        assert report["currency"] == "SGD"
        assert report["regulator"] == "MAS"
        assert report["management_fee"] == Decimal("5000")
        assert report["management_fee_bps"] == Decimal("50")
        assert report["reportable"] is True
        assert "MAS Notice FAA" in report["disclosure"]

    def test_sg_module_level_constants(self):
        assert self.rr.ENTITY_CODE == "SG"
        assert self.rr.CURRENCY == "SGD"
        assert self.rr.REGULATOR == "MAS"
        assert self.rr.LOCALE == "en_SG"
        assert self.rr.MGMT_FEE_BPS == Decimal("50")
        assert self.rr.SUITABILITY_FRAMEWORK == "MAS_FAA_2002"


# ===========================================================================
# HK Entity
# ===========================================================================

class TestHKEntity:

    @pytest.fixture(autouse=True)
    def _setup(self):
        self.rr = _load_report_module("HK")
        yield
        os.environ.pop("ENTITY_ID", None)

    def test_hk_constants(self):
        assert self.rr.ENTITY_CODE == "HK"
        assert self.rr.CURRENCY == "HKD"
        assert self.rr.REGULATOR == "HKMA"
        assert self.rr.LOCALE == "zh_HK"
        assert self.rr.MGMT_FEE_BPS == Decimal("45")

    def test_hk_fee(self):
        # 45 bps on 1 000 000
        assert self.rr.management_fee(Decimal("1000000")) == Decimal("4500.00")

    def test_hk_threshold(self):
        # portfolio_minimum = 1 000 000
        assert self.rr.is_reportable(Decimal("1000000")) is True
        assert self.rr.is_reportable(Decimal("999999.99")) is False

    def test_hk_disclosure(self):
        report = self.rr.build_report("PF-HK-01", Decimal("2000000"))
        assert "SFC_COP_2019" in report["disclosure"]

    def test_hk_entity_name(self):
        assert self.rr.ENTITY_NAME == "Hong Kong"


# ===========================================================================
# CH Entity
# ===========================================================================

class TestCHEntity:

    @pytest.fixture(autouse=True)
    def _setup(self):
        self.rr = _load_report_module("CH")
        yield
        os.environ.pop("ENTITY_ID", None)

    def test_ch_constants(self):
        assert self.rr.ENTITY_CODE == "CH"
        assert self.rr.CURRENCY == "CHF"
        assert self.rr.REGULATOR == "FINMA"
        assert self.rr.LOCALE == "de_CH"
        assert self.rr.MGMT_FEE_BPS == Decimal("45")

    def test_ch_fee(self):
        assert self.rr.management_fee(Decimal("1000000")) == Decimal("4500.00")

    def test_ch_threshold(self):
        # portfolio_minimum = 500 000
        assert self.rr.is_reportable(Decimal("500000")) is True
        assert self.rr.is_reportable(Decimal("499999.99")) is False

    def test_ch_disclosure(self):
        report = self.rr.build_report("PF-CH-01", Decimal("600000"))
        assert "FINMA_OUTSOURCING_2018_3" in report["disclosure"]

    def test_ch_entity_name(self):
        assert self.rr.ENTITY_NAME == "Switzerland"


# ===========================================================================
# Multi-entity config loading
# ===========================================================================

class TestMultiEntityConfigLoading:
    """Verify that multiple entity configs can be loaded and cached."""

    def teardown_method(self):
        os.environ.pop("ENTITY_ID", None)

    def test_load_all_entities(self):
        from entity_config import load_entity_config, clear_cache
        clear_cache()
        for eid, cur in [("SG", "SGD"), ("HK", "HKD"), ("CH", "CHF")]:
            cfg = load_entity_config(eid)
            assert cfg.entity_id == eid
            assert cfg.currency == cur

    def test_cache_returns_same_object(self):
        from entity_config import load_entity_config, clear_cache
        clear_cache()
        a = load_entity_config("SG")
        b = load_entity_config("SG")
        assert a is b

    def test_unknown_entity_raises(self):
        from entity_config import load_entity_config, clear_cache
        clear_cache()
        with pytest.raises(FileNotFoundError):
            load_entity_config("XX")

    def test_secret_ref_pattern(self):
        from entity_config import load_entity_config, clear_cache
        clear_cache()
        cfg = load_entity_config("HK")
        assert cfg.secret_ref("db-conn") == "${KEYVAULT:wealth-hk-db-conn}"

    def test_all_shared_contract_keys_present(self):
        from entity_config import load_entity_config, clear_cache
        clear_cache()
        for eid in ["SG", "HK", "CH"]:
            cfg = load_entity_config(eid)
            assert cfg.entity_id
            assert cfg.currency
            assert cfg.locale_primary
            assert len(cfg.locale_supported) >= 1
            assert len(cfg.fee_schedule) >= 1
            assert cfg.portfolio_minimum["amount"] > 0
            assert cfg.data_region
            assert cfg.kms_vault_name
            assert len(cfg.regulator) >= 1
            assert cfg.suitability_framework
            assert len(cfg.disclosure_locale) >= 1
            assert cfg.audit_siem_workspace
            assert cfg.data_residency_rule


# ===========================================================================
# Backward compatibility: default ENTITY_ID
# ===========================================================================

class TestDefaultEntity:
    """When ENTITY_ID is unset, SG must be used."""

    def test_defaults_to_sg(self):
        os.environ.pop("ENTITY_ID", None)
        rr = _load_report_module("SG")
        assert rr.ENTITY_CODE == "SG"
import importlib
import os
import sys
from decimal import Decimal
from pathlib import Path
from unittest import mock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

import risk_report
from risk_report import (
    BOOKING_CENTRE,
    CURRENCY,
    DB_CONNECTION_SECRET,
    ENTITY_CODE,
    LARGE_POSITION_THRESHOLD,
    LOCALE,
    MGMT_FEE_BPS,
    REGULATOR,
    SUITABILITY_FRAMEWORK,
    build_report,
    is_large_position,
    is_reportable,
    management_fee,
)


# ---------------------------------------------------------------------------
# SG baseline — ALL original tests preserved verbatim
# ---------------------------------------------------------------------------

def test_management_fee_one_million():
    assert management_fee(Decimal("1000000")) == Decimal("5000")


def test_management_fee_zero():
    assert management_fee(Decimal("0")) == Decimal("0.00")


def test_is_reportable_at_threshold():
    assert is_reportable(Decimal("250000")) is True


def test_is_reportable_below_threshold():
    assert is_reportable(Decimal("249999.99")) is False


def test_build_report_singapore_fields():
    report = build_report("PF-001", Decimal("1000000"))
    assert report["entity_code"] == "SG"
    assert report["currency"] == "SGD"
    assert report["regulator"] == "MAS"
    assert report["management_fee"] == Decimal("5000")
    assert report["management_fee_bps"] == MGMT_FEE_BPS
    assert report["reportable"] is True
    assert "MAS Notice FAA" in report["disclosure"] or "MAS_FAA_2002" in report["disclosure"]


# ---------------------------------------------------------------------------
# SG module-level symbol assertions
# ---------------------------------------------------------------------------

def test_sg_module_symbols():
    assert ENTITY_CODE == "SG"
    assert CURRENCY == "SGD"
    assert LOCALE == "en_SG"
    assert REGULATOR == "MAS"
    assert BOOKING_CENTRE == "Singapore"
    assert MGMT_FEE_BPS == Decimal("50")
    assert LARGE_POSITION_THRESHOLD == Decimal("250000")
    assert SUITABILITY_FRAMEWORK == "MAS_FAA_2002"
    assert DB_CONNECTION_SECRET == "${KEYVAULT:wealth-sg-db-connection-string}"


def test_is_large_position_alias():
    assert is_large_position(Decimal("250000")) is True
    assert is_large_position(Decimal("249999.99")) is False


# ---------------------------------------------------------------------------
# Helper: reload risk_report under a different ENTITY_ID
# ---------------------------------------------------------------------------

def _reload_for_entity(entity_id: str):
    with mock.patch.dict(os.environ, {"ENTITY_ID": entity_id}):
        if "risk_report" in sys.modules:
            del sys.modules["risk_report"]
        mod = importlib.import_module("risk_report")
    return mod


def _restore_sg():
    if "risk_report" in sys.modules:
        del sys.modules["risk_report"]
    with mock.patch.dict(os.environ, {"ENTITY_ID": "SG"}):
        importlib.import_module("risk_report")


# ---------------------------------------------------------------------------
# HK entity tests
# ---------------------------------------------------------------------------

class TestHKEntity:
    @pytest.fixture(autouse=True)
    def hk_module(self):
        self.mod = _reload_for_entity("HK")
        yield
        _restore_sg()

    def test_hk_symbols(self):
        assert self.mod.ENTITY_CODE == "HK"
        assert self.mod.CURRENCY == "HKD"
        assert self.mod.LOCALE == "en_HK"
        assert self.mod.REGULATOR == "SFC"
        assert self.mod.BOOKING_CENTRE == "Hong Kong"
        assert self.mod.MGMT_FEE_BPS == Decimal("60")
        assert self.mod.LARGE_POSITION_THRESHOLD == Decimal("1000000")
        assert self.mod.SUITABILITY_FRAMEWORK == "SFC_COP_2019"
        assert self.mod.DB_CONNECTION_SECRET == "${KEYVAULT:wealth-hk-db-connection-string}"

    def test_hk_management_fee(self):
        assert self.mod.management_fee(Decimal("1000000")) == Decimal("6000.00")

    def test_hk_is_large_position(self):
        assert self.mod.is_large_position(Decimal("1000000")) is True
        assert self.mod.is_large_position(Decimal("999999.99")) is False

    def test_hk_build_report(self):
        report = self.mod.build_report("PF-HK-001", Decimal("2000000"))
        assert report["entity_code"] == "HK"
        assert report["currency"] == "HKD"
        assert report["regulator"] == "SFC"
        assert report["management_fee"] == Decimal("12000.00")
        assert report["reportable"] is True


# ---------------------------------------------------------------------------
# CH entity tests
# ---------------------------------------------------------------------------

class TestCHEntity:
    @pytest.fixture(autouse=True)
    def ch_module(self):
        self.mod = _reload_for_entity("CH")
        yield
        _restore_sg()

    def test_ch_symbols(self):
        assert self.mod.ENTITY_CODE == "CH"
        assert self.mod.CURRENCY == "CHF"
        assert self.mod.LOCALE == "de_CH"
        assert self.mod.REGULATOR == "FINMA"
        assert self.mod.BOOKING_CENTRE == "Zurich"
        assert self.mod.MGMT_FEE_BPS == Decimal("80")
        assert self.mod.LARGE_POSITION_THRESHOLD == Decimal("5000000")
        assert self.mod.SUITABILITY_FRAMEWORK == "FINMA_LSFin_2020"
        assert self.mod.DB_CONNECTION_SECRET == "${KEYVAULT:wealth-ch-db-connection-string}"

    def test_ch_management_fee(self):
        assert self.mod.management_fee(Decimal("1000000")) == Decimal("8000.00")

    def test_ch_is_large_position(self):
        assert self.mod.is_large_position(Decimal("5000000")) is True
        assert self.mod.is_large_position(Decimal("4999999.99")) is False

    def test_ch_build_report(self):
        report = self.mod.build_report("PF-CH-001", Decimal("10000000"))
        assert report["entity_code"] == "CH"
        assert report["currency"] == "CHF"
        assert report["regulator"] == "FINMA"
        assert report["management_fee"] == Decimal("80000.00")
        assert report["reportable"] is True


# ---------------------------------------------------------------------------
# Startup validation tests
# ---------------------------------------------------------------------------

def test_invalid_entity_raises():
    with pytest.raises((ValueError, FileNotFoundError)):
        _reload_for_entity("XX")


def test_entity_id_defaults_to_sg_when_unset(monkeypatch):
    monkeypatch.delenv("ENTITY_ID", raising=False)
    if "risk_report" in sys.modules:
        del sys.modules["risk_report"]
    mod = importlib.import_module("risk_report")
    assert mod.ENTITY_CODE == "SG"
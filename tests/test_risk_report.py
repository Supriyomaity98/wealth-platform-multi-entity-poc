"""Tests for risk_report.py — entity-aware configuration.

Covers:
- SG baseline behaviour preservation
- HK and CH entity loading
- Config validation (missing keys, type errors, entity_id mismatch)
- Secret validation (kms_vault_name presence)
- Data-level entity_id segregation assertions
- Key Vault reference format
"""

import os
import sys
from decimal import Decimal
from pathlib import Path
from unittest import mock

import pytest
import yaml

# Ensure the python/ package is importable
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "python"))

import risk_report  # noqa: E402


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def _reset_module_state():
    """Reset the module-level _entity before each test."""
    risk_report._entity = None
    yield
    risk_report._entity = None


@pytest.fixture()
def config_dir(tmp_path):
    """Create a temporary config directory and point the module at it."""
    entities_dir = tmp_path / "configs" / "entities"
    entities_dir.mkdir(parents=True)
    with mock.patch.dict(os.environ, {"ENTITY_CONFIG_DIR": str(entities_dir)}):
        yield entities_dir


def _write_config(config_dir: Path, entity_id: str, overrides: dict = None) -> Path:
    """Write a valid entity YAML, optionally merging *overrides*."""
    base = {
        "entity_id": entity_id,
        "entity_full_name": f"Test Entity ({entity_id})",
        "currency": "SGD",
        "fee_schedule_bps": 50,
        "min_portfolio_threshold": 250000,
        "default_locale": "en_SG",
        "booking_centre": "Singapore",
        "data_region": "Southeast Asia",
        "kms_vault_name": "kv-test-vault",
        "suitability_framework": "MAS_FAA_2002",
        "regulatory_bodies": ["MAS"],
        "disclosure_locale_map": {"en": "disclosures/en_SG/"},
    }
    if overrides:
        base.update(overrides)
    p = config_dir / f"{entity_id}.yaml"
    p.write_text(yaml.dump(base, default_flow_style=False), encoding="utf-8")
    return p


# ---------------------------------------------------------------------------
# SG Baseline Behaviour Preservation
# ---------------------------------------------------------------------------

class TestSGBaselineBehaviour:
    """Verify every SG-specific value and computation is preserved exactly."""

    def test_management_fee_50bps(self, config_dir):
        _write_config(config_dir, "SG")
        cfg = risk_report.load_entity_config("SG")
        mv = Decimal("1000000")
        fee = risk_report.management_fee(mv, cfg)
        expected = (mv * Decimal("50") / Decimal("10000")).quantize(Decimal("0.01"))
        assert fee == expected
        assert fee == Decimal("5000.00")

    def test_is_reportable_at_threshold(self, config_dir):
        _write_config(config_dir, "SG")
        cfg = risk_report.load_entity_config("SG")
        assert risk_report.is_reportable(Decimal("250000"), cfg) is True
        assert risk_report.is_reportable(Decimal("249999.99"), cfg) is False

    def test_disclosure_text_mas(self, config_dir):
        _write_config(config_dir, "SG")
        cfg = risk_report.load_entity_config("SG")
        text = risk_report.disclosure_text(cfg)
        assert text == (
            "MAS Notice FAA: Past performance is not indicative of future results. "
            "Investments involve risk."
        )

    def test_build_report_sg(self, config_dir):
        _write_config(config_dir, "SG", {
            "entity_full_name": "ACME Wealth Management Pte Ltd (Singapore)",
        })
        cfg = risk_report.load_entity_config("SG")
        report = risk_report.build_report("P001", Decimal("500000"), cfg)
        assert report["entity_code"] == "SG"
        assert report["entity_name"] == "ACME Wealth Management Pte Ltd (Singapore)"
        assert report["regulator"] == "MAS"
        assert report["currency"] == "SGD"
        assert report["locale"] == "en_SG"
        assert report["data_region"] == "Southeast Asia"
        assert report["suitability_framework"] == "MAS_FAA_2002"
        assert report["management_fee_bps"] == Decimal("50")
        assert report["reportable"] is True
        assert "MAS Notice FAA" in report["disclosure"]

    def test_build_report_below_threshold(self, config_dir):
        _write_config(config_dir, "SG")
        cfg = risk_report.load_entity_config("SG")
        report = risk_report.build_report("P002", Decimal("100000"), cfg)
        assert report["reportable"] is False
        assert report["disclosure"] == ""


# ---------------------------------------------------------------------------
# HK Entity
# ---------------------------------------------------------------------------

class TestHKEntity:
    def test_hk_config_loads(self, config_dir):
        _write_config(config_dir, "HK", {
            "entity_full_name": "ACME Wealth Management Limited (Hong Kong)",
            "currency": "HKD",
            "fee_schedule_bps": 40,
            "min_portfolio_threshold": 200000,
            "default_locale": "zh_HK",
            "booking_centre": "Hong Kong",
            "data_region": "East Asia",
            "kms_vault_name": "kv-hk-ea",
            "suitability_framework": "SFC_COP_2019",
            "regulatory_bodies": ["SFC", "HKMA", "PDPO"],
            "disclosure_locale_map": {"zh": "disclosures/zh_HK/", "en": "disclosures/en_HK/"},
        })
        cfg = risk_report.load_entity_config("HK")
        assert cfg.entity_id == "HK"
        assert cfg.currency == "HKD"
        assert cfg.fee_schedule_bps == Decimal("40")
        assert cfg.primary_regulator == "SFC"

    def test_hk_management_fee_40bps(self, config_dir):
        _write_config(config_dir, "HK", {
            "fee_schedule_bps": 40,
            "suitability_framework": "SFC_COP_2019",
        })
        cfg = risk_report.load_entity_config("HK")
        fee = risk_report.management_fee(Decimal("1000000"), cfg)
        expected = (Decimal("1000000") * Decimal("40") / Decimal("10000")).quantize(Decimal("0.01"))
        assert fee == expected
        assert fee == Decimal("4000.00")

    def test_hk_disclosure_sfc(self, config_dir):
        _write_config(config_dir, "HK", {
            "suitability_framework": "SFC_COP_2019",
        })
        cfg = risk_report.load_entity_config("HK")
        text = risk_report.disclosure_text(cfg)
        assert "SFC Code of Conduct" in text

    def test_hk_threshold(self, config_dir):
        _write_config(config_dir, "HK", {
            "min_portfolio_threshold": 200000,
            "suitability_framework": "SFC_COP_2019",
        })
        cfg = risk_report.load_entity_config("HK")
        assert risk_report.is_reportable(Decimal("200000"), cfg) is True
        assert risk_report.is_reportable(Decimal("199999.99"), cfg) is False


# ---------------------------------------------------------------------------
# CH Entity
# ---------------------------------------------------------------------------

class TestCHEntity:
    def test_ch_config_loads(self, config_dir):
        _write_config(config_dir, "CH", {
            "entity_full_name": "ACME Wealth Management AG (Switzerland)",
            "currency": "CHF",
            "fee_schedule_bps": 30,
            "min_portfolio_threshold": 250000,
            "default_locale": "de_CH",
            "booking_centre": "Zurich",
            "data_region": "Switzerland North",
            "kms_vault_name": "kv-ch-chn",
            "suitability_framework": "FINMA_LSFin_2020",
            "regulatory_bodies": ["FINMA", "FADP_nDSG"],
            "disclosure_locale_map": {
                "de": "disclosures/de_CH/",
                "fr": "disclosures/fr_CH/",
                "it": "disclosures/it_CH/",
                "en": "disclosures/en_CH/",
            },
        })
        cfg = risk_report.load_entity_config("CH")
        assert cfg.entity_id == "CH"
        assert cfg.currency == "CHF"
        assert cfg.fee_schedule_bps == Decimal("30")
        assert cfg.primary_regulator == "FINMA"

    def test_ch_management_fee_30bps(self, config_dir):
        _write_config(config_dir, "CH", {
            "fee_schedule_bps": 30,
            "suitability_framework": "FINMA_LSFin_2020",
        })
        cfg = risk_report.load_entity_config("CH")
        fee = risk_report.management_fee(Decimal("1000000"), cfg)
        assert fee == Decimal("3000.00")

    def test_ch_disclosure_finma(self, config_dir):
        _write_config(config_dir, "CH", {
            "suitability_framework": "FINMA_LSFin_2020",
        })
        cfg = risk_report.load_entity_config("CH")
        text = risk_report.disclosure_text(cfg)
        assert "FINMA LSFin" in text


# ---------------------------------------------------------------------------
# Config Validation
# ---------------------------------------------------------------------------

class TestConfigValidation:
    def test_missing_entity_id_env_var(self, config_dir):
        with mock.patch.dict(os.environ, {"ENTITY_ID": ""}, clear=False):
            with pytest.raises(SystemExit):
                risk_report.load_entity_config()

    def test_missing_config_file(self, config_dir):
        with pytest.raises(SystemExit):
            risk_report.load_entity_config("NONEXISTENT")

    def test_missing_required_key(self, config_dir):
        p = config_dir / "BAD.yaml"
        p.write_text(yaml.dump({"entity_id": "BAD"}), encoding="utf-8")
        with pytest.raises(SystemExit):
            risk_report.load_entity_config("BAD")

    def test_entity_id_mismatch(self, config_dir):
        _write_config(config_dir, "MISMATCH", {"entity_id": "WRONG"})
        with pytest.raises(SystemExit):
            risk_report.load_entity_config("MISMATCH")

    def test_invalid_currency_length(self, config_dir):
        _write_config(config_dir, "BADCUR", {"entity_id": "BADCUR", "currency": "ABCD"})
        with pytest.raises(SystemExit):
            risk_report.load_entity_config("BADCUR")

    def test_empty_regulatory_bodies(self, config_dir):
        _write_config(config_dir, "NOREG", {"entity_id": "NOREG", "regulatory_bodies": []})
        with pytest.raises(SystemExit):
            risk_report.load_entity_config("NOREG")

    def test_invalid_kms_vault_name(self, config_dir):
        _write_config(config_dir, "BADVAULT", {
            "entity_id": "BADVAULT",
            "kms_vault_name": "bad vault/name",
        })
        with pytest.raises(SystemExit):
            risk_report.load_entity_config("BADVAULT")


# ---------------------------------------------------------------------------
# Secret Reference (Key Vault pattern)
# ---------------------------------------------------------------------------

class TestSecretReferences:
    def test_secret_ref_format(self, config_dir):
        _write_config(config_dir, "SG")
        cfg = risk_report.load_entity_config("SG")
        ref = risk_report.secret_ref("db-password", cfg)
        assert ref == "${KEYVAULT:kv-test-vault/db-password}"

    def test_secret_ref_hk(self, config_dir):
        _write_config(config_dir, "HK", {
            "kms_vault_name": "kv-hk-ea",
            "suitability_framework": "SFC_COP_2019",
        })
        cfg = risk_report.load_entity_config("HK")
        ref = risk_report.secret_ref("api-key", cfg)
        assert ref == "${KEYVAULT:kv-hk-ea/api-key}"


# ---------------------------------------------------------------------------
# Data-Level Entity Segregation (logical assertions)
# ---------------------------------------------------------------------------

class TestDataSegregation:
    """Verify that build_report always stamps the correct entity_code."""

    def test_sg_report_carries_sg_entity(self, config_dir):
        _write_config(config_dir, "SG")
        cfg = risk_report.load_entity_config("SG")
        report = risk_report.build_report("P1", Decimal("300000"), cfg)
        assert report["entity_code"] == "SG"

    def test_hk_report_carries_hk_entity(self, config_dir):
        _write_config(config_dir, "HK", {
            "suitability_framework": "SFC_COP_2019",
        })
        cfg = risk_report.load_entity_config("HK")
        report = risk_report.build_report("P2", Decimal("300000"), cfg)
        assert report["entity_code"] == "HK"

    def test_ch_report_carries_ch_entity(self, config_dir):
        _write_config(config_dir, "CH", {
            "suitability_framework": "FINMA_LSFin_2020",
        })
        cfg = risk_report.load_entity_config("CH")
        report = risk_report.build_report("P3", Decimal("300000"), cfg)
        assert report["entity_code"] == "CH"

    def test_no_cross_entity_leakage(self, config_dir):
        """Two configs loaded serially must not contaminate each other."""
        _write_config(config_dir, "SG")
        _write_config(config_dir, "HK", {
            "currency": "HKD",
            "suitability_framework": "SFC_COP_2019",
        })
        sg = risk_report.load_entity_config("SG")
        hk = risk_report.load_entity_config("HK")
        assert sg.currency == "SGD"
        assert hk.currency == "HKD"
        r_sg = risk_report.build_report("P1", Decimal("300000"), sg)
        r_hk = risk_report.build_report("P2", Decimal("300000"), hk)
        assert r_sg["currency"] == "SGD"
        assert r_hk["currency"] == "HKD"
        assert r_sg["entity_code"] != r_hk["entity_code"]


# ---------------------------------------------------------------------------
# Init / module-level state
# ---------------------------------------------------------------------------

class TestModuleInit:
    def test_init_sets_module_entity(self, config_dir):
        _write_config(config_dir, "SG")
        with mock.patch.dict(os.environ, {"ENTITY_ID": "SG"}):
            cfg = risk_report.init()
            assert cfg.entity_id == "SG"
            assert risk_report.get_entity().entity_id == "SG"

    def test_get_entity_lazy_loads(self, config_dir):
        _write_config(config_dir, "SG")
        with mock.patch.dict(os.environ, {"ENTITY_ID": "SG"}):
            risk_report._entity = None
            cfg = risk_report.get_entity()
            assert cfg.entity_id == "SG"
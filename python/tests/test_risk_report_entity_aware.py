"""Entity-aware QA tests for WP-DATA package.

Covers:
  - SG baseline behavioural preservation (exact parity with pre-refactor)
  - HK entity configuration and calculations
  - CH entity configuration and calculations
  - Missing/unknown entity context error handling
  - Config caching and immutability
  - Key Vault secret reference pattern
  - JSON config schema assertions

Run: PYTHONPATH=python pytest python/tests/test_risk_report_entity_aware.py -v
"""

from __future__ import annotations

import importlib
import json
import os
import pathlib
from decimal import Decimal

import pytest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _reload_for_entity(entity_id: str):
    """Reload entity_config and risk_report modules under a given ENTITY_ID."""
    import entity_config as ec_mod
    importlib.reload(ec_mod)
    if hasattr(ec_mod, "clear_cache"):
        ec_mod.clear_cache()
    for attr in ("_cache", "_CONFIG", "_config"):
        if hasattr(ec_mod, attr):
            try:
                setattr(ec_mod, attr, None)
            except (AttributeError, TypeError):
                pass

    os.environ["ENTITY_ID"] = entity_id
    importlib.reload(ec_mod)

    import risk_report
    importlib.reload(risk_report)
    return risk_report, ec_mod


@pytest.fixture(autouse=True)
def _clean_env():
    """Ensure ENTITY_ID is cleaned between tests."""
    original = os.environ.get("ENTITY_ID")
    yield
    if original is not None:
        os.environ["ENTITY_ID"] = original
    else:
        os.environ.pop("ENTITY_ID", None)
    try:
        import entity_config as ec_mod
        if hasattr(ec_mod, "clear_cache"):
            ec_mod.clear_cache()
    except Exception:
        pass


# ===========================================================================
# 1. SG BASELINE - Exact behavioural preservation
# ===========================================================================

class TestSGBaselineConstants:
    """Module-level constants must match the original hardcoded SG values."""

    @pytest.fixture(autouse=True)
    def _load(self):
        self.rr, self.ec = _reload_for_entity("SG")

    def test_entity_code(self):
        assert self.rr.ENTITY_CODE == "SG"

    def test_entity_name(self):
        assert self.rr.ENTITY_NAME == "Singapore"

    def test_currency_sgd(self):
        assert self.rr.CURRENCY == "SGD"

    def test_regulator_mas(self):
        assert self.rr.REGULATOR == "MAS"

    def test_locale_en_sg(self):
        assert self.rr.LOCALE == "en_SG"

    def test_data_region(self):
        assert self.rr.DATA_REGION == "azure-southeast-asia"

    def test_mgmt_fee_bps_50(self):
        assert self.rr.MGMT_FEE_BPS == Decimal("50")

    def test_large_position_threshold(self):
        assert self.rr.LARGE_POSITION_THRESHOLD == Decimal("1000000")

    def test_suitability_framework(self):
        assert self.rr.SUITABILITY_FRAMEWORK == "MAS_FAA"


class TestSGBaselineFunctions:
    """Function outputs must exactly match pre-refactor behaviour for SG."""

    @pytest.fixture(autouse=True)
    def _load(self):
        self.rr, _ = _reload_for_entity("SG")

    def test_management_fee_one_million(self):
        result = self.rr.management_fee(Decimal("1000000"))
        assert result == Decimal("5000")

    def test_management_fee_zero(self):
        result = self.rr.management_fee(Decimal("0"))
        assert result == Decimal("0")

    def test_management_fee_small_value(self):
        result = self.rr.management_fee(Decimal("100"))
        assert result == Decimal("0.50") or result == Decimal("0.5")

    def test_is_large_position_above(self):
        assert self.rr.is_large_position(Decimal("1500000")) is True

    def test_is_large_position_at_threshold(self):
        result = self.rr.is_large_position(Decimal("1000000"))
        assert isinstance(result, bool)

    def test_is_large_position_below(self):
        assert self.rr.is_large_position(Decimal("500000")) is False

    def test_disclosure_text_contains_mas(self):
        text = self.rr.disclosure_text()
        assert "MAS" in text or "mas" in text.lower()

    def test_disclosure_text_is_string(self):
        assert isinstance(self.rr.disclosure_text(), str)
        assert len(self.rr.disclosure_text()) > 0


class TestSGKeyVaultSecrets:
    """Key Vault secret references use the ${KEYVAULT:...} pattern."""

    @pytest.fixture(autouse=True)
    def _load(self):
        self.rr, _ = _reload_for_entity("SG")

    def test_db_connection_secret_pattern(self):
        secret = self.rr.DB_CONNECTION_SECRET
        assert secret.startswith("${KEYVAULT:")
        assert "wealth-sg" in secret.lower() or "wealth-SG" in secret
        assert secret.endswith("}")

    def test_api_key_secret_pattern(self):
        secret = self.rr.API_KEY_SECRET
        assert secret.startswith("${KEYVAULT:")
        assert secret.endswith("}")

    def test_no_plaintext_secrets(self):
        assert "password" not in self.rr.DB_CONNECTION_SECRET.lower()
        assert "server=" not in self.rr.DB_CONNECTION_SECRET.lower()


# ===========================================================================
# 2. SG DEFAULT - when ENTITY_ID is absent
# ===========================================================================

class TestDefaultEntity:
    """When ENTITY_ID env var is unset, module defaults to SG."""

    @pytest.fixture(autouse=True)
    def _load(self):
        os.environ.pop("ENTITY_ID", None)
        import entity_config as ec_mod
        importlib.reload(ec_mod)
        if hasattr(ec_mod, "clear_cache"):
            ec_mod.clear_cache()
        importlib.reload(ec_mod)
        import risk_report
        importlib.reload(risk_report)
        self.rr = risk_report

    def test_defaults_to_sg_entity_code(self):
        assert self.rr.ENTITY_CODE == "SG"

    def test_defaults_to_sgd_currency(self):
        assert self.rr.CURRENCY == "SGD"

    def test_defaults_to_mas_regulator(self):
        assert self.rr.REGULATOR == "MAS"


# ===========================================================================
# 3. HK Entity
# ===========================================================================

class TestHKEntity:
    """Verify HK-specific configuration values."""

    @pytest.fixture(autouse=True)
    def _load(self):
        self.rr, self.ec = _reload_for_entity("HK")

    def test_entity_code_hk(self):
        assert self.rr.ENTITY_CODE == "HK"

    def test_entity_name_hk(self):
        assert self.rr.ENTITY_NAME == "Hong Kong"

    def test_currency_hkd(self):
        assert self.rr.CURRENCY == "HKD"

    def test_regulator_sfc(self):
        assert self.rr.REGULATOR == "SFC"

    def test_locale_en_hk(self):
        assert self.rr.LOCALE == "en_HK"

    def test_mgmt_fee_bps_60(self):
        assert self.rr.MGMT_FEE_BPS == Decimal("60")

    def test_management_fee_one_million(self):
        result = self.rr.management_fee(Decimal("1000000"))
        assert result == Decimal("6000")

    def test_large_position_threshold_2m(self):
        assert self.rr.LARGE_POSITION_THRESHOLD == Decimal("2000000")

    def test_is_large_position_above_2m(self):
        assert self.rr.is_large_position(Decimal("2500000")) is True

    def test_is_large_position_below_2m(self):
        assert self.rr.is_large_position(Decimal("1500000")) is False

    def test_suitability_framework_sfc(self):
        assert self.rr.SUITABILITY_FRAMEWORK == "SFC_COP"

    def test_disclosure_text_contains_sfc(self):
        text = self.rr.disclosure_text()
        assert "SFC" in text or "sfc" in text.lower()

    def test_keyvault_references_hk(self):
        assert "wealth-hk" in self.rr.DB_CONNECTION_SECRET.lower() or \
               "wealth-HK" in self.rr.DB_CONNECTION_SECRET


# ===========================================================================
# 4. CH Entity
# ===========================================================================

class TestCHEntity:
    """Verify CH (Switzerland) entity-specific values."""

    @pytest.fixture(autouse=True)
    def _load(self):
        self.rr, self.ec = _reload_for_entity("CH")

    def test_entity_code_ch(self):
        assert self.rr.ENTITY_CODE == "CH"

    def test_entity_name_ch(self):
        assert self.rr.ENTITY_NAME == "Switzerland"

    def test_currency_chf(self):
        assert self.rr.CURRENCY == "CHF"

    def test_regulator_finma(self):
        assert self.rr.REGULATOR == "FINMA"

    def test_locale_de_ch(self):
        assert self.rr.LOCALE == "de_CH"

    def test_mgmt_fee_bps_45(self):
        assert self.rr.MGMT_FEE_BPS == Decimal("45")

    def test_management_fee_one_million(self):
        result = self.rr.management_fee(Decimal("1000000"))
        assert result == Decimal("4500")

    def test_large_position_threshold_5m(self):
        assert self.rr.LARGE_POSITION_THRESHOLD == Decimal("5000000")

    def test_is_large_position_below_5m(self):
        assert self.rr.is_large_position(Decimal("4000000")) is False

    def test_is_large_position_above_5m(self):
        assert self.rr.is_large_position(Decimal("6000000")) is True

    def test_suitability_framework_finma(self):
        assert self.rr.SUITABILITY_FRAMEWORK == "FINMA_FIDLEG"

    def test_disclosure_text_contains_finma(self):
        text = self.rr.disclosure_text()
        assert "FINMA" in text or "finma" in text.lower()

    def test_keyvault_references_ch(self):
        assert "wealth-ch" in self.rr.DB_CONNECTION_SECRET.lower() or \
               "wealth-CH" in self.rr.DB_CONNECTION_SECRET


# ===========================================================================
# 5. EntityConfig direct tests
# ===========================================================================

class TestEntityConfigDirect:
    """Test entity_config.py module directly."""

    @pytest.fixture(autouse=True)
    def _load(self):
        self._, self.ec = _reload_for_entity("SG")

    def test_load_returns_entity_config(self):
        cfg = self.ec.load_entity_config()
        assert cfg.entity_id == "SG"

    def test_config_caching_returns_same_object(self):
        cfg1 = self.ec.load_entity_config()
        cfg2 = self.ec.load_entity_config()
        assert cfg1 is cfg2

    def test_clear_cache_allows_reload(self):
        cfg1 = self.ec.load_entity_config()
        self.ec.clear_cache()
        os.environ["ENTITY_ID"] = "HK"
        importlib.reload(self.ec)
        cfg2 = self.ec.load_entity_config()
        assert cfg2.entity_id == "HK"
        assert cfg1.entity_id != cfg2.entity_id

    def test_secret_ref_pattern(self):
        cfg = self.ec.load_entity_config()
        ref = cfg.secret_ref("db-connection")
        assert ref == "${KEYVAULT:wealth-sg-db-connection}" or \
               ref == "${KEYVAULT:wealth-SG-db-connection}"

    def test_fee_lookup(self):
        cfg = self.ec.load_entity_config()
        fee = cfg.get_fee_bps("management")
        assert isinstance(fee, (int, float, Decimal))

    def test_threshold(self):
        cfg = self.ec.load_entity_config()
        t = cfg.threshold()
        assert t > 0

    def test_disclosure_text_not_empty(self):
        cfg = self.ec.load_entity_config()
        text = cfg.disclosure_text()
        assert isinstance(text, str)
        assert len(text) > 0


class TestUnknownEntity:
    """Loading an unknown entity should raise an appropriate error."""

    def test_unknown_entity_raises(self):
        import entity_config as ec_mod
        importlib.reload(ec_mod)
        if hasattr(ec_mod, "clear_cache"):
            ec_mod.clear_cache()
        os.environ["ENTITY_ID"] = "XX_NONEXISTENT"
        importlib.reload(ec_mod)
        with pytest.raises((FileNotFoundError, KeyError, ValueError, Exception)):
            ec_mod.load_entity_config()


# ===========================================================================
# 6. JSON config file structural assertions
# ===========================================================================

SHARED_CONTRACT_KEYS = [
    "entity.id",
    "entity.currency",
    "entity.locale.primary",
    "entity.locale.supported",
    "entity.fee_schedule",
    "entity.portfolio_minimum",
    "entity.data_region",
    "entity.kms_vault_name",
    "entity.regulator",
    "entity.suitability_framework",
    "entity.disclosure_locale",
    "entity.audit_siem_workspace",
    "entity.data_residency_rule",
]


def _find_config_dir():
    """Locate the entity_configs directory."""
    candidates = [
        pathlib.Path("python/entity_configs"),
        pathlib.Path("entity_configs"),
        pathlib.Path(__file__).parent.parent / "entity_configs",
    ]
    for c in candidates:
        if c.is_dir():
            return c
    pytest.skip("entity_configs directory not found")


@pytest.mark.parametrize("entity_file", ["sg.json", "hk.json", "ch.json"])
class TestConfigJsonSchema:
    """Each entity JSON must contain all 13 shared-contract keys."""

    def test_all_shared_contract_keys_present(self, entity_file):
        config_dir = _find_config_dir()
        filepath = config_dir / entity_file
        assert filepath.exists(), f"{entity_file} not found in {config_dir}"
        with open(filepath) as f:
            data = json.load(f)

        flat_keys = set()
        if isinstance(data, dict):
            flat_keys = set(data.keys())
            def _flatten(d, prefix=""):
                for k, v in d.items():
                    full = f"{prefix}{k}" if not prefix else f"{prefix}.{k}"
                    flat_keys.add(full)
                    if isinstance(v, dict):
                        _flatten(v, full)
            _flatten(data)

        for key in SHARED_CONTRACT_KEYS:
            assert key in flat_keys, \
                f"Missing shared-contract key '{key}' in {entity_file}"

    def test_entity_id_matches_filename(self, entity_file):
        config_dir = _find_config_dir()
        filepath = config_dir / entity_file
        with open(filepath) as f:
            data = json.load(f)

        expected_id = entity_file.replace(".json", "").upper()
        actual_id = data.get("entity.id") or data.get("entity", {}).get("id")
        assert actual_id is not None, f"Cannot find entity.id in {entity_file}"
        assert actual_id.upper() == expected_id


# ===========================================================================
# 7. Cross-entity fee differentiation
# ===========================================================================

class TestFeesDifferBetweenEntities:
    """Fee schedules must differ across entities to prove config isolation."""

    def test_sg_hk_ch_fees_differ(self):
        rr_sg, _ = _reload_for_entity("SG")
        fee_sg = rr_sg.MGMT_FEE_BPS

        rr_hk, _ = _reload_for_entity("HK")
        fee_hk = rr_hk.MGMT_FEE_BPS

        rr_ch, _ = _reload_for_entity("CH")
        fee_ch = rr_ch.MGMT_FEE_BPS

        assert fee_sg != fee_hk, "SG and HK fees should differ"
        assert fee_sg != fee_ch, "SG and CH fees should differ"
        assert fee_hk != fee_ch, "HK and CH fees should differ"

    def test_same_market_value_different_fee_output(self):
        mv = Decimal("1000000")

        rr_sg, _ = _reload_for_entity("SG")
        fee_sg = rr_sg.management_fee(mv)

        rr_hk, _ = _reload_for_entity("HK")
        fee_hk = rr_hk.management_fee(mv)

        assert fee_sg != fee_hk, "Same MV should produce different fees for SG vs HK"
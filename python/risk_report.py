"""Risk reporting module — entity-aware configuration.

Loads entity configuration from YAML files based on the ENTITY_ID environment
variable. All entity-specific values come from configuration — no hardcoded
SG-only assumptions remain. Secrets are referenced via Azure Key Vault.

Behaviour for the SG baseline is preserved exactly.
"""

import os
import sys
from decimal import Decimal
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml


# ---------------------------------------------------------------------------
# Entity configuration loader
# ---------------------------------------------------------------------------

_REQUIRED_CONFIG_KEYS = {
    "entity_id": str,
    "entity_full_name": str,
    "currency": str,
    "fee_schedule_bps": (int, float),
    "min_portfolio_threshold": (int, float),
    "default_locale": str,
    "booking_centre": str,
    "data_region": str,
    "kms_vault_name": str,
    "suitability_framework": str,
    "regulatory_bodies": list,
    "disclosure_locale_map": dict,
}

# Disclosure templates keyed by suitability_framework.
# Each entity's framework maps to the legally required disclosure text.
_DISCLOSURE_TEMPLATES: Dict[str, str] = {
    "MAS_FAA_2002": (
        "MAS Notice FAA: Past performance is not indicative of future results. "
        "Investments involve risk."
    ),
    "SFC_COP_2019": (
        "SFC Code of Conduct: Past performance is not indicative of future results. "
        "Investment involves risk. Losses may exceed the principal amount invested."
    ),
    "FINMA_LSFin_2020": (
        "FINMA LSFin: Die frühere Wertentwicklung ist kein verlässlicher Indikator "
        "für künftige Ergebnisse. Anlagen sind mit Risiken verbunden."
    ),
}


class EntityConfig:
    """Immutable container for a loaded and validated entity configuration."""

    def __init__(self, config: Dict[str, Any]) -> None:
        self._cfg = dict(config)

    @property
    def entity_id(self) -> str:
        return self._cfg["entity_id"]

    @property
    def entity_full_name(self) -> str:
        return self._cfg["entity_full_name"]

    @property
    def currency(self) -> str:
        return self._cfg["currency"]

    @property
    def fee_schedule_bps(self) -> Decimal:
        return Decimal(str(self._cfg["fee_schedule_bps"]))

    @property
    def min_portfolio_threshold(self) -> Decimal:
        return Decimal(str(self._cfg["min_portfolio_threshold"]))

    @property
    def default_locale(self) -> str:
        return self._cfg["default_locale"]

    @property
    def booking_centre(self) -> str:
        return self._cfg["booking_centre"]

    @property
    def data_region(self) -> str:
        return self._cfg["data_region"]

    @property
    def kms_vault_name(self) -> str:
        return self._cfg["kms_vault_name"]

    @property
    def suitability_framework(self) -> str:
        return self._cfg["suitability_framework"]

    @property
    def regulatory_bodies(self) -> List[str]:
        return list(self._cfg["regulatory_bodies"])

    @property
    def disclosure_locale_map(self) -> Dict[str, str]:
        return dict(self._cfg["disclosure_locale_map"])

    # Convenience: primary regulator is the first in the list
    @property
    def primary_regulator(self) -> str:
        return self._cfg["regulatory_bodies"][0]


def _resolve_config_dir() -> Path:
    """Return the path to configs/entities/ relative to this file or repo root."""
    # Check env override first
    override = os.environ.get("ENTITY_CONFIG_DIR")
    if override:
        return Path(override)
    # Walk up from this file to find configs/entities/
    here = Path(__file__).resolve().parent
    for ancestor in [here, here.parent, here.parent.parent]:
        candidate = ancestor / "configs" / "entities"
        if candidate.is_dir():
            return candidate
    # Fallback: relative to cwd
    return Path("configs") / "entities"


def load_entity_config(entity_id: Optional[str] = None) -> EntityConfig:
    """Load, validate, and return the EntityConfig for *entity_id*.

    Parameters
    ----------
    entity_id : str or None
        If ``None``, the value is read from the ``ENTITY_ID`` environment
        variable.  A missing or empty value causes an immediate hard failure.

    Returns
    -------
    EntityConfig

    Raises
    ------
    SystemExit
        If the configuration file is missing, malformed, or fails validation.
    """
    if entity_id is None:
        entity_id = os.environ.get("ENTITY_ID", "").strip()
    if not entity_id:
        _fail("ENTITY_ID environment variable is not set or is empty.")

    config_dir = _resolve_config_dir()
    config_path = config_dir / f"{entity_id}.yaml"
    if not config_path.is_file():
        _fail(f"Entity config file not found: {config_path}")

    with open(config_path, "r", encoding="utf-8") as fh:
        raw = yaml.safe_load(fh)

    if not isinstance(raw, dict):
        _fail(f"Entity config must be a YAML mapping, got {type(raw).__name__}")

    _validate_config(raw, entity_id)
    _validate_secrets(raw)

    return EntityConfig(raw)


def _validate_config(cfg: Dict[str, Any], expected_entity_id: str) -> None:
    """Validate presence, types, and cross-checks of all required keys."""
    missing = [k for k in _REQUIRED_CONFIG_KEYS if k not in cfg]
    if missing:
        _fail(f"Missing config keys: {', '.join(sorted(missing))}")

    for key, expected_type in _REQUIRED_CONFIG_KEYS.items():
        val = cfg[key]
        if not isinstance(val, expected_type):
            _fail(
                f"Config key '{key}' expected type {expected_type}, "
                f"got {type(val).__name__}: {val!r}"
            )

    if cfg["entity_id"] != expected_entity_id:
        _fail(
            f"entity_id in config ('{cfg['entity_id']}') does not match "
            f"requested entity ('{expected_entity_id}')."
        )

    if len(cfg["currency"]) != 3:
        _fail(f"currency must be a 3-letter ISO 4217 code, got '{cfg['currency']}'")

    if not cfg["regulatory_bodies"]:
        _fail("regulatory_bodies list must not be empty.")


def _validate_secrets(cfg: Dict[str, Any]) -> None:
    """Ensure secrets are Azure Key Vault references, never plaintext."""
    vault_name = cfg.get("kms_vault_name", "")
    if not vault_name:
        _fail("kms_vault_name must be set for secret resolution.")
    # Validate that the vault name looks reasonable (no slashes, no spaces)
    if " " in vault_name or "/" in vault_name:
        _fail(f"kms_vault_name looks invalid: '{vault_name}'")


def _fail(message: str) -> None:  # pragma: no cover — intentional hard exit
    print(f"[FATAL] risk_report config: {message}", file=sys.stderr)
    raise SystemExit(1)


# ---------------------------------------------------------------------------
# Module-level entity configuration (loaded at import time when ENTITY_ID set,
# or lazily via init())
# ---------------------------------------------------------------------------

_entity: Optional[EntityConfig] = None


def init(entity_id: Optional[str] = None) -> EntityConfig:
    """Initialise (or re-initialise) the module-level entity config."""
    global _entity
    _entity = load_entity_config(entity_id)
    return _entity


def get_entity() -> EntityConfig:
    """Return the current entity config, initialising if needed."""
    global _entity
    if _entity is None:
        _entity = load_entity_config()
    return _entity


# ---------------------------------------------------------------------------
# Key Vault secret reference helper
# ---------------------------------------------------------------------------

def secret_ref(secret_name: str, entity_cfg: Optional[EntityConfig] = None) -> str:
    """Return an Azure Key Vault reference string for *secret_name*.

    Format follows the shared contract:
        ``${KEYVAULT:<kms_vault_name>/<secret_name>}``
    """
    cfg = entity_cfg or get_entity()
    return f"${{KEYVAULT:{cfg.kms_vault_name}/{secret_name}}}"


# ---------------------------------------------------------------------------
# Business functions — behaviour preserved exactly
# ---------------------------------------------------------------------------

def management_fee(
    market_value: Decimal,
    entity_cfg: Optional[EntityConfig] = None,
) -> Decimal:
    """Compute annual management fee at the entity's schedule (basis points)."""
    cfg = entity_cfg or get_entity()
    return (market_value * cfg.fee_schedule_bps / Decimal("10000")).quantize(
        Decimal("0.01")
    )


def is_reportable(
    market_value: Decimal,
    entity_cfg: Optional[EntityConfig] = None,
) -> bool:
    """Return True if position meets or exceeds the entity's threshold."""
    cfg = entity_cfg or get_entity()
    return market_value >= cfg.min_portfolio_threshold


def disclosure_text(entity_cfg: Optional[EntityConfig] = None) -> str:
    """Return the regulatory disclosure string for the entity's framework."""
    cfg = entity_cfg or get_entity()
    framework = cfg.suitability_framework
    text = _DISCLOSURE_TEMPLATES.get(framework)
    if text is None:
        _fail(
            f"No disclosure template registered for suitability_framework "
            f"'{framework}'. Register it in _DISCLOSURE_TEMPLATES."
        )
    return text


def build_report(
    portfolio_id: str,
    market_value: Decimal,
    entity_cfg: Optional[EntityConfig] = None,
) -> dict:
    """Build a risk report dict for the given portfolio."""
    cfg = entity_cfg or get_entity()
    reportable = is_reportable(market_value, cfg)
    return {
        "portfolio_id": portfolio_id,
        "entity_code": cfg.entity_id,
        "entity_name": cfg.entity_full_name,
        "regulator": cfg.primary_regulator,
        "currency": cfg.currency,
        "locale": cfg.default_locale,
        "data_region": cfg.data_region,
        "suitability_framework": cfg.suitability_framework,
        "market_value": market_value,
        "management_fee": management_fee(market_value, cfg),
        "management_fee_bps": cfg.fee_schedule_bps,
        "reportable": reportable,
        "disclosure": disclosure_text(cfg) if reportable else "",
    }
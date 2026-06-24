"""Risk reporting module — entity-aware configuration.

Entity context is resolved at module load time from the ENTITY_ID
environment variable (default: SG). All constants are sourced from
per-entity YAML config files under python/entities/.
"""

import os
from decimal import Decimal
from pathlib import Path

import yaml

_ALLOWED_ENTITIES = frozenset({"SG", "HK", "CH"})

_entity_id = os.environ.get("ENTITY_ID", "SG").upper()
if _entity_id not in _ALLOWED_ENTITIES:
    raise ValueError(
        f"Invalid ENTITY_ID '{_entity_id}'. Allowed: {sorted(_ALLOWED_ENTITIES)}"
    )

_CONFIG_DIR = Path(__file__).resolve().parent / "entities"
_config_path = _CONFIG_DIR / f"{_entity_id}.yaml"
if not _config_path.exists():
    raise FileNotFoundError(f"Entity config not found: {_config_path}")

with open(_config_path, "r") as _f:
    _cfg = yaml.safe_load(_f)

# --- Module-level symbols (contract) ---
CURRENCY: str = _cfg["currency"]
LOCALE: str = _cfg["locale"]
REGULATOR: str = _cfg["regulator"]
BOOKING_CENTRE: str = _cfg["booking_centre"]
MGMT_FEE_BPS: Decimal = Decimal(str(_cfg["fee_bps"]))
LARGE_POSITION_THRESHOLD: Decimal = Decimal(str(_cfg["large_position_threshold"]))
SUITABILITY_FRAMEWORK: str = _cfg["suitability_framework"]
DB_CONNECTION_SECRET: str = (
    f"${{KEYVAULT:{_cfg['kms_vault_name']}-db-connection-string}}"
)

# Internal extras from config
_ENTITY_CODE: str = _cfg["entity_id"]
_DATA_REGION: str = _cfg["data_region"]
_DISCLOSURE_LOCALE: str = _cfg["disclosure_locale"]
_AUDIT_TRAIL_ENABLED: bool = _cfg["audit_trail_enabled"]

# --- Disclosure texts per regulator ---
_DISCLOSURE_MAP = {
    "MAS": (
        "MAS Notice FAA: Past performance is not indicative of future "
        "results. Investments involve risk."
    ),
    "SFC": (
        "SFC COP: Past performance is not indicative of future results. "
        "Investments involve risk."
    ),
    "FINMA": (
        "FINMA LSFin: Past performance is not indicative of future results. "
        "Investments involve risk."
    ),
}


def is_large_position(value: Decimal) -> bool:
    """Return True if value >= entity large-position threshold."""
    return value >= LARGE_POSITION_THRESHOLD


# Backward-compatible alias
is_reportable = is_large_position


def management_fee(notional: Decimal) -> Decimal:
    """Compute annual management fee at the entity schedule."""
    return (notional * MGMT_FEE_BPS / Decimal("10000")).quantize(Decimal("0.01"))


def disclosure_text() -> str:
    """Return regulator-appropriate disclosure string."""
    return _DISCLOSURE_MAP.get(REGULATOR, "")


def build_report(portfolio_id: str, market_value: Decimal) -> dict:
    """Build a risk report dict for the given portfolio."""
    reportable = is_large_position(market_value)
    return {
        "portfolio_id": portfolio_id,
        "entity_code": _ENTITY_CODE,
        "entity_name": BOOKING_CENTRE,
        "regulator": REGULATOR,
        "currency": CURRENCY,
        "locale": LOCALE,
        "data_region": _DATA_REGION,
        "suitability_framework": SUITABILITY_FRAMEWORK,
        "market_value": market_value,
        "management_fee": management_fee(market_value),
        "management_fee_bps": MGMT_FEE_BPS,
        "reportable": reportable,
        "disclosure": disclosure_text() if reportable else "",
    }
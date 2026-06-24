"""Risk reporting module — entity-aware multi-jurisdiction deployment.

Loads entity configuration from python/entities/<ENTITY_ID>.yaml at module
load time. Defaults to SG when ENTITY_ID is not set, preserving all
existing Singapore behaviour exactly.
"""

import os
from decimal import Decimal
from pathlib import Path

import yaml

_ENTITIES_DIR = Path(__file__).parent / "entities"
_VALID_ENTITIES = {"SG", "HK", "CH"}


def _load_entity_config(entity_id: str) -> dict:
    """Load and return the YAML config for entity_id. Raises on bad input."""
    if entity_id not in _VALID_ENTITIES:
        raise ValueError(
            f"ENTITY_ID '{entity_id}' is not one of {sorted(_VALID_ENTITIES)}. "
            "System cannot proceed."
        )
    config_path = _ENTITIES_DIR / f"{entity_id}.yaml"
    if not config_path.exists():
        raise FileNotFoundError(
            f"Entity config file not found: {config_path}. System cannot proceed."
        )
    with config_path.open("r", encoding="utf-8") as fh:
        cfg = yaml.safe_load(fh)
    if cfg.get("entity_id") != entity_id:
        raise ValueError(
            f"entity_id mismatch: file declares '{cfg.get('entity_id')}' "
            f"but ENTITY_ID env var is '{entity_id}'. System cannot proceed."
        )
    return cfg


_ENTITY_ID: str = os.environ.get("ENTITY_ID", "SG").strip().upper()
_CFG: dict = _load_entity_config(_ENTITY_ID)

ENTITY_CODE: str = _CFG["entity_id"]
ENTITY_NAME: str = _CFG["booking_centre"]
CURRENCY: str = _CFG["currency"]
LOCALE: str = _CFG["locales"][0]
REGULATOR: str = _CFG["regulators"][0]
BOOKING_CENTRE: str = _CFG["booking_centre"]
MGMT_FEE_BPS: Decimal = Decimal(str(_CFG["fee_bps"]))
LARGE_POSITION_THRESHOLD: Decimal = Decimal(str(_CFG["large_position_threshold"]))
SUITABILITY_FRAMEWORK: str = _CFG["suitability_framework"]
DATA_REGION: str = _CFG["data_region"]
DB_CONNECTION_SECRET: str = _CFG["kv_db_secret_name"]


def management_fee(notional: Decimal) -> Decimal:
    """Compute annual management fee for this entity's fee schedule."""
    return (notional * MGMT_FEE_BPS / Decimal("10000")).quantize(Decimal("0.01"))


def is_large_position(value: Decimal) -> bool:
    """Return True if value >= LARGE_POSITION_THRESHOLD."""
    return value >= LARGE_POSITION_THRESHOLD


def is_reportable(market_value: Decimal) -> bool:
    """Backward-compat alias for is_large_position."""
    return is_large_position(market_value)


def disclosure_text() -> str:
    """Return the regulator disclosure string for reportable positions."""
    return (
        f"{SUITABILITY_FRAMEWORK}: Past performance is not indicative of "
        "future results. Investments involve risk."
    )


def build_report(portfolio_id: str, market_value: Decimal) -> dict:
    """Build a risk report dict for the given portfolio and active entity."""
    reportable = is_reportable(market_value)
    return {
        "portfolio_id": portfolio_id,
        "entity_code": ENTITY_CODE,
        "entity_name": ENTITY_NAME,
        "regulator": REGULATOR,
        "currency": CURRENCY,
        "locale": LOCALE,
        "data_region": DATA_REGION,
        "suitability_framework": SUITABILITY_FRAMEWORK,
        "market_value": market_value,
        "management_fee": management_fee(market_value),
        "management_fee_bps": MGMT_FEE_BPS,
        "reportable": reportable,
        "disclosure": disclosure_text() if reportable else "",
    }
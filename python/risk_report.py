"""Risk reporting module — entity-aware, driven by WEALTH_ENTITY env var (default: SG)."""

import os
from decimal import Decimal
from pathlib import Path

import yaml

_ENTITY_ID = os.environ.get("WEALTH_ENTITY", "SG").upper()
_CONFIG_DIR = Path(__file__).parent / "entities"


def _load_config(entity_id: str) -> dict:
    config_path = _CONFIG_DIR / f"{entity_id.lower()}.yaml"
    if not config_path.exists():
        raise FileNotFoundError(f"Entity config not found: {config_path}")
    with config_path.open() as fh:
        return yaml.safe_load(fh)


_cfg = _load_config(_ENTITY_ID)
_entity = _cfg["entity"]
_locale_cfg = _cfg["locale"]
_regulatory = _cfg["regulatory"]
_product = _cfg["product_rules"]
_infra = _cfg["infrastructure"]

# ---------------------------------------------------------------------------
# Required module-level symbols (contract: WP-PYTHON)
# ---------------------------------------------------------------------------
CURRENCY: str = _locale_cfg["currency"]
LOCALE: str = _locale_cfg["default_locale"]
REGULATOR: str = _regulatory["regulators"][0]
BOOKING_CENTRE: str = _entity["booking_centre"]
MGMT_FEE_BPS: Decimal = Decimal(str(_product["advisory_fee_bps"]))
LARGE_POSITION_THRESHOLD: Decimal = Decimal(str(_product["onboarding_threshold_minor_units"]))
SUITABILITY_FRAMEWORK: str = _product["suitability_framework"]
DB_CONNECTION_SECRET: str = (
    "${KEYVAULT:" + _infra["kv_vault_uri"] + "}"
)

# Legacy aliases preserved for backward compatibility
ENTITY_CODE: str = _entity["entity_id"]
ENTITY_NAME: str = _entity["entity_name"]
DATA_REGION: str = _infra["azure_region"]


# ---------------------------------------------------------------------------
# Public functions
# ---------------------------------------------------------------------------

def management_fee(notional: Decimal) -> Decimal:
    """Compute annual management fee in entity currency."""
    return (notional * MGMT_FEE_BPS / Decimal("10000")).quantize(Decimal("0.01"))


def is_large_position(value: Decimal) -> bool:
    """Return True if value >= LARGE_POSITION_THRESHOLD."""
    return value >= LARGE_POSITION_THRESHOLD


# Backward-compat alias
def is_reportable(market_value: Decimal) -> bool:
    return is_large_position(market_value)


def disclosure_text() -> str:
    framework = SUITABILITY_FRAMEWORK
    regulator = REGULATOR
    return (
        f"{regulator} ({framework}): Past performance is not indicative of "
        "future results. Investments involve risk."
    )


def build_report(portfolio_id: str, market_value: Decimal) -> dict:
    reportable = is_large_position(market_value)
    return {
        "portfolio_id": portfolio_id,
        "entity_code": ENTITY_CODE,
        "entity_name": ENTITY_NAME,
        "regulator": REGULATOR,
        "currency": CURRENCY,
        "locale": LOCALE,
        "booking_centre": BOOKING_CENTRE,
        "data_region": DATA_REGION,
        "suitability_framework": SUITABILITY_FRAMEWORK,
        "market_value": market_value,
        "management_fee": management_fee(market_value),
        "management_fee_bps": MGMT_FEE_BPS,
        "reportable": reportable,
        "disclosure": disclosure_text() if reportable else "",
    }
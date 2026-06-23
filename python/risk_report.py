"""Risk reporting module \u2014 entity-aware.

Configuration is driven entirely by the ``ENTITY_ID`` environment variable
(defaulting to ``\"SG\"`` for backward compatibility).  Entity-specific values
are loaded from ``entity_configs/<id>.json`` via :mod:`entity_config`.

Backward compatibility
----------------------
The module-level constants ``ENTITY_CODE``, ``CURRENCY``, ``REGULATOR``,
``LOCALE``, ``DATA_REGION``, ``MGMT_FEE_BPS``, ``LARGE_POSITION_THRESHOLD``,
and ``SUITABILITY_FRAMEWORK`` are still exported.  They resolve from the
active entity config so that existing call-sites and tests continue to work
unchanged when ``ENTITY_ID=SG`` (the default).
"""

from __future__ import annotations

from decimal import Decimal

from entity_config import load_entity_config

# \u2500\u2500 Load entity configuration (immutable after bootstrap) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
_cfg = load_entity_config()  # reads ENTITY_ID env-var; defaults to "SG"

# \u2500\u2500 Backward-compatible module-level constants \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
ENTITY_CODE: str = _cfg.entity_id
ENTITY_NAME: str = {
    "SG": "Singapore",
    "HK": "Hong Kong",
    "CH": "Switzerland",
}.get(_cfg.entity_id, _cfg.entity_id)
REGULATOR: str = _cfg.regulator_primary
CURRENCY: str = _cfg.currency
LOCALE: str = _cfg.locale_primary
DATA_REGION: str = _cfg.data_region
MGMT_FEE_BPS: Decimal = _cfg.standard_fee_bps()
LARGE_POSITION_THRESHOLD: Decimal = _cfg.large_position_threshold()
SUITABILITY_FRAMEWORK: str = _cfg.suitability_framework

# \u2500\u2500 Secret references (never plaintext) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\nDB_CONNECTION_SECRET = _cfg.secret_ref("db-connection-string")
API_KEY_SECRET = _cfg.secret_ref("api-key")


def management_fee(market_value: Decimal) -> Decimal:
    """Compute annual management fee using the entity fee schedule."""
    return (market_value * MGMT_FEE_BPS / Decimal("10000")).quantize(Decimal("0.01"))


def is_reportable(market_value: Decimal) -> bool:
    """Return True if position meets or exceeds the entity large-position threshold."""
    return market_value >= LARGE_POSITION_THRESHOLD


def disclosure_text() -> str:
    """Return the regulator-specific disclosure string for reportable positions."""
    return _cfg.disclosure_text()


def build_report(portfolio_id: str, market_value: Decimal) -> dict:
    """Build a risk report dict for the given portfolio."""
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
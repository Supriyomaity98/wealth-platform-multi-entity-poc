"""Risk reporting module — multi-entity deployment.

Entity configuration is loaded at module start from YAML files in the
`entities/` directory.  The active entity is selected via the
ACME_ENTITY_ID environment variable (default: "SG" for backward
compatibility with the Singapore baseline).

Module-level symbols exposed for external consumers:
  CURRENCY, LOCALE, REGULATOR, BOOKING_CENTRE, MGMT_FEE_BPS,
  LARGE_POSITION_THRESHOLD, SUITABILITY_FRAMEWORK,
  DB_CONNECTION_SECRET, is_large_position(), management_fee()
"""

import os
from decimal import Decimal
from python.entity_context import EntityContext

_entity_id = os.environ.get("ACME_ENTITY_ID", "SG")
_ctx = EntityContext(_entity_id)

# --- Module-level symbols (required contract) --------------------------
CURRENCY: str = _ctx.currency
LOCALE: str = _ctx.locale
REGULATOR: str = _ctx.regulator
BOOKING_CENTRE: str = _ctx.booking_centre
MGMT_FEE_BPS: Decimal = _ctx.fee_bps
LARGE_POSITION_THRESHOLD: Decimal = _ctx.large_position_threshold
SUITABILITY_FRAMEWORK: str = _ctx.suitability_framework
DB_CONNECTION_SECRET: str = _ctx.db_connection_secret

# Legacy aliases kept for SG backward-compat
ENTITY_CODE: str = _ctx.entity_id
ENTITY_NAME: str = _ctx.booking_centre
DATA_REGION: str = _ctx.data_region


def is_large_position(value: Decimal) -> bool:
    """Return True when *value* meets or exceeds the entity threshold."""
    return value >= LARGE_POSITION_THRESHOLD


# Keep legacy name for SG baseline
is_reportable = is_large_position


def management_fee(notional: Decimal) -> Decimal:
    """Compute annual management fee using the entity fee schedule."""
    return (notional * MGMT_FEE_BPS / Decimal("10000")).quantize(Decimal("0.01"))


def disclosure_text() -> str:
    """Return entity-appropriate disclosure string."""
    _disclosures = {
        "MAS": (
            "MAS Notice FAA: Past performance is not indicative of "
            "future results. Investments involve risk."
        ),
        "SFC": (
            "SFC Code of Conduct: Past performance is not indicative "
            "of future results. Investments involve risk."
        ),
        "FINMA": (
            "FINMA LSFin: Past performance is not indicative of "
            "future results. Investments involve risk."
        ),
    }
    return _disclosures.get(REGULATOR, "")


def build_report(portfolio_id: str, market_value: Decimal) -> dict:
    """Build a risk report dict for the given portfolio."""
    reportable = is_large_position(market_value)
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
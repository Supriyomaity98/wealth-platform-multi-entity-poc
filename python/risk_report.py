"""Risk reporting module — Singapore deployment.

All module-level constants represent the live SG entity configuration.
These constants are the primary refactoring target for the multi-agent
workflow that will introduce entity-aware configuration for HK and CH.
"""

from decimal import Decimal

ENTITY_CODE = "SG"
ENTITY_NAME = "Singapore"
REGULATOR = "MAS"
CURRENCY = "SGD"
LOCALE = "en_SG"
DATA_REGION = "ap-southeast-1"
MGMT_FEE_BPS = Decimal("50")
LARGE_POSITION_THRESHOLD = Decimal("250000")
SUITABILITY_FRAMEWORK = "MAS-Notice-FAA"


def management_fee(market_value: Decimal) -> Decimal:
    """Compute annual management fee at the Singapore schedule (50 bps)."""
    return (market_value * MGMT_FEE_BPS / Decimal("10000")).quantize(Decimal("0.01"))


def is_reportable(market_value: Decimal) -> bool:
    """Return True if position exceeds the Singapore large-position threshold."""
    return market_value >= LARGE_POSITION_THRESHOLD


def disclosure_text() -> str:
    """Return the MAS Notice FAA disclosure string for reportable positions."""
    return (
        "MAS Notice FAA: Past performance is not indicative of future results. "
        "Investments involve risk."
    )


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

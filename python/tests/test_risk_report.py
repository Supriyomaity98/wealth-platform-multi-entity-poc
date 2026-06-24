from decimal import Decimal

import pytest

from risk_report import (
    CURRENCY,
    ENTITY_CODE,
    MGMT_FEE_BPS,
    REGULATOR,
    build_report,
    is_reportable,
    management_fee,
)


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
    assert "MAS Notice FAA" in report["disclosure"]

"""Entity-aware configuration loader.

Reads ENTITY_ID from the environment and loads the matching configuration
from ``entity_configs/``.  For the SG baseline every value is identical to
the former module-level constants in ``risk_report.py``.

Secrets follow the Azure Key Vault reference pattern:
    ${KEYVAULT:wealth-<entity>-<secret-name>}
"""

from __future__ import annotations

import json
import os
import pathlib
from decimal import Decimal
from typing import Any, Dict, List, Optional


_CONFIG_DIR = pathlib.Path(__file__).resolve().parent / "entity_configs"

# In-memory cache keyed by entity id
_cache: Dict[str, "EntityConfig"] = {}


class EntityConfig:
    """Immutable configuration container for a single entity."""

    def __init__(self, data: Dict[str, Any]) -> None:
        entity = data["entity"]
        self.entity_id: str = entity["id"]
        self.currency: str = entity["currency"]
        self.locale_primary: str = entity["locale"]["primary"]
        self.locale_supported: List[str] = entity["locale"]["supported"]
        self.fee_schedule: List[Dict[str, Any]] = entity["fee_schedule"]
        self.portfolio_minimum: Dict[str, Any] = entity["portfolio_minimum"]
        self.data_region: str = entity["data_region"]
        self.kms_vault_name: str = entity["kms_vault_name"]
        self.regulator: List[str] = entity["regulator"]
        self.suitability_framework: str = entity["suitability_framework"]
        self.disclosure_locale: List[str] = entity["disclosure_locale"]
        self.audit_siem_workspace: str = entity["audit_siem_workspace"]
        self.data_residency_rule: str = entity["data_residency_rule"]

        # Derived helpers used by risk_report
        self.regulator_primary: str = self.regulator[0]

    # ── Fee helpers ──────────────────────────────────────────────
    def standard_fee_bps(self) -> Decimal:
        """Return the fee_bps of the first 'standard' tier."""
        for tier in self.fee_schedule:
            if tier.get("tier") == "standard":
                return Decimal(str(tier["fee_bps"]))
        raise ValueError(f"No standard fee tier for entity {self.entity_id}")

    def large_position_threshold(self) -> Decimal:
        """Return portfolio_minimum amount as the large-position threshold."""
        return Decimal(str(self.portfolio_minimum["amount"]))

    # ── Disclosure helpers ───────────────────────────────────────
    def disclosure_text(self) -> str:
        """Return regulator-specific disclosure for reportable positions."""
        fw = self.suitability_framework
        if self.entity_id == "SG":
            return (
                "MAS Notice FAA: Past performance is not indicative of "
                "future results. Investments involve risk."
            )
        elif self.entity_id == "HK":
            return (
                f"{fw}: Past performance is not indicative of future results. "
                "Investments carry risks including possible loss of principal."
            )
        elif self.entity_id == "CH":
            return (
                f"{fw}: Vergangene Wertentwicklungen sind kein Indikator "
                "für zukünftige Ergebnisse. Anlagen sind mit Risiken verbunden."
            )
        # Generic fallback — always safe
        return (
            f"{fw}: Past performance is not indicative of future results. "
            "Investments involve risk."
        )

    # ── Secret reference helper ──────────────────────────────────
    def secret_ref(self, secret_name: str) -> str:
        """Return a Key Vault reference for the given secret name."""
        eid = self.entity_id.lower()
        return f"${{KEYVAULT:wealth-{eid}-{secret_name}}}"


def load_entity_config(entity_id: Optional[str] = None) -> EntityConfig:
    """Load and cache the entity configuration.

    Parameters
    ----------
    entity_id : str, optional
        If *None*, falls back to the ``ENTITY_ID`` environment variable.
        Defaults to ``"SG"`` when neither is provided (preserving baseline).
    """
    if entity_id is None:
        entity_id = os.environ.get("ENTITY_ID", "SG")

    entity_id = entity_id.upper()

    if entity_id in _cache:
        return _cache[entity_id]

    config_path = _CONFIG_DIR / f"{entity_id.lower()}.json"
    if not config_path.exists():
        raise FileNotFoundError(
            f"Entity config not found: {config_path}"
        )

    with open(config_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)

    cfg = EntityConfig(data)
    _cache[entity_id] = cfg
    return cfg


def clear_cache() -> None:
    """Clear the config cache \u2014 useful in tests."""
    _cache.clear()
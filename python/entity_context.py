"""Immutable entity context — loaded once per process from YAML."""

import os
from decimal import Decimal
from pathlib import Path

import yaml

_ENTITIES_DIR = Path(__file__).resolve().parent / "entities"


class EntityContext:
    """Immutable configuration holder for a single entity."""

    __slots__ = (
        "entity_id", "currency", "locale", "regulator",
        "booking_centre", "fee_bps", "large_position_threshold",
        "min_balance", "data_region", "kms_vault_name",
        "suitability_framework", "disclosure_locale",
        "audit_log_policy", "db_connection_secret",
    )

    def __init__(self, entity_id: str | None = None) -> None:
        eid = (entity_id or os.environ.get("ACME_ENTITY_ID", "SG")).upper()
        cfg_path = _ENTITIES_DIR / f"{eid}.yaml"
        if not cfg_path.exists():
            raise FileNotFoundError(
                f"No entity config for '{eid}' at {cfg_path}"
            )
        with open(cfg_path, "r") as fh:
            cfg = yaml.safe_load(fh)

        self.entity_id: str = cfg["entity_id"]
        self.currency: str = cfg["currency"]
        self.locale: str = cfg["locale"]
        self.regulator: str = cfg["regulator"]
        self.booking_centre: str = cfg.get("booking_centre", self.entity_id)
        self.fee_bps: Decimal = Decimal(str(cfg["fee_bps"]))
        self.large_position_threshold: Decimal = Decimal(
            str(cfg.get("large_position_threshold", 250000))
        )
        self.min_balance: Decimal = Decimal(
            str(cfg.get("min_balance", 0))
        )
        self.data_region: str = cfg["data_region"]
        self.kms_vault_name: str = cfg["kms_vault_name"]
        self.suitability_framework: str = cfg["suitability_framework"]
        self.disclosure_locale: str = cfg.get(
            "disclosure_locale", self.locale
        )
        self.audit_log_policy: str = cfg.get(
            "audit_log_policy", "standard"
        )
        # Secret reference — NEVER plaintext
        vault = self.kms_vault_name
        self.db_connection_secret: str = (
            f"${{KEYVAULT:{vault}-db-connection-string}}"
        )

    def __setattr__(self, _name: str, _value: object) -> None:
        if hasattr(self, "entity_id"):
            raise AttributeError("EntityContext is immutable")
        super().__setattr__(_name, _value)
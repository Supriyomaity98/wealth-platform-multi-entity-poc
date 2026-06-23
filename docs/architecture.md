# Architecture

## Current state — single-entity Singapore

The platform is live in Singapore. Every component embeds Singapore-specific constants: SGD currency, MAS regulator, en_SG locale, Singapore booking centre, 50 bps management fee, and a 250,000 SGD large-position threshold.

### Components

| Component | Location | Responsibility |
|-----------|----------|----------------|
| COBOL batch | `cobol/PORTVAL.cbl` | Nightly portfolio valuation, fee computation, disclosure flags |
| Java API | `java/AccountController.java` | REST endpoint `POST /api/account/value` for on-demand valuation |
| Python module | `python/risk_report.py` | Risk report generation with suitability and disclosure text |
| SQL schema | `sql/schema.sql` | Client, portfolio, and holding tables with SG defaults |

None of these components share a configuration layer today. Each hardcodes the same Singapore assumptions independently.

## Target state — entity-aware, single codebase

One codebase serves three legal-entity deployments:

| Entity | Code | Currency | Regulator | Azure region |
|--------|------|----------|-----------|--------------|
| Singapore (live) | SG | SGD | MAS | Southeast Asia |
| Hong Kong | HK | HKD | SFC | East Asia |
| Switzerland | CH | CHF | FINMA | Switzerland North |

Entity configuration (currency, locale, regulator, fee schedule, thresholds, disclosure templates, data region) is injected at deploy time — not selected at runtime. Each entity runs in its own Azure VPC with a dedicated Key Vault.

The multi-agent refactoring workflow will:

1. Extract hardcoded constants into entity configuration.
2. Add an `entity` configuration record (or equivalent) consumed by all four components.
3. Introduce `entity_id` / entity-aware defaults in the SQL schema.
4. Preserve backward compatibility for the live Singapore deployment.

# Wealth Platform Multi-Entity PoC

A synthetic wealth-management platform currently live in **Singapore**, used as a demonstration codebase for a multi-agent refactoring workflow. The workflow expands the platform to **Hong Kong** and **Switzerland** through entity-aware configuration — without forking the codebase per jurisdiction.

All hardcoded single-entity (Singapore) assumptions throughout this repository are **intentional**. They represent the refactoring targets that the multi-agent workflow must address.

## Languages

| Area | Technology |
|------|------------|
| Batch valuation | COBOL (`cobol/PORTVAL.cbl`) |
| Account API | Java / Spring Boot (`java/`) |
| Risk reporting | Python (`python/`) |
| Data layer | PostgreSQL (`sql/schema.sql`) |

## Story

The platform launched in Singapore under MAS supervision, with SGD as the base currency, en_SG locale, and a 50 bps management fee schedule. Client portfolios are booked at the Singapore booking centre; risk reports carry MAS Notice FAA disclosure text.

Group strategy calls for expansion into Hong Kong (HKD, SFC, East Asia region) and Switzerland (CHF, FINMA, Switzerland North region). Rather than cloning the stack per entity, engineering will refactor this single codebase to read entity configuration at deploy time — one artefact, three legal-entity deployments, each in its own Azure VPC with a dedicated Key Vault.

The agents' job: find every Singapore assumption (currency, regulator, fee basis points, disclosure strings, large-position thresholds, schema defaults) and replace them with configuration-driven values, while preserving backward compatibility for the live Singapore deployment.

## Repository layout

```
cobol/          Batch portfolio valuation (PORTVAL)
java/           Spring Boot account service
python/         Risk reporting module
sql/            PostgreSQL schema
docs/           Architecture and governance references
```

## CI

GitHub Actions runs Python tests, Java compile (non-blocking), and COBOL structure checks on every push and pull request to `main`.

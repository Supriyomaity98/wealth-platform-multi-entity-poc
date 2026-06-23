# Governance

## Reference document

**WEALTH-GOV-TECH-001** — *Technology Standards for Wealth Platform Entity Deployments*

Owned by: **Group Compliance**

All entity expansions must comply with WEALTH-GOV-TECH-001 and receive formal sign-off before production deployment.

## Approval bodies

The following governance bodies must approve any entity expansion (SG → HK, SG → CH, or additional jurisdictions):

| Body | Role |
|------|------|
| **Group Compliance** | Regulatory mapping, disclosure text, suitability framework alignment |
| **New Business Governance** | Commercial viability, product scope, client onboarding rules |
| **Internal Audit** | Control design, segregation of duties, audit trail completeness |
| **APAC Technology Risk** | Infrastructure risk assessment, data residency, operational resilience |

## Approved Azure regions

| Entity | Region name | Azure region ID |
|--------|-------------|-----------------|
| Singapore (SG) | Southeast Asia | `southeastasia` |
| Hong Kong (HK) | East Asia | `eastasia` |
| Switzerland (CH) | Switzerland North | `switzerlandnorth` |

Cross-region data replication between entity VPCs is prohibited without explicit Group Compliance waiver.

## Approved technology stack

- **Java** 17+ with **Spring Boot** 3.x (account and integration services)
- **Python** 3.11+ (risk reporting, analytics)
- **COBOL** (legacy batch — retained, not rewritten)
- **PostgreSQL** on **Microsoft Azure**
- **VPC per legal entity** — mandatory; no shared compute between entities
- **Azure Key Vault per entity** — secrets and certificates must not cross entity boundaries
- **No runtime entity switching** — entity identity is fixed at deployment; a running instance serves exactly one legal entity

******************************************************************
      * ENTCFG.cpy - Entity Configuration Copybook
      *
      * Maps shared contract config keys to COBOL data items for each
      * supported entity (SG, HK, CH). Key names align with the
      * shared_contract used by Java, Python, and all other teams.
      *
      * Shared contract keys mapped:
      *   entity.id                   -> EC-xx-ENTITY-CODE
      *   entity.currency             -> EC-xx-CURRENCY
      *   entity.locale.primary       -> EC-xx-LOCALE
      *   entity.regulator            -> EC-xx-REGULATOR
      *   entity.fee_schedule (std)   -> EC-xx-MGMT-FEE-BPS
      *   entity.portfolio_minimum    -> EC-xx-PORTFOLIO-MIN-AMT
      *   entity.data_region          -> EC-xx-DATA-REGION
      *   entity.kms_vault_name       -> EC-xx-KMS-VAULT-NAME
      *   entity.suitability_framework-> EC-xx-SUITABILITY-FWK
      *   entity.disclosure_locale    -> EC-xx-DISCLOSURE-TEXT
      *   entity.audit_siem_workspace -> EC-xx-AUDIT-SIEM-WKSP
      *   entity.data_residency_rule  -> EC-xx-DATA-RESID-RULE
      *
      * Secrets are NEVER stored here. All secrets use Azure Key
      * Vault references: ${KEYVAULT:wealth-{entity}-[secret-name]}
      ******************************************************************

      * ============================================================
      * SG - Singapore (baseline entity)
      * ============================================================
       01  EC-SG-ENTITY-CODE       PIC X(02) VALUE "SG".
       01  EC-SG-CURRENCY          PIC X(03) VALUE "SGD".
       01  EC-SG-LOCALE            PIC X(05) VALUE "en_SG".
       01  EC-SG-REGULATOR         PIC X(20) VALUE "MAS".
       01  EC-SG-BOOKING-CENTRE    PIC X(20) VALUE "Singapore".
       01  EC-SG-MGMT-FEE-BPS     PIC 9(03) VALUE 50.
       01  EC-SG-LARGE-POS-THR    PIC 9(09)V99
                                     VALUE 250000.00.
       01  EC-SG-DISCLOSURE-TEXT   PIC X(80)
           VALUE "MAS Notice FAA: Past performance is not indicative".
       01  EC-SG-SUITABILITY-FWK  PIC X(30)
           VALUE "MAS_FAA_2002".
       01  EC-SG-DATA-REGION      PIC X(30)
           VALUE "azure-southeast-asia".
       01  EC-SG-KMS-VAULT-NAME   PIC X(30)
           VALUE "kv-wealth-sg-prod".
       01  EC-SG-PORTFOLIO-MIN-AMT PIC 9(09)V99
                                     VALUE 200000.00.
       01  EC-SG-DATA-RESID-RULE  PIC X(120)
           VALUE "SG client data must remain in Azure Southeast Asia p
      -    "er MAS TRM Guidelines 2021".
       01  EC-SG-AUDIT-SIEM-WKSP  PIC X(80)
           VALUE "/subscriptions/.../law-wealth-sg-prod".

      * ============================================================
      * HK - Hong Kong
      * ============================================================
       01  EC-HK-ENTITY-CODE       PIC X(02) VALUE "HK".
       01  EC-HK-CURRENCY          PIC X(03) VALUE "HKD".
       01  EC-HK-LOCALE            PIC X(05) VALUE "zh_HK".
       01  EC-HK-REGULATOR         PIC X(20) VALUE "HKMA,SFC,PDPO".
       01  EC-HK-BOOKING-CENTRE    PIC X(20) VALUE "Hong Kong".
       01  EC-HK-MGMT-FEE-BPS     PIC 9(03) VALUE 45.
       01  EC-HK-LARGE-POS-THR    PIC 9(09)V99
                                     VALUE 2000000.00.
       01  EC-HK-DISCLOSURE-TEXT   PIC X(80)
           VALUE "SFC COP: Investment involves risks. Past performance
      -    " is not indicative".
       01  EC-HK-SUITABILITY-FWK  PIC X(30)
           VALUE "SFC_COP_2019".
       01  EC-HK-DATA-REGION      PIC X(30)
           VALUE "azure-east-asia".
       01  EC-HK-KMS-VAULT-NAME   PIC X(30)
           VALUE "kv-wealth-hk-prod".
       01  EC-HK-PORTFOLIO-MIN-AMT PIC 9(09)V99
                                     VALUE 1000000.00.
       01  EC-HK-DATA-RESID-RULE  PIC X(120)
           VALUE "HK client/transaction data must remain in Azure East
      -    " Asia per HKMA/SFC/PDPO".
       01  EC-HK-AUDIT-SIEM-WKSP  PIC X(80)
           VALUE "/subscriptions/.../law-wealth-hk-prod".

      * ============================================================
      * CH - Switzerland
      * ============================================================
       01  EC-CH-ENTITY-CODE       PIC X(02) VALUE "CH".
       01  EC-CH-CURRENCY          PIC X(03) VALUE "CHF".
       01  EC-CH-LOCALE            PIC X(05) VALUE "de_CH".
       01  EC-CH-REGULATOR         PIC X(20) VALUE "FINMA,nDSG".
       01  EC-CH-BOOKING-CENTRE    PIC X(20) VALUE "Zurich".
       01  EC-CH-MGMT-FEE-BPS     PIC 9(03) VALUE 45.
       01  EC-CH-LARGE-POS-THR    PIC 9(09)V99
                                     VALUE 1000000.00.
       01  EC-CH-DISCLOSURE-TEXT   PIC X(80)
           VALUE "FINMA: Anlagen sind mit Risiken verbunden. Vergangen
      -    "e Ergebnisse sind kein Indikator".
       01  EC-CH-SUITABILITY-FWK  PIC X(30)
           VALUE "FINMA_OUTSOURCING_2018_3".
       01  EC-CH-DATA-REGION      PIC X(30)
           VALUE "azure-switzerland-north".
       01  EC-CH-KMS-VAULT-NAME   PIC X(30)
           VALUE "kv-wealth-ch-prod".
       01  EC-CH-PORTFOLIO-MIN-AMT PIC 9(09)V99
                                     VALUE 500000.00.
       01  EC-CH-DATA-RESID-RULE  PIC X(120)
           VALUE "All regulated Swiss entity data must reside in Azure
      -    " Switzerland North; no cross-border transfer except as per
      -    " nDSG/FINMA approval".
       01  EC-CH-AUDIT-SIEM-WKSP  PIC X(80)
           VALUE "/subscriptions/.../law-wealth-ch-prod".
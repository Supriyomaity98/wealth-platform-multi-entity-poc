IDENTIFICATION DIVISION.
       PROGRAM-ID. PORTVAL.
      * Portfolio valuation batch - multi-entity deployment.
      * Entity context is resolved at startup from ENTITY_ID
      * environment variable. All entity-specific values are loaded
      * from the ENTCFG copybook and resolved via 1000-INITIALISE.
      * Secrets use Azure Key Vault references (${KEYVAULT:...}).
      *
      * Behaviour for the SG baseline is preserved exactly.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      * --- Entity configuration copybook (shared config keys) ---
           COPY ENTCFG.

      * --- Runtime entity context (populated in 1000-INITIALISE) ---
       01  WS-ENTITY-CODE           PIC X(02).
       01  WS-CURRENCY              PIC X(03).
       01  WS-LOCALE                PIC X(05).
       01  WS-REGULATOR             PIC X(20).
       01  WS-BOOKING-CENTRE        PIC X(20).
       01  WS-MGMT-FEE-BPS         PIC 9(03).
       01  WS-LARGE-POS-THRESHOLD   PIC 9(09)V99.
       01  WS-DISCLOSURE-TEXT       PIC X(80).
       01  WS-SUITABILITY-FWK       PIC X(30).
       01  WS-DATA-REGION           PIC X(30).
       01  WS-KMS-VAULT-NAME        PIC X(30).
       01  WS-PORTFOLIO-MINIMUM-AMT PIC 9(09)V99.
       01  WS-DATA-RESIDENCY-RULE   PIC X(120).
       01  WS-AUDIT-SIEM-WKSP      PIC X(80).

      * --- Key Vault reference for secrets (entity-aware) ---
       01  WS-KV-DB-PASSWORD        PIC X(60).

      * --- Environment variable input ---
       01  WS-ENV-ENTITY-ID         PIC X(02).

      * --- Portfolio input record ---
       01  WS-PORTFOLIO-ID          PIC X(12).
       01  WS-MARKET-VALUE          PIC 9(11)V99.
       01  WS-MGMT-FEE              PIC 9(09)V99.
       01  WS-FEE-RATE              PIC 9V9999.
       01  WS-IS-REPORTABLE         PIC X(01).
       01  WS-REPORT-FLAG           PIC X(01) VALUE "N".
       01  WS-EOF-FLAG              PIC X(01) VALUE "N".
       01  WS-RECORD-COUNT          PIC 9(06) VALUE ZERO.

      * --- Work fields ---
       01  WS-INIT-OK               PIC X(01) VALUE "N".

       PROCEDURE DIVISION.
       0000-MAIN.
      * Entry point - resolve entity context, then process.
           PERFORM 1000-INITIALISE
           IF WS-INIT-OK = "Y"
               PERFORM 2000-PROCESS-PORTFOLIOS
                   UNTIL WS-EOF-FLAG = "Y"
               PERFORM 9000-FINALISE
           END-IF
           STOP RUN.

       1000-INITIALISE.
      * Read ENTITY_ID from environment and load entity config.
      * If ENTITY_ID is not set, default to SG for backward compat.
           ACCEPT WS-ENV-ENTITY-ID FROM ENVIRONMENT "ENTITY_ID"

           IF WS-ENV-ENTITY-ID = SPACES OR
              WS-ENV-ENTITY-ID = LOW-VALUES
               MOVE "SG" TO WS-ENV-ENTITY-ID
           END-IF

           EVALUATE WS-ENV-ENTITY-ID
               WHEN "SG"
                   PERFORM 1100-LOAD-CFG-SG
               WHEN "HK"
                   PERFORM 1200-LOAD-CFG-HK
               WHEN "CH"
                   PERFORM 1300-LOAD-CFG-CH
               WHEN OTHER
                   DISPLAY "PORTVAL FATAL: Unknown ENTITY_ID: "
                       WS-ENV-ENTITY-ID
                   MOVE "N" TO WS-INIT-OK
                   GO TO 1000-EXIT
           END-EVALUATE

      * Build Key Vault reference for DB password (entity-aware).
      * Pattern: ${KEYVAULT:wealth-{entity}-db-password}
           EVALUATE WS-ENTITY-CODE
               WHEN "SG"
                   MOVE "${KEYVAULT:wealth-sg-db-password}"
                       TO WS-KV-DB-PASSWORD
               WHEN "HK"
                   MOVE "${KEYVAULT:wealth-hk-db-password}"
                       TO WS-KV-DB-PASSWORD
               WHEN "CH"
                   MOVE "${KEYVAULT:wealth-ch-db-password}"
                       TO WS-KV-DB-PASSWORD
           END-EVALUATE

           DISPLAY "PORTVAL starting - entity "
               WS-ENTITY-CODE ", regulator " WS-REGULATOR
           MOVE ZERO TO WS-RECORD-COUNT
           MOVE "N" TO WS-EOF-FLAG
           MOVE "Y" TO WS-INIT-OK.

       1000-EXIT.
           EXIT.

       1100-LOAD-CFG-SG.
      * entity.id = SG
           MOVE EC-SG-ENTITY-CODE       TO WS-ENTITY-CODE
      * entity.currency = SGD
           MOVE EC-SG-CURRENCY           TO WS-CURRENCY
      * entity.locale.primary = en_SG
           MOVE EC-SG-LOCALE             TO WS-LOCALE
      * entity.regulator = MAS
           MOVE EC-SG-REGULATOR          TO WS-REGULATOR
      * Booking centre derived from entity
           MOVE EC-SG-BOOKING-CENTRE     TO WS-BOOKING-CENTRE
      * entity.fee_schedule standard tier = 50 bps
           MOVE EC-SG-MGMT-FEE-BPS      TO WS-MGMT-FEE-BPS
      * Large position threshold
           MOVE EC-SG-LARGE-POS-THR      TO WS-LARGE-POS-THRESHOLD
      * entity.disclosure_locale driven text
           MOVE EC-SG-DISCLOSURE-TEXT    TO WS-DISCLOSURE-TEXT
      * entity.suitability_framework = MAS_FAA_2002
           MOVE EC-SG-SUITABILITY-FWK   TO WS-SUITABILITY-FWK
      * entity.data_region = azure-southeast-asia
           MOVE EC-SG-DATA-REGION        TO WS-DATA-REGION
      * entity.kms_vault_name = kv-wealth-sg-prod
           MOVE EC-SG-KMS-VAULT-NAME     TO WS-KMS-VAULT-NAME
      * entity.portfolio_minimum.amount = 200000
           MOVE EC-SG-PORTFOLIO-MIN-AMT  TO WS-PORTFOLIO-MINIMUM-AMT
      * entity.data_residency_rule
           MOVE EC-SG-DATA-RESID-RULE    TO WS-DATA-RESIDENCY-RULE
      * entity.audit_siem_workspace
           MOVE EC-SG-AUDIT-SIEM-WKSP   TO WS-AUDIT-SIEM-WKSP.

       1200-LOAD-CFG-HK.
      * entity.id = HK
           MOVE EC-HK-ENTITY-CODE       TO WS-ENTITY-CODE
      * entity.currency = HKD
           MOVE EC-HK-CURRENCY           TO WS-CURRENCY
      * entity.locale.primary = zh_HK
           MOVE EC-HK-LOCALE             TO WS-LOCALE
      * entity.regulator = HKMA,SFC,PDPO
           MOVE EC-HK-REGULATOR          TO WS-REGULATOR
           MOVE EC-HK-BOOKING-CENTRE     TO WS-BOOKING-CENTRE
      * entity.fee_schedule standard tier = 45 bps
           MOVE EC-HK-MGMT-FEE-BPS      TO WS-MGMT-FEE-BPS
           MOVE EC-HK-LARGE-POS-THR      TO WS-LARGE-POS-THRESHOLD
           MOVE EC-HK-DISCLOSURE-TEXT    TO WS-DISCLOSURE-TEXT
      * entity.suitability_framework = SFC_COP_2019
           MOVE EC-HK-SUITABILITY-FWK   TO WS-SUITABILITY-FWK
      * entity.data_region = azure-east-asia
           MOVE EC-HK-DATA-REGION        TO WS-DATA-REGION
      * entity.kms_vault_name = kv-wealth-hk-prod
           MOVE EC-HK-KMS-VAULT-NAME     TO WS-KMS-VAULT-NAME
      * entity.portfolio_minimum.amount = 1000000
           MOVE EC-HK-PORTFOLIO-MIN-AMT  TO WS-PORTFOLIO-MINIMUM-AMT
           MOVE EC-HK-DATA-RESID-RULE    TO WS-DATA-RESIDENCY-RULE
           MOVE EC-HK-AUDIT-SIEM-WKSP   TO WS-AUDIT-SIEM-WKSP.

       1300-LOAD-CFG-CH.
      * entity.id = CH
           MOVE EC-CH-ENTITY-CODE       TO WS-ENTITY-CODE
      * entity.currency = CHF
           MOVE EC-CH-CURRENCY           TO WS-CURRENCY
      * entity.locale.primary = de_CH
           MOVE EC-CH-LOCALE             TO WS-LOCALE
      * entity.regulator = FINMA,nDSG
           MOVE EC-CH-REGULATOR          TO WS-REGULATOR
           MOVE EC-CH-BOOKING-CENTRE     TO WS-BOOKING-CENTRE
      * entity.fee_schedule standard tier = 45 bps
           MOVE EC-CH-MGMT-FEE-BPS      TO WS-MGMT-FEE-BPS
           MOVE EC-CH-LARGE-POS-THR      TO WS-LARGE-POS-THRESHOLD
           MOVE EC-CH-DISCLOSURE-TEXT    TO WS-DISCLOSURE-TEXT
      * entity.suitability_framework = FINMA_OUTSOURCING_2018_3
           MOVE EC-CH-SUITABILITY-FWK   TO WS-SUITABILITY-FWK
      * entity.data_region = azure-switzerland-north
           MOVE EC-CH-DATA-REGION        TO WS-DATA-REGION
      * entity.kms_vault_name = kv-wealth-ch-prod
           MOVE EC-CH-KMS-VAULT-NAME     TO WS-KMS-VAULT-NAME
      * entity.portfolio_minimum.amount = 500000
           MOVE EC-CH-PORTFOLIO-MIN-AMT  TO WS-PORTFOLIO-MINIMUM-AMT
           MOVE EC-CH-DATA-RESID-RULE    TO WS-DATA-RESIDENCY-RULE
           MOVE EC-CH-AUDIT-SIEM-WKSP   TO WS-AUDIT-SIEM-WKSP.

       2000-PROCESS-PORTFOLIOS.
      * Read next portfolio and compute valuation.
           PERFORM 2100-READ-PORTFOLIO
           IF WS-EOF-FLAG NOT = "Y"
               PERFORM 3000-VALUATE-PORTFOLIO
               ADD 1 TO WS-RECORD-COUNT
           END-IF.

       2100-READ-PORTFOLIO.
      * Stub read - production would READ from PORTIN-FILE.
           MOVE "Y" TO WS-EOF-FLAG.

       3000-VALUATE-PORTFOLIO.
      * Apply entity fee schedule and check reportability.
           PERFORM 3100-COMPUTE-FEE
           PERFORM 3200-CHECK-REPORTABLE
           PERFORM 3300-EMIT-VALUATION.

       3100-COMPUTE-FEE.
      * Management fee = market value * bps / 10000 (entity bps).
           COMPUTE WS-FEE-RATE = WS-MGMT-FEE-BPS / 10000
           COMPUTE WS-MGMT-FEE = WS-MARKET-VALUE * WS-FEE-RATE.

       3200-CHECK-REPORTABLE.
      * Positions above threshold require regulatory disclosure.
           IF WS-MARKET-VALUE >= WS-LARGE-POS-THRESHOLD
               MOVE "Y" TO WS-IS-REPORTABLE
           ELSE
               MOVE "N" TO WS-IS-REPORTABLE
           END-IF.

       3300-EMIT-VALUATION.
      * Write valuation line with entity booking centre and disclosure.
           DISPLAY "PORTFOLIO: " WS-PORTFOLIO-ID
           DISPLAY "  CURRENCY: " WS-CURRENCY
           DISPLAY "  BOOKING:  " WS-BOOKING-CENTRE
           DISPLAY "  MKT-VAL:  " WS-MARKET-VALUE
           DISPLAY "  MGMT-FEE: " WS-MGMT-FEE
           DISPLAY "  REPORTABLE: " WS-IS-REPORTABLE
           IF WS-IS-REPORTABLE = "Y"
               DISPLAY "  DISCLOSURE: " WS-DISCLOSURE-TEXT
           END-IF.

       9000-FINALISE.
      * Close files and print summary.
           DISPLAY "PORTVAL complete - processed "
               WS-RECORD-COUNT " portfolios ("
               WS-ENTITY-CODE ")".
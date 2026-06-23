IDENTIFICATION DIVISION.
       PROGRAM-ID. PORTVAL.
      * Portfolio valuation batch - multi-entity deployment.
      * Entity-specific values are loaded from ENTITY-COPY copybook
      * structure, populated at startup from external config keyed
      * by the ENTITY_ID environment variable.
      * SG baseline behaviour is preserved exactly.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      * --- Entity configuration record (from copybook) -----------
           COPY ENTITY-COPY.

      * --- Runtime entity fields derived from config --------------
       01  WS-ENTITY-CODE           PIC X(02).
       01  WS-CURRENCY              PIC X(03).
       01  WS-LOCALE                PIC X(05).
       01  WS-REGULATOR             PIC X(20).
       01  WS-BOOKING-CENTRE        PIC X(20).
       01  WS-MGMT-FEE-BPS          PIC 9(03).
       01  WS-LARGE-POS-THRESHOLD   PIC 9(09)V99.
       01  WS-DISCLOSURE-TEXT       PIC X(80).
       01  WS-ENTITY-FULL-NAME     PIC X(60).
       01  WS-DATA-REGION           PIC X(20).
       01  WS-KMS-VAULT-NAME        PIC X(20).
       01  WS-SUITABILITY-FWK       PIC X(20).

      * --- Key Vault secret references (never plaintext) ----------
      * Pattern: ${KEYVAULT:<kms_vault_name>/<secret_name>}
       01  WS-KV-DB-PASSWORD        PIC X(80).
       01  WS-KV-API-KEY            PIC X(80).

      * --- Portfolio input record ---------------------------------
       01  WS-PORTFOLIO-ID          PIC X(12).
       01  WS-MARKET-VALUE          PIC 9(11)V99.
       01  WS-MGMT-FEE              PIC 9(09)V99.
       01  WS-FEE-RATE              PIC 9V9999.
       01  WS-IS-REPORTABLE         PIC X(01).
       01  WS-REPORT-FLAG           PIC X(01) VALUE "N".
       01  WS-EOF-FLAG              PIC X(01) VALUE "N".
       01  WS-RECORD-COUNT          PIC 9(06) VALUE ZERO.

      * --- Environment variable input buffer ----------------------
       01  WS-ENV-ENTITY-ID         PIC X(02).
       01  WS-CONFIG-LOADED         PIC X(01) VALUE "N".

       PROCEDURE DIVISION.
       0000-MAIN.
      * Entry point - load entity config, initialise, process.
           PERFORM 0500-LOAD-ENTITY-CONFIG
           IF WS-CONFIG-LOADED NOT = "Y"
               DISPLAY "PORTVAL ABORT - entity config invalid or "
                   "missing. Check ENTITY_ID env var."
               STOP RUN
           END-IF
           PERFORM 1000-INITIALISE
           PERFORM 2000-PROCESS-PORTFOLIOS
               UNTIL WS-EOF-FLAG = "Y"
           PERFORM 9000-FINALISE
           STOP RUN.

       0500-LOAD-ENTITY-CONFIG.
      * Read ENTITY_ID from environment and populate working
      * storage from the entity configuration structure.
      * In production this calls the config-loader subsystem;
      * here we map ENTITY-CFG copybook fields to runtime fields.
           ACCEPT WS-ENV-ENTITY-ID FROM ENVIRONMENT "ENTITY_ID"

           IF WS-ENV-ENTITY-ID = SPACES OR
              WS-ENV-ENTITY-ID = LOW-VALUES
               DISPLAY "PORTVAL ERROR - ENTITY_ID env var not set"
               MOVE "N" TO WS-CONFIG-LOADED
           ELSE
               PERFORM 0510-MAP-ENTITY-VALUES
           END-IF.

       0510-MAP-ENTITY-VALUES.
      * Map entity config values based on ENTITY_ID.
      * Each entity block matches the shared contract keys exactly.
      * SG baseline is the original behaviour preserved verbatim.
           EVALUATE WS-ENV-ENTITY-ID
               WHEN "SG"
                   MOVE "SG"    TO EC-ENTITY-ID
                   MOVE "ACME Wealth Management Pte Ltd (Singapore)"
                       TO EC-ENTITY-FULL-NAME
                   MOVE "SGD"   TO EC-CURRENCY
                   MOVE 50      TO EC-FEE-SCHEDULE-BPS
                   MOVE 250000  TO EC-MIN-PORTFOLIO-THRESHOLD
                   MOVE "en_SG" TO EC-DEFAULT-LOCALE
                   MOVE "Singapore" TO EC-BOOKING-CENTRE
                   MOVE "Southeast Asia" TO EC-DATA-REGION
                   MOVE "kv-sg-sea" TO EC-KMS-VAULT-NAME
                   MOVE "MAS_FAA_2002" TO EC-SUITABILITY-FRAMEWORK
                   MOVE "MAS"   TO EC-REGULATORY-BODY-1
                   MOVE SPACES  TO EC-REGULATORY-BODY-2
                   MOVE SPACES  TO EC-REGULATORY-BODY-3
                   MOVE "disclosures/en_SG/" TO EC-DISCLOSURE-PATH-1
                   MOVE SPACES TO EC-DISCLOSURE-PATH-2
                   MOVE SPACES TO EC-DISCLOSURE-PATH-3
                   MOVE SPACES TO EC-DISCLOSURE-PATH-4
                   MOVE "Y" TO WS-CONFIG-LOADED

               WHEN "HK"
                   MOVE "HK"    TO EC-ENTITY-ID
                   MOVE "ACME Wealth Management Limited (Hong Kong)"
                       TO EC-ENTITY-FULL-NAME
                   MOVE "HKD"   TO EC-CURRENCY
                   MOVE 40      TO EC-FEE-SCHEDULE-BPS
                   MOVE 200000  TO EC-MIN-PORTFOLIO-THRESHOLD
                   MOVE "zh_HK" TO EC-DEFAULT-LOCALE
                   MOVE "Hong Kong" TO EC-BOOKING-CENTRE
                   MOVE "East Asia" TO EC-DATA-REGION
                   MOVE "kv-hk-ea" TO EC-KMS-VAULT-NAME
                   MOVE "SFC_COP_2019" TO EC-SUITABILITY-FRAMEWORK
                   MOVE "SFC"   TO EC-REGULATORY-BODY-1
                   MOVE "HKMA"  TO EC-REGULATORY-BODY-2
                   MOVE "PDPO"  TO EC-REGULATORY-BODY-3
                   MOVE "disclosures/zh_HK/" TO EC-DISCLOSURE-PATH-1
                   MOVE "disclosures/en_HK/" TO EC-DISCLOSURE-PATH-2
                   MOVE SPACES TO EC-DISCLOSURE-PATH-3
                   MOVE SPACES TO EC-DISCLOSURE-PATH-4
                   MOVE "Y" TO WS-CONFIG-LOADED

               WHEN "CH"
                   MOVE "CH"    TO EC-ENTITY-ID
                   MOVE "ACME Wealth Management AG (Switzerland)"
                       TO EC-ENTITY-FULL-NAME
                   MOVE "CHF"   TO EC-CURRENCY
                   MOVE 30      TO EC-FEE-SCHEDULE-BPS
                   MOVE 250000  TO EC-MIN-PORTFOLIO-THRESHOLD
                   MOVE "de_CH" TO EC-DEFAULT-LOCALE
                   MOVE "Zurich" TO EC-BOOKING-CENTRE
                   MOVE "Switzerland North" TO EC-DATA-REGION
                   MOVE "kv-ch-chn" TO EC-KMS-VAULT-NAME
                   MOVE "FINMA_LSFin_2020"
                       TO EC-SUITABILITY-FRAMEWORK
                   MOVE "FINMA" TO EC-REGULATORY-BODY-1
                   MOVE "FADP_nDSG" TO EC-REGULATORY-BODY-2
                   MOVE SPACES  TO EC-REGULATORY-BODY-3
                   MOVE "disclosures/de_CH/" TO EC-DISCLOSURE-PATH-1
                   MOVE "disclosures/fr_CH/" TO EC-DISCLOSURE-PATH-2
                   MOVE "disclosures/it_CH/" TO EC-DISCLOSURE-PATH-3
                   MOVE "disclosures/en_CH/" TO EC-DISCLOSURE-PATH-4
                   MOVE "Y" TO WS-CONFIG-LOADED

               WHEN OTHER
                   DISPLAY "PORTVAL ERROR - unknown ENTITY_ID: "
                       WS-ENV-ENTITY-ID
                   MOVE "N" TO WS-CONFIG-LOADED
           END-EVALUATE

           IF WS-CONFIG-LOADED = "Y"
               PERFORM 0520-APPLY-CONFIG-TO-WS
           END-IF.

       0520-APPLY-CONFIG-TO-WS.
      * Transfer entity config copybook fields into the working
      * storage runtime variables used by business logic.
           MOVE EC-ENTITY-ID          TO WS-ENTITY-CODE
           MOVE EC-CURRENCY           TO WS-CURRENCY
           MOVE EC-DEFAULT-LOCALE     TO WS-LOCALE
           MOVE EC-REGULATORY-BODY-1  TO WS-REGULATOR
           MOVE EC-BOOKING-CENTRE     TO WS-BOOKING-CENTRE
           MOVE EC-FEE-SCHEDULE-BPS   TO WS-MGMT-FEE-BPS
           MOVE EC-MIN-PORTFOLIO-THRESHOLD
                                      TO WS-LARGE-POS-THRESHOLD
           MOVE EC-ENTITY-FULL-NAME   TO WS-ENTITY-FULL-NAME
           MOVE EC-DATA-REGION        TO WS-DATA-REGION
           MOVE EC-KMS-VAULT-NAME     TO WS-KMS-VAULT-NAME
           MOVE EC-SUITABILITY-FRAMEWORK TO WS-SUITABILITY-FWK

      * Build Key Vault secret references from entity vault name.
      * Pattern: ${KEYVAULT:<vault>/<secret>}
           INITIALIZE WS-KV-DB-PASSWORD
           STRING "${KEYVAULT:" DELIMITED SIZE
                  EC-KMS-VAULT-NAME DELIMITED SPACES
                  "/db-password}" DELIMITED SIZE
                  INTO WS-KV-DB-PASSWORD
           END-STRING

           INITIALIZE WS-KV-API-KEY
           STRING "${KEYVAULT:" DELIMITED SIZE
                  EC-KMS-VAULT-NAME DELIMITED SPACES
                  "/api-key}" DELIMITED SIZE
                  INTO WS-KV-API-KEY
           END-STRING

      * Build entity-appropriate disclosure text.
           EVALUATE WS-ENTITY-CODE
               WHEN "SG"
                   MOVE "MAS Notice FAA: Past performance is not ind
      -               "icative"
                       TO WS-DISCLOSURE-TEXT
               WHEN "HK"
                   MOVE "SFC COP: Past performance is not indicative
      -               " of future results"
                       TO WS-DISCLOSURE-TEXT
               WHEN "CH"
                   MOVE "FINMA LSFin: Vergangene Wertentwicklung ist
      -               " kein Indikator"
                       TO WS-DISCLOSURE-TEXT
               WHEN OTHER
                   MOVE SPACES TO WS-DISCLOSURE-TEXT
           END-EVALUATE.

       1000-INITIALISE.
      * Open input portfolio file and reset counters.
           DISPLAY "PORTVAL starting - entity "
               WS-ENTITY-CODE ", regulator " WS-REGULATOR
           MOVE ZERO TO WS-RECORD-COUNT
           MOVE "N" TO WS-EOF-FLAG.

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
      * Management fee = market value * bps / 10000.
      * Fee bps comes from entity config (e.g. 50 for SG).
           COMPUTE WS-FEE-RATE = WS-MGMT-FEE-BPS / 10000
           COMPUTE WS-MGMT-FEE = WS-MARKET-VALUE * WS-FEE-RATE.

       3200-CHECK-REPORTABLE.
      * Positions above entity threshold require regulatory disclosure.
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
IDENTIFICATION DIVISION.
       PROGRAM-ID. PORTVAL.
      * Portfolio valuation batch - entity driven by YAML manifest.
      * Config loaded from ${KEYVAULT:wealth-{entity_id}-manifest}
      * ENV ENTITY_ID must match manifest entity_id (fail-fast).

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MANIFEST-FILE
               ASSIGN TO DYNAMIC WS-MANIFEST-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-MANIFEST-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  MANIFEST-FILE.
       01  MF-RECORD                PIC X(120).

       WORKING-STORAGE SECTION.
       01  WS-ENTITY-ID-ENV         PIC X(04).
       01  WS-MANIFEST-PATH         PIC X(120).
       01  WS-MANIFEST-STATUS       PIC X(02).
       01  WS-YAML-KEY              PIC X(40).
       01  WS-YAML-VALUE            PIC X(80).
       01  WS-COLON-POS             PIC 9(03).
       01  WS-MANIFEST-EOF          PIC X(01) VALUE "N".
       COPY ENTITY-COPY.
       01  WS-PORTFOLIO-ID          PIC X(12).
       01  WS-MARKET-VALUE          PIC 9(11)V99.
       01  WS-MGMT-FEE              PIC 9(09)V99.
       01  WS-FEE-RATE              PIC 9(01)V9(06).
       01  WS-IS-REPORTABLE         PIC X(01).
       01  WS-EOF-FLAG              PIC X(01) VALUE "N".
       01  WS-RECORD-COUNT          PIC 9(06) VALUE ZERO.
       01  WS-DISCLOSURE-TEXT       PIC X(80).
       01  WS-RETURN-CODE           PIC 9(02) VALUE 0.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALISE
           IF WS-RETURN-CODE = 0
               PERFORM 2000-PROCESS-PORTFOLIOS
                   UNTIL WS-EOF-FLAG = "Y"
               PERFORM 9000-FINALISE
           ELSE
               DISPLAY "PORTVAL ABEND: " EC-VALIDATION-MSG
               MOVE 16 TO RETURN-CODE
           END-IF
           STOP RUN.

       1000-INITIALISE.
           PERFORM 1100-READ-ENTITY-ENV
           PERFORM 1200-LOAD-MANIFEST
           PERFORM 1300-VALIDATE-ENTITY
           MOVE ZERO TO WS-RECORD-COUNT
           MOVE "N" TO WS-EOF-FLAG.

       1100-READ-ENTITY-ENV.
           ACCEPT WS-ENTITY-ID-ENV FROM ENVIRONMENT "ENTITY_ID"
           IF WS-ENTITY-ID-ENV = SPACES
               MOVE "ENTITY_ID env var not set" TO EC-VALIDATION-MSG
               MOVE 8 TO WS-RETURN-CODE
           ELSE
               STRING "/etc/entity-config/"
                   DELIMITED SIZE
                   FUNCTION LOWER-CASE(
                       FUNCTION TRIM(WS-ENTITY-ID-ENV))
                   DELIMITED SIZE
                   "/entity-config.yaml"
                   DELIMITED SIZE
                   INTO WS-MANIFEST-PATH
           END-IF.

       1200-LOAD-MANIFEST.
           IF WS-RETURN-CODE NOT = 0
               NEXT SENTENCE
           ELSE
               OPEN INPUT MANIFEST-FILE
               IF WS-MANIFEST-STATUS NOT = "00"
                   STRING "Cannot open manifest: " DELIMITED SIZE
                       WS-MANIFEST-PATH DELIMITED SIZE
                       INTO EC-VALIDATION-MSG
                   MOVE 8 TO WS-RETURN-CODE
               ELSE
                   PERFORM 1210-PARSE-MANIFEST
                       UNTIL WS-MANIFEST-EOF = "Y"
                   CLOSE MANIFEST-FILE
               END-IF
           END-IF.

       1210-PARSE-MANIFEST.
           READ MANIFEST-FILE INTO MF-RECORD
               AT END MOVE "Y" TO WS-MANIFEST-EOF
           END-READ
           IF WS-MANIFEST-EOF NOT = "Y"
               PERFORM 1220-PARSE-YAML-LINE
           END-IF.

       1220-PARSE-YAML-LINE.
           MOVE SPACES TO WS-YAML-KEY WS-YAML-VALUE
           MOVE ZERO TO WS-COLON-POS
           INSPECT MF-RECORD
               TALLYING WS-COLON-POS
                   FOR CHARACTERS BEFORE ":"
           IF WS-COLON-POS > 0 AND WS-COLON-POS < 40
               MOVE MF-RECORD(1:WS-COLON-POS) TO WS-YAML-KEY
               MOVE FUNCTION TRIM(WS-YAML-KEY) TO WS-YAML-KEY
               MOVE MF-RECORD(WS-COLON-POS + 2:80) TO WS-YAML-VALUE
               MOVE FUNCTION TRIM(WS-YAML-VALUE) TO WS-YAML-VALUE
               PERFORM 1230-MAP-YAML-TO-CONFIG
           END-IF.

       1230-MAP-YAML-TO-CONFIG.
           EVALUATE WS-YAML-KEY
             WHEN "entity_id"
               MOVE WS-YAML-VALUE TO EC-ENTITY-ID
             WHEN "currency"
               MOVE WS-YAML-VALUE TO EC-CURRENCY
             WHEN "locale_primary"
               MOVE WS-YAML-VALUE TO EC-LOCALE-PRIMARY
             WHEN "locale_supported"
               MOVE WS-YAML-VALUE TO EC-LOCALE-SUPPORTED
             WHEN "fee_bps"
               MOVE FUNCTION NUMVAL(WS-YAML-VALUE) TO EC-FEE-BPS
             WHEN "relationship_threshold_amount"
               MOVE FUNCTION NUMVAL(WS-YAML-VALUE)
                   TO EC-RELATIONSHIP-THRESHOLD
             WHEN "large_position_threshold"
               MOVE FUNCTION NUMVAL(WS-YAML-VALUE)
                   TO EC-LARGE-POS-THRESHOLD
             WHEN "data_region"
               MOVE WS-YAML-VALUE TO EC-DATA-REGION
             WHEN "kv_vault_name"
               MOVE WS-YAML-VALUE TO EC-KV-VAULT-NAME
             WHEN "kv_vault_uri"
               MOVE WS-YAML-VALUE TO EC-KV-VAULT-URI
             WHEN "regulator"
               MOVE WS-YAML-VALUE TO EC-REGULATOR
             WHEN "suitability_framework"
               MOVE WS-YAML-VALUE TO EC-SUITABILITY-FRAMEWORK
             WHEN "disclosure_locale_required"
               MOVE WS-YAML-VALUE(1:1) TO EC-DISCLOSURE-LOCALE-REQ
             WHEN "cross_border_consent_required"
               MOVE WS-YAML-VALUE(1:1) TO EC-CROSS-BORDER-CONSENT
             WHEN "data_residency_strict"
               MOVE WS-YAML-VALUE(1:1) TO EC-DATA-RESIDENCY-STRICT
             WHEN "multilingual_documents_required"
               MOVE WS-YAML-VALUE(1:1) TO EC-MULTILINGUAL-DOCS-REQ
             WHEN "audit_log_retention_days"
               MOVE FUNCTION NUMVAL(WS-YAML-VALUE)
                   TO EC-AUDIT-LOG-RETENTION
             WHEN "schema_entity_id_enforced"
               MOVE WS-YAML-VALUE(1:1) TO EC-SCHEMA-ENTITY-ENFORCED
             WHEN "booking_centre"
               MOVE WS-YAML-VALUE TO EC-BOOKING-CENTRE
             WHEN OTHER
               CONTINUE
           END-EVALUATE.

       1300-VALIDATE-ENTITY.
           IF WS-RETURN-CODE NOT = 0
               NEXT SENTENCE
           ELSE
               IF FUNCTION TRIM(WS-ENTITY-ID-ENV) NOT =
                  FUNCTION TRIM(EC-ENTITY-ID)
                   STRING
                     "ENTITY_ID mismatch: env="
                         DELIMITED SIZE
                     FUNCTION TRIM(WS-ENTITY-ID-ENV)
                         DELIMITED SIZE
                     " manifest="
                         DELIMITED SIZE
                     FUNCTION TRIM(EC-ENTITY-ID)
                         DELIMITED SIZE
                     INTO EC-VALIDATION-MSG
                   MOVE 8 TO WS-RETURN-CODE
               ELSE
                   IF EC-FEE-BPS = 0
                       MOVE "Manifest fee_bps is zero or missing"
                           TO EC-VALIDATION-MSG
                       MOVE 8 TO WS-RETURN-CODE
                   ELSE
                       MOVE "Y" TO EC-CONFIG-LOADED-FLAG
                       DISPLAY "PORTVAL starting - entity: "
                           FUNCTION TRIM(EC-ENTITY-ID)
                           " regulator: "
                           FUNCTION TRIM(EC-REGULATOR)
                   END-IF
               END-IF
           END-IF.

       2000-PROCESS-PORTFOLIOS.
           PERFORM 2100-READ-PORTFOLIO
           IF WS-EOF-FLAG NOT = "Y"
               PERFORM 3000-VALUATE-PORTFOLIO
               ADD 1 TO WS-RECORD-COUNT
           END-IF.

       2100-READ-PORTFOLIO.
           MOVE "Y" TO WS-EOF-FLAG.

       3000-VALUATE-PORTFOLIO.
           PERFORM 3100-COMPUTE-FEE
           PERFORM 3200-CHECK-REPORTABLE
           PERFORM 3300-EMIT-VALUATION.

       3100-COMPUTE-FEE.
           COMPUTE WS-FEE-RATE = EC-FEE-BPS / 10000
           COMPUTE WS-MGMT-FEE = WS-MARKET-VALUE * WS-FEE-RATE.

       3200-CHECK-REPORTABLE.
           IF WS-MARKET-VALUE >= EC-LARGE-POS-THRESHOLD
               MOVE "Y" TO WS-IS-REPORTABLE
           ELSE
               MOVE "N" TO WS-IS-REPORTABLE
           END-IF.

       3300-EMIT-VALUATION.
           STRING FUNCTION TRIM(EC-REGULATOR) DELIMITED SIZE
               " Notice: Past performance is not indicative"
               DELIMITED SIZE
               INTO WS-DISCLOSURE-TEXT
           DISPLAY "PORTFOLIO: " WS-PORTFOLIO-ID
           DISPLAY "  CURRENCY: " FUNCTION TRIM(EC-CURRENCY)
           DISPLAY "  BOOKING:  " FUNCTION TRIM(EC-BOOKING-CENTRE)
           DISPLAY "  MKT-VAL:  " WS-MARKET-VALUE
           DISPLAY "  MGMT-FEE: " WS-MGMT-FEE
           DISPLAY "  REPORTABLE: " WS-IS-REPORTABLE
           IF WS-IS-REPORTABLE = "Y"
               DISPLAY "  DISCLOSURE: " WS-DISCLOSURE-TEXT
           END-IF.

       9000-FINALISE.
           DISPLAY "PORTVAL complete - processed "
               WS-RECORD-COUNT " portfolios ("
               FUNCTION TRIM(EC-ENTITY-ID) ")".
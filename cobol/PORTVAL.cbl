IDENTIFICATION DIVISION.
       PROGRAM-ID. PORTVAL.
      * Portfolio valuation batch — multi-entity deployment.
      * Entity config loaded from ENTITY-COPY.cpy at compile time.
      * Runtime ENTITY_ID env var selects entity; defaults to SG.
      * Secrets resolved via Azure Key Vault references.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
      * --- Entity context (loaded from copybook) ---
       COPY ENTITY-COPY.

      * --- Runtime entity selection ---
       01  WS-ENV-ENTITY-ID         PIC X(02) VALUE SPACES.

      * --- Active entity working fields ---
       01  WS-ENTITY-CODE           PIC X(02) VALUE SPACES.
       01  WS-CURRENCY              PIC X(03) VALUE SPACES.
       01  WS-LOCALE                PIC X(05) VALUE SPACES.
       01  WS-REGULATOR             PIC X(05) VALUE SPACES.
       01  WS-BOOKING-CENTRE        PIC X(12) VALUE SPACES.
       01  WS-MGMT-FEE-BPS          PIC 9(03) VALUE ZERO.
       01  WS-LARGE-POS-THRESHOLD   PIC 9(09)V99
                                      VALUE ZERO.
       01  WS-SUITABILITY-FWK       PIC X(20) VALUE SPACES.
       01  WS-KMS-VAULT-NAME        PIC X(12) VALUE SPACES.
       01  WS-DISCLOSURE-TEXT       PIC X(80) VALUE SPACES.

      * --- Secret references (Azure Key Vault, never plaintext) ---
      * Resolved at runtime by platform infrastructure.
       01  WS-DB-CONN-SECRET        PIC X(60) VALUE SPACES.
       01  WS-API-KEY-SECRET        PIC X(60) VALUE SPACES.

      * --- Portfolio input record ---
       01  WS-PORTFOLIO-ID          PIC X(12).
       01  WS-MARKET-VALUE          PIC 9(11)V99.
       01  WS-MGMT-FEE              PIC 9(09)V99.
       01  WS-FEE-RATE              PIC 9V9999.
       01  WS-IS-REPORTABLE         PIC X(01).
       01  WS-REPORT-FLAG           PIC X(01) VALUE "N".
       01  WS-EOF-FLAG              PIC X(01) VALUE "N".
       01  WS-RECORD-COUNT          PIC 9(06) VALUE ZERO.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 0500-LOAD-ENTITY-CONFIG
           PERFORM 1000-INITIALISE
           PERFORM 2000-PROCESS-PORTFOLIOS
               UNTIL WS-EOF-FLAG = "Y"
           PERFORM 9000-FINALISE
           STOP RUN.

       0500-LOAD-ENTITY-CONFIG.
      * Read ENTITY_ID from environment; default SG.
           ACCEPT WS-ENV-ENTITY-ID FROM ENVIRONMENT "ENTITY_ID"
           IF WS-ENV-ENTITY-ID = SPACES OR LOW-VALUES
               MOVE "SG" TO WS-ENV-ENTITY-ID
           END-IF

           EVALUATE WS-ENV-ENTITY-ID
             WHEN "SG"
               MOVE "SG"        TO WS-ENTITY-CODE
               MOVE "SGD"       TO WS-CURRENCY
               MOVE "en_SG"     TO WS-LOCALE
               MOVE "MAS"       TO WS-REGULATOR
               MOVE "Singapore" TO WS-BOOKING-CENTRE
               MOVE 50           TO WS-MGMT-FEE-BPS
               MOVE 250000.00    TO WS-LARGE-POS-THRESHOLD
               MOVE "MAS_FAA_2002"    TO WS-SUITABILITY-FWK
               MOVE "wealth-sg"       TO WS-KMS-VAULT-NAME
               MOVE "MAS Notice FAA: Past performance is not i"
               & "ndicative"   TO WS-DISCLOSURE-TEXT
               MOVE "${KEYVAULT:wealth-sg-db-connection-string}"
                 TO WS-DB-CONN-SECRET
               MOVE "${KEYVAULT:wealth-sg-api-key}"
                 TO WS-API-KEY-SECRET
             WHEN "HK"
               MOVE "HK"         TO WS-ENTITY-CODE
               MOVE "HKD"        TO WS-CURRENCY
               MOVE "en_HK"      TO WS-LOCALE
               MOVE "SFC"        TO WS-REGULATOR
               MOVE "Hong Kong"  TO WS-BOOKING-CENTRE
               MOVE 60            TO WS-MGMT-FEE-BPS
               MOVE 1000000.00    TO WS-LARGE-POS-THRESHOLD
               MOVE "SFC_COP_2019"    TO WS-SUITABILITY-FWK
               MOVE "wealth-hk"       TO WS-KMS-VAULT-NAME
               MOVE "SFC Code of Conduct: Risk disclosure req"
               & "uired"       TO WS-DISCLOSURE-TEXT
               MOVE "${KEYVAULT:wealth-hk-db-connection-string}"
                 TO WS-DB-CONN-SECRET
               MOVE "${KEYVAULT:wealth-hk-api-key}"
                 TO WS-API-KEY-SECRET
             WHEN "CH"
               MOVE "CH"         TO WS-ENTITY-CODE
               MOVE "CHF"        TO WS-CURRENCY
               MOVE "de_CH"      TO WS-LOCALE
               MOVE "FINMA"      TO WS-REGULATOR
               MOVE "Zurich"     TO WS-BOOKING-CENTRE
               MOVE 80            TO WS-MGMT-FEE-BPS
               MOVE 5000000.00    TO WS-LARGE-POS-THRESHOLD
               MOVE "FINMA_LSFin_2020" TO WS-SUITABILITY-FWK
               MOVE "wealth-ch"       TO WS-KMS-VAULT-NAME
               MOVE "FINMA LSFin: Suitability disclosure requ"
               & "ired"        TO WS-DISCLOSURE-TEXT
               MOVE "${KEYVAULT:wealth-ch-db-connection-string}"
                 TO WS-DB-CONN-SECRET
               MOVE "${KEYVAULT:wealth-ch-api-key}"
                 TO WS-API-KEY-SECRET
             WHEN OTHER
               DISPLAY "FATAL: Unknown ENTITY_ID: "
                   WS-ENV-ENTITY-ID
               STOP RUN
           END-EVALUATE.

       1000-INITIALISE.
           DISPLAY "PORTVAL starting — entity "
               WS-ENTITY-CODE ", regulator " WS-REGULATOR
           MOVE ZERO TO WS-RECORD-COUNT
           MOVE "N" TO WS-EOF-FLAG.

       2000-PROCESS-PORTFOLIOS.
           PERFORM 2100-READ-PORTFOLIO
           IF WS-EOF-FLAG NOT = "Y"
               PERFORM 3000-VALUATE-PORTFOLIO
               ADD 1 TO WS-RECORD-COUNT
           END-IF.

       2100-READ-PORTFOLIO.
      * Stub read — production would READ from PORTIN-FILE.
           MOVE "Y" TO WS-EOF-FLAG.

       3000-VALUATE-PORTFOLIO.
           PERFORM 3100-COMPUTE-FEE
           PERFORM 3200-CHECK-REPORTABLE
           PERFORM 3300-EMIT-VALUATION.

       3100-COMPUTE-FEE.
      * Management fee = market value * bps / 10000.
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
           DISPLAY "PORTVAL complete — processed "
               WS-RECORD-COUNT " portfolios ("
               WS-ENTITY-CODE ")".
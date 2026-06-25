IDENTIFICATION DIVISION.
       PROGRAM-ID. PORTVAL.
      * Portfolio valuation batch — multi-entity deployment.
      * Entity context loaded from ACME_ENTITY_ID env variable.
      * Secrets use Azure Key Vault refs: ${KEYVAULT:...}

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
      * --- Entity context (loaded once at startup) ---
           COPY ENTITY-COPY.
      * --- Key Vault secret references ---
       01  WS-KV-DB-CONN            PIC X(60).
       01  WS-KV-VAULT-NAME         PIC X(20).
      * --- Portfolio input record ---
       01  WS-PORTFOLIO-ID          PIC X(12).
       01  WS-MARKET-VALUE          PIC 9(11)V99.
       01  WS-MGMT-FEE              PIC 9(09)V99.
       01  WS-FEE-RATE              PIC 9V9999.
       01  WS-IS-REPORTABLE         PIC X(01).
       01  WS-REPORT-FLAG           PIC X(01) VALUE "N".
       01  WS-EOF-FLAG              PIC X(01) VALUE "N".
       01  WS-RECORD-COUNT          PIC 9(06) VALUE ZERO.
       01  WS-ENV-ENTITY            PIC X(02).

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 0500-LOAD-ENTITY-CONTEXT
           PERFORM 1000-INITIALISE
           PERFORM 2000-PROCESS-PORTFOLIOS
               UNTIL WS-EOF-FLAG = "Y"
           PERFORM 9000-FINALISE
           STOP RUN.

       0500-LOAD-ENTITY-CONTEXT.
      * Read entity from env; default SG if unset/empty.
           ACCEPT WS-ENV-ENTITY FROM ENVIRONMENT
               "ACME_ENTITY_ID"
           IF WS-ENV-ENTITY = SPACES OR WS-ENV-ENTITY = LOW-VALUES
               MOVE "SG" TO WS-ENV-ENTITY
           END-IF
           MOVE WS-ENV-ENTITY TO WS-ENTITY-CODE
           EVALUATE WS-ENTITY-CODE
             WHEN "SG"
               MOVE "SGD"        TO WS-CURRENCY
               MOVE "en_SG"      TO WS-LOCALE
               MOVE "MAS"        TO WS-REGULATOR
               MOVE "Singapore"  TO WS-BOOKING-CENTRE
               MOVE 50           TO WS-MGMT-FEE-BPS
               MOVE 250000.00    TO WS-LARGE-POS-THRESHOLD
               MOVE "MAS_FAA_2002" TO WS-SUIT-FRAMEWORK
               MOVE "wealth-sg"  TO WS-KV-VAULT-NAME
               MOVE "${KEYVAULT:wealth-sg-db-connection-string}"
                 TO WS-KV-DB-CONN
               MOVE "MAS Notice FAA: Past performance is not ind"
               & "icative" TO WS-DISCLOSURE-TEXT
             WHEN "HK"
               MOVE "HKD"        TO WS-CURRENCY
               MOVE "en_HK"      TO WS-LOCALE
               MOVE "SFC"        TO WS-REGULATOR
               MOVE "Hong Kong"  TO WS-BOOKING-CENTRE
               MOVE 60           TO WS-MGMT-FEE-BPS
               MOVE 1000000.00   TO WS-LARGE-POS-THRESHOLD
               MOVE "SFC_COP_2019" TO WS-SUIT-FRAMEWORK
               MOVE "wealth-hk"  TO WS-KV-VAULT-NAME
               MOVE "${KEYVAULT:wealth-hk-db-connection-string}"
                 TO WS-KV-DB-CONN
               MOVE "SFC COP: Past performance is not indicative"
                 TO WS-DISCLOSURE-TEXT
             WHEN "CH"
               MOVE "CHF"        TO WS-CURRENCY
               MOVE "de_CH"      TO WS-LOCALE
               MOVE "FINMA"      TO WS-REGULATOR
               MOVE "Zurich"     TO WS-BOOKING-CENTRE
               MOVE 80           TO WS-MGMT-FEE-BPS
               MOVE 5000000.00   TO WS-LARGE-POS-THRESHOLD
               MOVE "FINMA_LSFin_2020" TO WS-SUIT-FRAMEWORK
               MOVE "wealth-ch"  TO WS-KV-VAULT-NAME
               MOVE "${KEYVAULT:wealth-ch-db-connection-string}"
                 TO WS-KV-DB-CONN
               MOVE "FINMA LSFin: Past performance is not indica"
               & "tive" TO WS-DISCLOSURE-TEXT
             WHEN OTHER
               DISPLAY "PORTVAL ABORT: Unknown entity "
                   WS-ENTITY-CODE
               STOP RUN
           END-EVALUATE.

       1000-INITIALISE.
           DISPLAY "PORTVAL starting — entity " WS-ENTITY-CODE
               ", regulator " WS-REGULATOR
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
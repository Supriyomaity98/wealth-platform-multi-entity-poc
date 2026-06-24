IDENTIFICATION DIVISION.
       PROGRAM-ID. PORTVAL.
      * Portfolio valuation batch — entity-aware via ENTITY-ID env var.
      * SG is the default baseline; HK and CH loaded via ENTITY-COPY.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
      * --- Entity context copybook ---
       COPY ENTITY-COPY.

      * --- Portfolio input record ---
       01  WS-PORTFOLIO-ID          PIC X(12).
       01  WS-MARKET-VALUE          PIC 9(11)V99.
       01  WS-MGMT-FEE              PIC 9(09)V99.
       01  WS-FEE-RATE              PIC 9V9999.
       01  WS-IS-REPORTABLE         PIC X(01).
       01  WS-REPORT-FLAG           PIC X(01) VALUE 'N'.
       01  WS-EOF-FLAG              PIC X(01) VALUE 'N'.
       01  WS-RECORD-COUNT          PIC 9(06) VALUE ZERO.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 0500-LOAD-ENTITY-CONFIG
           PERFORM 1000-INITIALISE
           PERFORM 2000-PROCESS-PORTFOLIOS
               UNTIL WS-EOF-FLAG = 'Y'
           PERFORM 9000-FINALISE
           STOP RUN.

       0500-LOAD-ENTITY-CONFIG.
      * Read ENTITY_ID from environment; default to SG baseline.
           MOVE FUNCTION TRIM(
               FUNCTION GETENV('ENTITY_ID'))
               TO WS-ENTITY-CODE
           IF WS-ENTITY-CODE = SPACES OR WS-ENTITY-CODE = LOW-VALUES
               MOVE 'SG' TO WS-ENTITY-CODE
           END-IF
           EVALUATE WS-ENTITY-CODE
               WHEN 'SG'
                   MOVE 'SGD'           TO WS-CURRENCY
                   MOVE 'en_SG'         TO WS-LOCALE
                   MOVE 'MAS'           TO WS-REGULATOR
                   MOVE 'Singapore'     TO WS-BOOKING-CENTRE
                   MOVE 50             TO WS-MGMT-FEE-BPS
                   MOVE 250000.00      TO WS-LARGE-POS-THRESHOLD
                   MOVE 'MAS_FAA_2002'  TO WS-SUITABILITY-FWK
                   MOVE '${KEYVAULT:wealth-sg-db-connection-string}'
                                        TO WS-KV-SECRET-REF
               WHEN 'HK'
                   MOVE 'HKD'           TO WS-CURRENCY
                   MOVE 'en_HK'         TO WS-LOCALE
                   MOVE 'SFC'           TO WS-REGULATOR
                   MOVE 'Hong Kong'     TO WS-BOOKING-CENTRE
                   MOVE 60             TO WS-MGMT-FEE-BPS
                   MOVE 1000000.00     TO WS-LARGE-POS-THRESHOLD
                   MOVE 'SFC_COP_2019'  TO WS-SUITABILITY-FWK
                   MOVE '${KEYVAULT:wealth-hk-db-connection-string}'
                                        TO WS-KV-SECRET-REF
               WHEN 'CH'
                   MOVE 'CHF'           TO WS-CURRENCY
                   MOVE 'de_CH'         TO WS-LOCALE
                   MOVE 'FINMA'         TO WS-REGULATOR
                   MOVE 'Zurich'        TO WS-BOOKING-CENTRE
                   MOVE 80             TO WS-MGMT-FEE-BPS
                   MOVE 5000000.00     TO WS-LARGE-POS-THRESHOLD
                   MOVE 'FINMA_LSFin_2020' TO WS-SUITABILITY-FWK
                   MOVE '${KEYVAULT:wealth-ch-db-connection-string}'
                                        TO WS-KV-SECRET-REF
               WHEN OTHER
                   DISPLAY 'PORTVAL ABORT: unknown ENTITY_ID '
                       WS-ENTITY-CODE
                   STOP RUN
           END-EVALUATE.

       1000-INITIALISE.
           DISPLAY 'PORTVAL starting — entity ' WS-ENTITY-CODE
               ' regulator ' WS-REGULATOR
           MOVE ZERO TO WS-RECORD-COUNT
           MOVE 'N' TO WS-EOF-FLAG.

       2000-PROCESS-PORTFOLIOS.
           PERFORM 2100-READ-PORTFOLIO
           IF WS-EOF-FLAG NOT = 'Y'
               PERFORM 3000-VALUATE-PORTFOLIO
               ADD 1 TO WS-RECORD-COUNT
           END-IF.

       2100-READ-PORTFOLIO.
      * Stub read — production would READ from PORTIN-FILE.
           MOVE 'Y' TO WS-EOF-FLAG.

       3000-VALUATE-PORTFOLIO.
           PERFORM 3100-COMPUTE-FEE
           PERFORM 3200-CHECK-REPORTABLE
           PERFORM 3300-EMIT-VALUATION.

       3100-COMPUTE-FEE.
      * Management fee = market value * bps / 10000.
           COMPUTE WS-FEE-RATE = WS-MGMT-FEE-BPS / 10000
           COMPUTE WS-MGMT-FEE = WS-MARKET-VALUE * WS-FEE-RATE.

       3200-CHECK-REPORTABLE.
      * Positions above entity threshold require regulatory disclosure.
           IF WS-MARKET-VALUE >= WS-LARGE-POS-THRESHOLD
               MOVE 'Y' TO WS-IS-REPORTABLE
           ELSE
               MOVE 'N' TO WS-IS-REPORTABLE
           END-IF.

       3300-EMIT-VALUATION.
           DISPLAY 'PORTFOLIO: ' WS-PORTFOLIO-ID
           DISPLAY '  CURRENCY: ' WS-CURRENCY
           DISPLAY '  BOOKING:  ' WS-BOOKING-CENTRE
           DISPLAY '  MKT-VAL:  ' WS-MARKET-VALUE
           DISPLAY '  MGMT-FEE: ' WS-MGMT-FEE
           DISPLAY '  REPORTABLE: ' WS-IS-REPORTABLE
           IF WS-IS-REPORTABLE = 'Y'
               DISPLAY '  REGULATOR: ' WS-REGULATOR
               DISPLAY '  FRAMEWORK: ' WS-SUITABILITY-FWK
           END-IF.

       9000-FINALISE.
           DISPLAY 'PORTVAL complete — processed '
               WS-RECORD-COUNT ' portfolios (' WS-ENTITY-CODE ')'.
IDENTIFICATION DIVISION.
       PROGRAM-ID. PORTVAL.
      * Portfolio valuation batch — multi-entity aware.
      * Entity set once at start via WEALTH_ENTITY_ID env var (default SG).

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
      * --- Entity identity ---
       01  WS-ENTITY-ID             PIC X(02) VALUE "SG".

      * Entity canonical constants (SG / HK / CH).
           COPY ENTITY-COPY.

      * --- Runtime entity fields (populated by 0100-LOAD-ENTITY-CONTEXT) ---
       01  WS-CURRENCY              PIC X(03).
       01  WS-LOCALE                PIC X(05).
       01  WS-REGULATOR             PIC X(08).
       01  WS-BOOKING-CENTRE        PIC X(16).
       01  WS-MGMT-FEE-BPS          PIC 9(03).
       01  WS-LARGE-POS-THRESHOLD   PIC 9(09)V99.
       01  WS-SUITABILITY           PIC X(20).
       01  WS-VAULT-REF             PIC X(60).

      * --- Portfolio input fields ---
       01  WS-PORTFOLIO-ID          PIC X(12).
       01  WS-MARKET-VALUE          PIC 9(11)V99.
       01  WS-MGMT-FEE              PIC 9(09)V99.
       01  WS-FEE-RATE              PIC 9V9999.
       01  WS-IS-REPORTABLE         PIC X(01).
       01  WS-EOF-FLAG              PIC X(01) VALUE "N".
       01  WS-RECORD-COUNT          PIC 9(06) VALUE ZERO.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 0100-LOAD-ENTITY-CONTEXT
           PERFORM 1000-INITIALISE
           PERFORM 2000-PROCESS-PORTFOLIOS
               UNTIL WS-EOF-FLAG = "Y"
           PERFORM 9000-FINALISE
           STOP RUN.

       0100-LOAD-ENTITY-CONTEXT.
      * Read WEALTH_ENTITY_ID env var; default SG if blank.
           ACCEPT WS-ENTITY-ID FROM ENVIRONMENT "WEALTH_ENTITY_ID"
           IF WS-ENTITY-ID = SPACES
               MOVE "SG" TO WS-ENTITY-ID
           END-IF
           EVALUATE WS-ENTITY-ID
               WHEN "SG"
                   MOVE EC-SG-CURRENCY    TO WS-CURRENCY
                   MOVE EC-SG-LOCALE      TO WS-LOCALE
                   MOVE EC-SG-REGULATOR   TO WS-REGULATOR
                   MOVE EC-SG-BOOKING     TO WS-BOOKING-CENTRE
                   MOVE EC-SG-FEE-BPS     TO WS-MGMT-FEE-BPS
                   MOVE EC-SG-THRESHOLD   TO WS-LARGE-POS-THRESHOLD
                   MOVE EC-SG-SUITABILITY TO WS-SUITABILITY
                   MOVE EC-SG-VAULT-REF   TO WS-VAULT-REF
               WHEN "HK"
                   MOVE EC-HK-CURRENCY    TO WS-CURRENCY
                   MOVE EC-HK-LOCALE      TO WS-LOCALE
                   MOVE EC-HK-REGULATOR   TO WS-REGULATOR
                   MOVE EC-HK-BOOKING     TO WS-BOOKING-CENTRE
                   MOVE EC-HK-FEE-BPS     TO WS-MGMT-FEE-BPS
                   MOVE EC-HK-THRESHOLD   TO WS-LARGE-POS-THRESHOLD
                   MOVE EC-HK-SUITABILITY TO WS-SUITABILITY
                   MOVE EC-HK-VAULT-REF   TO WS-VAULT-REF
               WHEN "CH"
                   MOVE EC-CH-CURRENCY    TO WS-CURRENCY
                   MOVE EC-CH-LOCALE      TO WS-LOCALE
                   MOVE EC-CH-REGULATOR   TO WS-REGULATOR
                   MOVE EC-CH-BOOKING     TO WS-BOOKING-CENTRE
                   MOVE EC-CH-FEE-BPS     TO WS-MGMT-FEE-BPS
                   MOVE EC-CH-THRESHOLD   TO WS-LARGE-POS-THRESHOLD
                   MOVE EC-CH-SUITABILITY TO WS-SUITABILITY
                   MOVE EC-CH-VAULT-REF   TO WS-VAULT-REF
               WHEN OTHER
                   DISPLAY "PORTVAL ABORT: unknown WEALTH_ENTITY_ID="
                       WS-ENTITY-ID
                   STOP RUN
           END-EVALUATE.

       1000-INITIALISE.
           DISPLAY "PORTVAL starting — entity " WS-ENTITY-ID
               " regulator " WS-REGULATOR
           MOVE ZERO TO WS-RECORD-COUNT
           MOVE "N"  TO WS-EOF-FLAG.

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
      * Management fee = market value * fee-bps / 10000.
           COMPUTE WS-FEE-RATE = WS-MGMT-FEE-BPS / 10000
           COMPUTE WS-MGMT-FEE = WS-MARKET-VALUE * WS-FEE-RATE.

       3200-CHECK-REPORTABLE.
      * Positions at or above entity threshold require disclosure.
           IF WS-MARKET-VALUE >= WS-LARGE-POS-THRESHOLD
               MOVE "Y" TO WS-IS-REPORTABLE
           ELSE
               MOVE "N" TO WS-IS-REPORTABLE
           END-IF.

       3300-EMIT-VALUATION.
           DISPLAY "PORTFOLIO:    " WS-PORTFOLIO-ID
           DISPLAY "  CURRENCY:   " WS-CURRENCY
           DISPLAY "  BOOKING:    " WS-BOOKING-CENTRE
           DISPLAY "  SUITABILITY:" WS-SUITABILITY
           DISPLAY "  MKT-VAL:    " WS-MARKET-VALUE
           DISPLAY "  MGMT-FEE:   " WS-MGMT-FEE
           DISPLAY "  REPORTABLE: " WS-IS-REPORTABLE
           IF WS-IS-REPORTABLE = "Y"
               DISPLAY "  VAULT-REF:  " WS-VAULT-REF
           END-IF.

       9000-FINALISE.
           DISPLAY "PORTVAL complete — processed "
               WS-RECORD-COUNT " portfolios (" WS-ENTITY-ID ")".
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PORTVAL.
      * Portfolio valuation batch — Singapore deployment.
      * Hardcoded SG values below are the multi-entity refactoring target.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
      * --- Entity constants (refactoring target: load from config) ---
       01  WS-ENTITY-CODE           PIC X(02) VALUE "SG".
       01  WS-CURRENCY              PIC X(03) VALUE "SGD".
       01  WS-LOCALE                PIC X(05) VALUE "en_SG".
       01  WS-REGULATOR             PIC X(03) VALUE "MAS".
       01  WS-BOOKING-CENTRE        PIC X(12) VALUE "Singapore".
       01  WS-MGMT-FEE-BPS          PIC 9(03) VALUE 50.
       01  WS-LARGE-POS-THRESHOLD   PIC 9(09)V99
                                      VALUE 250000.00.
       01  WS-DISCLOSURE-TEXT       PIC X(80)
           VALUE "MAS Notice FAA: Past performance is not indicative".
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
      * Entry point — initialise and process portfolio file.
           PERFORM 1000-INITIALISE
           PERFORM 2000-PROCESS-PORTFOLIOS
               UNTIL WS-EOF-FLAG = "Y"
           PERFORM 9000-FINALISE
           STOP RUN.

       1000-INITIALISE.
      * Open input portfolio file and reset counters.
           DISPLAY "PORTVAL starting — entity SG, regulator MAS"
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
      * Stub read — production would READ from PORTIN-FILE.
           MOVE "Y" TO WS-EOF-FLAG.

       3000-VALUATE-PORTFOLIO.
      * Apply Singapore fee schedule and check reportability.
           PERFORM 3100-COMPUTE-FEE
           PERFORM 3200-CHECK-REPORTABLE
           PERFORM 3300-EMIT-VALUATION.

       3100-COMPUTE-FEE.
      * Management fee = market value * bps / 10000 (50 bps SG schedule).
           COMPUTE WS-FEE-RATE = WS-MGMT-FEE-BPS / 10000
           COMPUTE WS-MGMT-FEE = WS-MARKET-VALUE * WS-FEE-RATE.

       3200-CHECK-REPORTABLE.
      * Positions above 250000 SGD require regulatory disclosure.
           IF WS-MARKET-VALUE >= WS-LARGE-POS-THRESHOLD
               MOVE "Y" TO WS-IS-REPORTABLE
           ELSE
               MOVE "N" TO WS-IS-REPORTABLE
           END-IF.

       3300-EMIT-VALUATION.
      * Write valuation line with SG booking centre and disclosure.
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
           DISPLAY "PORTVAL complete — processed "
               WS-RECORD-COUNT " portfolios (SG)".

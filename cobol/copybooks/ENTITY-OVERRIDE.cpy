*================================================================*
      * ENTITY-OVERRIDE.cpy — Per-entity override value table.          *
      * HK and CH overrides relative to SG baseline.                   *
      * Included where a program needs a lookup table rather than       *
      * inline EVALUATE logic.                                          *
      *================================================================*
       01  WS-ENTITY-TABLE.
           05  WS-ENTITY-ENTRY OCCURS 3 TIMES
                               INDEXED BY WS-ENT-IDX.
               10  WS-ENT-CODE      PIC X(02).
               10  WS-ENT-CCY       PIC X(03).
               10  WS-ENT-LOCALE    PIC X(05).
               10  WS-ENT-REG       PIC X(05).
               10  WS-ENT-BOOKING   PIC X(12).
               10  WS-ENT-FEE-BPS   PIC 9(03).
               10  WS-ENT-THRESHOLD PIC 9(09)V99.
               10  WS-ENT-SUIT-FWK  PIC X(20).
               10  WS-ENT-KV-VAULT  PIC X(20).

       PROCEDURE DIVISION.
      *--- Populate table at program initialisation ---
       INIT-ENTITY-TABLE.
           MOVE 'SG'              TO WS-ENT-CODE(1)
           MOVE 'SGD'             TO WS-ENT-CCY(1)
           MOVE 'en_SG'           TO WS-ENT-LOCALE(1)
           MOVE 'MAS'             TO WS-ENT-REG(1)
           MOVE 'Singapore'       TO WS-ENT-BOOKING(1)
           MOVE 50                TO WS-ENT-FEE-BPS(1)
           MOVE 250000.00         TO WS-ENT-THRESHOLD(1)
           MOVE 'MAS_FAA_2002'    TO WS-ENT-SUIT-FWK(1)
           MOVE 'wealth-sg'       TO WS-ENT-KV-VAULT(1)

           MOVE 'HK'              TO WS-ENT-CODE(2)
           MOVE 'HKD'             TO WS-ENT-CCY(2)
           MOVE 'en_HK'           TO WS-ENT-LOCALE(2)
           MOVE 'SFC'             TO WS-ENT-REG(2)
           MOVE 'Hong Kong'       TO WS-ENT-BOOKING(2)
           MOVE 60                TO WS-ENT-FEE-BPS(2)
           MOVE 1000000.00        TO WS-ENT-THRESHOLD(2)
           MOVE 'SFC_COP_2019'    TO WS-ENT-SUIT-FWK(2)
           MOVE 'wealth-hk'       TO WS-ENT-KV-VAULT(2)

           MOVE 'CH'              TO WS-ENT-CODE(3)
           MOVE 'CHF'             TO WS-ENT-CCY(3)
           MOVE 'de_CH'           TO WS-ENT-LOCALE(3)
           MOVE 'FINMA'           TO WS-ENT-REG(3)
           MOVE 'Zurich'          TO WS-ENT-BOOKING(3)
           MOVE 80                TO WS-ENT-FEE-BPS(3)
           MOVE 5000000.00        TO WS-ENT-THRESHOLD(3)
           MOVE 'FINMA_LSFin_2020' TO WS-ENT-SUIT-FWK(3)
           MOVE 'wealth-ch'       TO WS-ENT-KV-VAULT(3).
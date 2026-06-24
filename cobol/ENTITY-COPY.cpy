*================================================================*
      * ENTITY-COPY.cpy - Entity configuration copybook
      * Canonical entity values for multi-entity wealth platform.
      * Included by PORTVAL.cbl via COPY ENTITY-COPY.
      *================================================================*

      * --- Entity configuration table ---
       01  WS-ENTITY-CONFIG-TABLE.
         05  WS-CFG-SG.
           10  FILLER PIC X(02) VALUE "SG".
           10  FILLER PIC X(03) VALUE "SGD".
           10  FILLER PIC X(05) VALUE "en_SG".
           10  FILLER PIC X(05) VALUE "MAS".
           10  FILLER PIC X(12) VALUE "Singapore".
           10  FILLER PIC 9(03) VALUE 50.
           10  FILLER PIC 9(09)V99 VALUE 250000.00.
           10  FILLER PIC X(20) VALUE "MAS_FAA_2002".
           10  FILLER PIC X(12) VALUE "wealth-sg".
         05  WS-CFG-HK.
           10  FILLER PIC X(02) VALUE "HK".
           10  FILLER PIC X(03) VALUE "HKD".
           10  FILLER PIC X(05) VALUE "en_HK".
           10  FILLER PIC X(05) VALUE "SFC".
           10  FILLER PIC X(12) VALUE "Hong Kong".
           10  FILLER PIC 9(03) VALUE 60.
           10  FILLER PIC 9(09)V99 VALUE 1000000.00.
           10  FILLER PIC X(20) VALUE "SFC_COP_2019".
           10  FILLER PIC X(12) VALUE "wealth-hk".
         05  WS-CFG-CH.
           10  FILLER PIC X(02) VALUE "CH".
           10  FILLER PIC X(03) VALUE "CHF".
           10  FILLER PIC X(05) VALUE "de_CH".
           10  FILLER PIC X(05) VALUE "FINMA".
           10  FILLER PIC X(12) VALUE "Zurich".
           10  FILLER PIC 9(03) VALUE 80.
           10  FILLER PIC 9(09)V99 VALUE 5000000.00.
           10  FILLER PIC X(20) VALUE "FINMA_LSFin_2020".
           10  FILLER PIC X(12) VALUE "wealth-ch".

      * --- 88-level conditions on active entity ---
       01  WS-ACTIVE-ENTITY         PIC X(02) VALUE "SG".
           88 ENTITY-IS-SG          VALUE "SG".
           88 ENTITY-IS-HK          VALUE "HK".
           88 ENTITY-IS-CH          VALUE "CH".
           88 ENTITY-IS-VALID       VALUE "SG" "HK" "CH".

      * --- Key Vault reference patterns (no plaintext secrets) ---
      * DB connection: ${KEYVAULT:wealth-{entity}-db-connection-string}
      * API key:       ${KEYVAULT:wealth-{entity}-api-key}
      * Platform infra resolves these at runtime.
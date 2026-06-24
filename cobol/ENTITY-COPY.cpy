*================================================================*
      * ENTITY-COPY.cpy — Canonical entity constants (SG / HK / CH).
      * All values hard-pinned to shared contract canonical values.
      * Secrets referenced via Key Vault pattern only; no plaintext.
      *================================================================*

      * --- SG (Singapore — home entity, baseline) ---
       01  EC-SG-CURRENCY       PIC X(03) VALUE "SGD".
       01  EC-SG-LOCALE         PIC X(05) VALUE "en_SG".
       01  EC-SG-REGULATOR      PIC X(08) VALUE "MAS".
       01  EC-SG-BOOKING        PIC X(16) VALUE "Singapore".
       01  EC-SG-FEE-BPS        PIC 9(03) VALUE 050.
       01  EC-SG-THRESHOLD      PIC 9(09)V99 VALUE 250000.00.
       01  EC-SG-SUITABILITY    PIC X(20) VALUE "MAS_FAA_2002".
       01  EC-SG-VAULT-REF      PIC X(60)
           VALUE "${KEYVAULT:wealth-sg-db-password}".

      * --- HK (Hong Kong) ---
       01  EC-HK-CURRENCY       PIC X(03) VALUE "HKD".
       01  EC-HK-LOCALE         PIC X(05) VALUE "en_HK".
       01  EC-HK-REGULATOR      PIC X(08) VALUE "SFC".
       01  EC-HK-BOOKING        PIC X(16) VALUE "Hong Kong".
       01  EC-HK-FEE-BPS        PIC 9(03) VALUE 060.
       01  EC-HK-THRESHOLD      PIC 9(09)V99 VALUE 1000000.00.
       01  EC-HK-SUITABILITY    PIC X(20) VALUE "SFC_COP_2019".
       01  EC-HK-VAULT-REF      PIC X(60)
           VALUE "${KEYVAULT:wealth-hk-db-password}".

      * --- CH (Switzerland) ---
       01  EC-CH-CURRENCY       PIC X(03) VALUE "CHF".
       01  EC-CH-LOCALE         PIC X(05) VALUE "de_CH".
       01  EC-CH-REGULATOR      PIC X(08) VALUE "FINMA".
       01  EC-CH-BOOKING        PIC X(16) VALUE "Zurich".
       01  EC-CH-FEE-BPS        PIC 9(03) VALUE 080.
       01  EC-CH-THRESHOLD      PIC 9(09)V99 VALUE 5000000.00.
       01  EC-CH-SUITABILITY    PIC X(20) VALUE "FINMA_LSFin_2020".
       01  EC-CH-VAULT-REF      PIC X(60)
           VALUE "${KEYVAULT:wealth-ch-db-password}".
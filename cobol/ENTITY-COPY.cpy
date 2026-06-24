*================================================================*
      * ENTITY-COPY.cpy — Working-storage entity context fields.        *
      * Included by PORTVAL.cbl (and any program needing entity state). *
      * Values are populated at runtime by 0500-LOAD-ENTITY-CONFIG.     *
      * Supported entity codes: SG (default), HK, CH.                  *
      *================================================================*
       01  WS-ENTITY-CODE           PIC X(02) VALUE 'SG'.
       01  WS-CURRENCY              PIC X(03) VALUE 'SGD'.
       01  WS-LOCALE                PIC X(05) VALUE 'en_SG'.
       01  WS-REGULATOR             PIC X(05) VALUE 'MAS'.
       01  WS-BOOKING-CENTRE        PIC X(12) VALUE 'Singapore'.
       01  WS-MGMT-FEE-BPS          PIC 9(03)  VALUE 50.
       01  WS-LARGE-POS-THRESHOLD   PIC 9(09)V99
                                      VALUE 250000.00.
       01  WS-SUITABILITY-FWK       PIC X(20) VALUE 'MAS_FAA_2002'.
      * Key Vault reference — never a plaintext secret.
       01  WS-KV-SECRET-REF         PIC X(60)
           VALUE '${KEYVAULT:wealth-sg-db-connection-string}'.
      *
      * 88-level condition names for SG baseline (canonical values).
       01  WS-ENTITY-IS-SG          PIC X(01) VALUE 'N'.
           88 ENTITY-SG             VALUE 'Y'.
       01  WS-ENTITY-IS-HK          PIC X(01) VALUE 'N'.
           88 ENTITY-HK             VALUE 'Y'.
       01  WS-ENTITY-IS-CH          PIC X(01) VALUE 'N'.
           88 ENTITY-CH             VALUE 'Y'.
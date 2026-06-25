* ENTITY-COPY.cpy — Entity context working-storage fields.
      * Included by PORTVAL.cbl via COPY statement.
      * Values populated at runtime by 0500-LOAD-ENTITY-CONTEXT.
       01  WS-ENTITY-CODE           PIC X(02).
           88 ENTITY-SG              VALUE "SG".
           88 ENTITY-HK              VALUE "HK".
           88 ENTITY-CH              VALUE "CH".
       01  WS-CURRENCY              PIC X(03).
           88 CURRENCY-SGD           VALUE "SGD".
           88 CURRENCY-HKD           VALUE "HKD".
           88 CURRENCY-CHF           VALUE "CHF".
       01  WS-LOCALE                PIC X(05).
           88 LOCALE-EN-SG           VALUE "en_SG".
           88 LOCALE-EN-HK           VALUE "en_HK".
           88 LOCALE-DE-CH           VALUE "de_CH".
       01  WS-REGULATOR             PIC X(05).
           88 REG-MAS                VALUE "MAS".
           88 REG-SFC                VALUE "SFC".
           88 REG-FINMA              VALUE "FINMA".
       01  WS-BOOKING-CENTRE        PIC X(12).
           88 BOOK-SINGAPORE         VALUE "Singapore".
           88 BOOK-HONG-KONG         VALUE "Hong Kong".
           88 BOOK-ZURICH            VALUE "Zurich".
       01  WS-MGMT-FEE-BPS          PIC 9(03).
           88 FEE-BPS-50             VALUE 50.
           88 FEE-BPS-60             VALUE 60.
           88 FEE-BPS-80             VALUE 80.
       01  WS-LARGE-POS-THRESHOLD   PIC 9(09)V99.
       01  WS-SUIT-FRAMEWORK        PIC X(20).
           88 SUIT-MAS-FAA           VALUE "MAS_FAA_2002".
           88 SUIT-SFC-COP           VALUE "SFC_COP_2019".
           88 SUIT-FINMA-LSFIN       VALUE "FINMA_LSFin_2020".
       01  WS-DISCLOSURE-TEXT       PIC X(80).
*================================================================*
      * ENTITY-CONFIG.cpy — 88-level canonical entity constants.        *
      * All three entities: SG, HK, CH.                                *
      *================================================================*
      * --- Currency codes ---
       01  WS-CFG-CURRENCY          PIC X(03).
           88 CFG-CCY-SGD           VALUE 'SGD'.
           88 CFG-CCY-HKD           VALUE 'HKD'.
           88 CFG-CCY-CHF           VALUE 'CHF'.
      * --- Locale codes ---
       01  WS-CFG-LOCALE            PIC X(05).
           88 CFG-LOC-SG            VALUE 'en_SG'.
           88 CFG-LOC-HK            VALUE 'en_HK'.
           88 CFG-LOC-CH            VALUE 'de_CH'.
      * --- Regulators ---
       01  WS-CFG-REGULATOR         PIC X(05).
           88 CFG-REG-MAS           VALUE 'MAS'.
           88 CFG-REG-SFC           VALUE 'SFC'.
           88 CFG-REG-FINMA         VALUE 'FINMA'.
      * --- Fee bps ---
       01  WS-CFG-FEE-BPS           PIC 9(03).
           88 CFG-FEE-SG            VALUE 50.
           88 CFG-FEE-HK            VALUE 60.
           88 CFG-FEE-CH            VALUE 80.
      * --- Large-position thresholds ---
       01  WS-CFG-THRESHOLD         PIC 9(09)V99.
           88 CFG-THR-SG            VALUE 250000.00.
           88 CFG-THR-HK            VALUE 1000000.00.
           88 CFG-THR-CH            VALUE 5000000.00.
      * --- Suitability frameworks ---
       01  WS-CFG-SUIT-FWK          PIC X(20).
           88 CFG-SUIT-SG           VALUE 'MAS_FAA_2002'.
           88 CFG-SUIT-HK           VALUE 'SFC_COP_2019'.
           88 CFG-SUIT-CH           VALUE 'FINMA_LSFin_2020'.
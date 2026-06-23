*================================================================*
      * ENTITY-COPY.cpy                                                *
      * Copybook defining the entity configuration structure.          *
      * Matches the shared contract keys exactly:                      *
      *   entity_id, entity_full_name, currency, fee_schedule_bps,     *
      *   min_portfolio_threshold, default_locale, booking_centre,     *
      *   data_region, kms_vault_name, suitability_framework,          *
      *   regulatory_bodies, disclosure_locale_map                     *
      *                                                                *
      * Used by: PORTVAL.cbl (and any future entity-aware programs)    *
      * Key Vault pattern: ${KEYVAULT:<kms_vault_name>/<secret_name>}  *
      *================================================================*

       01  ENTITY-CONFIG.
           05  EC-ENTITY-ID              PIC X(02).
           05  EC-ENTITY-FULL-NAME       PIC X(60).
           05  EC-CURRENCY               PIC X(03).
           05  EC-FEE-SCHEDULE-BPS       PIC 9(03).
           05  EC-MIN-PORTFOLIO-THRESHOLD
                                         PIC 9(09)V99.
           05  EC-DEFAULT-LOCALE         PIC X(05).
           05  EC-BOOKING-CENTRE         PIC X(20).
           05  EC-DATA-REGION            PIC X(20).
           05  EC-KMS-VAULT-NAME         PIC X(20).
           05  EC-SUITABILITY-FRAMEWORK  PIC X(20).
      *    regulatory_bodies - up to 3 bodies per entity
           05  EC-REGULATORY-BODIES.
               10  EC-REGULATORY-BODY-1  PIC X(10).
               10  EC-REGULATORY-BODY-2  PIC X(10).
               10  EC-REGULATORY-BODY-3  PIC X(10).
      *    disclosure_locale_map - up to 4 locale paths per entity
           05  EC-DISCLOSURE-LOCALE-MAP.
               10  EC-DISCLOSURE-PATH-1  PIC X(40).
               10  EC-DISCLOSURE-PATH-2  PIC X(40).
               10  EC-DISCLOSURE-PATH-3  PIC X(40).
               10  EC-DISCLOSURE-PATH-4  PIC X(40).
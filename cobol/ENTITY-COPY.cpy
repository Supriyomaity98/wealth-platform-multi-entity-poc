*================================================================*
      * ENTITY-COPY.CPY  Entity config model copybook                  *
      * Keys mirror shared contract entity-config.yaml manifest keys.  *
      * Populated by PORTVAL at runtime from mounted YAML manifest.    *
      * KeyVault pattern: ${KEYVAULT:wealth-{entity_id}-manifest}      *
      *================================================================*
       01  EC-ENTITY-CONFIG.
           05  EC-ENTITY-ID             PIC X(04).
           05  EC-CURRENCY              PIC X(03).
           05  EC-LOCALE-PRIMARY        PIC X(10).
           05  EC-LOCALE-SUPPORTED      PIC X(30).
           05  EC-FEE-BPS               PIC 9(04).
           05  EC-RELATIONSHIP-THRESHOLD
                                        PIC 9(11)V99.
           05  EC-DATA-REGION           PIC X(20).
           05  EC-KV-VAULT-NAME         PIC X(30).
           05  EC-KV-VAULT-URI          PIC X(80).
           05  EC-REGULATOR             PIC X(10).
           05  EC-SUITABILITY-FRAMEWORK PIC X(30).
           05  EC-DISCLOSURE-LOCALE-REQ PIC X(01).
           05  EC-CROSS-BORDER-CONSENT  PIC X(01).
           05  EC-DATA-RESIDENCY-STRICT PIC X(01).
           05  EC-MULTILINGUAL-DOCS-REQ PIC X(01).
           05  EC-AUDIT-LOG-RETENTION   PIC 9(05).
           05  EC-SCHEMA-ENTITY-ENFORCED
                                        PIC X(01).
           05  EC-BOOKING-CENTRE        PIC X(20).
           05  EC-LARGE-POS-THRESHOLD   PIC 9(11)V99.
           05  EC-CONFIG-LOADED-FLAG    PIC X(01) VALUE "N".
           05  EC-VALIDATION-MSG        PIC X(80).
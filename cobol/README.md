# COBOL — PORTVAL

`PORTVAL.cbl` is a nightly batch program that reads portfolio records, computes management fees, checks large-position reportability, and emits valuation lines for the Singapore booking centre.

## Singapore assumptions (refactoring targets)

| Constant | Current (SG) | HK target | CH target |
|----------|-------------|-----------|-----------|
| Currency | SGD | HKD | CHF |
| Locale | en_SG | en_HK / zh_HK | de_CH / fr_CH |
| Regulator | MAS | SFC | FINMA |
| Booking centre | Singapore | Hong Kong | Zurich |
| Management fee | 50 bps | Entity fee schedule | Entity fee schedule |
| Large position threshold | 250,000 SGD | HKD equivalent | CHF equivalent |
| Disclosure text | MAS Notice FAA | SFC code of conduct | FINMA disclosure rules |

## Refactoring approach

Replace `WORKING-STORAGE` literals with a configuration record loaded at batch start (entity code, currency, fee bps, threshold, disclosure template). The paragraph structure can remain; only the data source changes.

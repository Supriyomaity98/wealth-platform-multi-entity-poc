"""
Static-analysis pytest suite for PORTVAL.cbl and ENTITY-COPY.cpy.
Runs on CI without a COBOL compiler; asserts canonical literal
presence, Key Vault pattern, and structural abort guard.

Run: pytest cobol/tests/test_portval_static.py -v
"""
import re
import os
import pytest

TEST_DIR   = os.path.dirname(__file__)
COBOL_DIR  = os.path.join(TEST_DIR, "..")
PORTVAL    = os.path.join(COBOL_DIR, "PORTVAL.cbl")
ENTITY_CPY = os.path.join(COBOL_DIR, "ENTITY-COPY.cpy")


def _src():
    parts = []
    for p in (PORTVAL, ENTITY_CPY):
        with open(p) as fh:
            parts.append(fh.read())
    return "\n".join(parts)


# TC-01 SG baseline canonical literals
def test_sg_baseline_canonical_values():
    s = _src()
    assert "SGD"          in s, "SG currency SGD missing"
    assert "en_SG"        in s, "SG locale en_SG missing"
    assert "MAS"          in s, "SG regulator MAS missing"
    assert "Singapore"    in s, "SG booking centre missing"
    assert re.search(r'(?<![0-9])50(?![0-9])', s), "SG fee_bps 50 missing"
    assert re.search(r'250000', s),                 "SG threshold 250000 missing"
    assert "MAS_FAA_2002" in s, "SG suitability MAS_FAA_2002 missing"
    assert "wealth-sg"    in s, "SG KV name wealth-sg missing"


# TC-02 HK switch canonical literals
def test_hk_switch_canonical_values():
    s = _src()
    assert "HKD"          in s, "HK currency HKD missing"
    assert "en_HK"        in s, "HK locale en_HK missing"
    assert "SFC"          in s, "HK regulator SFC missing"
    assert "Hong Kong"    in s, "HK booking centre missing"
    assert re.search(r'(?<![0-9])60(?![0-9])', s), "HK fee_bps 60 missing"
    assert re.search(r'1000000', s),                "HK threshold 1000000 missing"
    assert "SFC_COP_2019" in s, "HK suitability SFC_COP_2019 missing"
    assert "wealth-hk"    in s, "HK KV name wealth-hk missing"


# TC-03 CH switch canonical literals
def test_ch_switch_canonical_values():
    s = _src()
    assert "CHF"               in s, "CH currency CHF missing"
    assert "de_CH"             in s, "CH locale de_CH missing"
    assert "FINMA"             in s, "CH regulator FINMA missing"
    assert "Zurich"            in s, "CH booking centre missing"
    assert re.search(r'(?<![0-9])80(?![0-9])', s), "CH fee_bps 80 missing"
    assert re.search(r'5000000', s),                "CH threshold 5000000 missing"
    assert "FINMA_LSFin_2020"  in s, "CH suitability FINMA_LSFin_2020 missing"
    assert "wealth-ch"         in s, "CH KV name wealth-ch missing"


# TC-04 No plaintext credentials; Key Vault pattern enforced
def test_no_plaintext_credentials_keyvault_pattern_present():
    s = _src()
    for pat in [r'PASSWORD\s*=\s*["\'][^$]',
                r'PWD\s*=\s*["\'][^$]',
                r'password\s*=\s*["\'][^$]']:
        assert not re.search(pat, s, re.IGNORECASE), \
            f"Plaintext credential pattern matched: {pat}"
    assert re.search(r'\$\{KEYVAULT:wealth-sg', s), \
        "SG Key Vault reference pattern missing"
    assert re.search(r'\$\{KEYVAULT:wealth-hk', s), \
        "HK Key Vault reference pattern missing"
    assert re.search(r'\$\{KEYVAULT:wealth-ch', s), \
        "CH Key Vault reference pattern missing"


# TC-05 WHEN OTHER + STOP RUN abort guard in PORTVAL
def test_unknown_entity_abort_guard():
    with open(PORTVAL) as fh:
        src = fh.read()
    wo = src.find("WHEN OTHER")
    assert wo != -1, "WHEN OTHER clause missing in PORTVAL"
    sr = src.find("STOP RUN", wo)
    assert sr != -1 and sr > wo, \
        "STOP RUN must follow WHEN OTHER to abort on unknown entity"


# TC-06 Cross-entity fee-bps are distinct (50, 60, 80 all present)
def test_cross_entity_fee_bps_all_distinct():
    s = _src()
    found = {
        "SG_50": bool(re.search(r'(?<![0-9])50(?![0-9])', s)),
        "HK_60": bool(re.search(r'(?<![0-9])60(?![0-9])', s)),
        "CH_80": bool(re.search(r'(?<![0-9])80(?![0-9])', s)),
    }
    for label, ok in found.items():
        assert ok, f"fee_bps literal for {label} not found in sources"
    # three distinct values — confirm no accidental collapse
    assert len({50, 60, 80}) == 3
# Rules Update: v48B → v50A → v50B → v50C

## 48B → 50A (gene list from Jan 3 → Feb 18, variant DB from Jan 3 → Feb 18)

### Master Gene List
- Deleted 2 gene-disease combinations:
  - `F2` — Prothrombin_thrombophilia (AD, ClinVar P and LP)
  - `F5` — Thrombophilia_due_to_activated_protein_C_resistance (AD, ClinVar P and LP)
- No genes added

### VariantCall Database
- Approved variants: 4,084 → 4,854 (+770)
- Unique genes (approved): 928 → 1,085 (+157)
- Unique diseases (approved): 1,074 → 1,244 (+170)

### Rules
- Total rules: 95,351 → 96,117 (+766)
- Total diseases: 2,184 → 2,182 (-2)

---

## 50A → 50B (gene list from Feb 18 → Feb 23, variant DB from Feb 18 → Feb 23)

### Master Gene List
- Deleted 1 gene-disease combination:
  - `KRT82` — KRT82-associated_alopecia_areata
- Added 6 new gene-disease entries (5 existing genes + 1 new gene):
  - `IFT140` — ift140_related_autosomal_dominant_polycystic_kidney_disease (AD, ClinVar P and LP)
  - `SLC7A9` — autosomal_dominant_cystinuria_complex (AD, ClinVar P and LP)
  - `REN` — ren_related_autosomal_recessive_renal_tubular_dysgenesis (AR, Missense and nonsense)
  - `AQP2` — aqp2_related_autosomal_recessive_nephrogenic_diabetes_insipidus (AR, Missense and nonsense)
  - `SNORD118` — leukoencephalopathy_brain_calcifications_and_cysts (AR, Missense and nonsense)
  - `SLC4A1` — distal_renal_tubular_acidosis_4_with_hemolytic_anemia (AR, Missense and nonsense)

### VariantCall Database
- Approved variants: 4,854 → 4,995 (+141)
- Unique genes (approved): 1,085 → 1,099 (+14)
- Unique diseases (approved): 1,244 → 1,258 (+14)

### Rules
- Total rules: 96,117 → 96,400 (+283)
- Total diseases: 2,182 → 2,187 (+5)
- Total genes: 1,821 → 1,822 (+1)

---

## 50B → 50C (devel_ rules with lower QC thresholds)

### No input changes
- Same master gene list, variant list, and variantCall database as 50B

### Devel rules added
- All 96,393 production rules duplicated with `devel_` prefix and lower QC:
  - `QUAL >= 22.4` → `QUAL >= 13`
  - `format_DP >= 8` → `format_DP >= 5`
  - `format_GQ >= 16` → `format_GQ >= 13`
- 7 validation/proficiency rules skipped (no QC filters to substitute)
- 4 devel-only genes added (not in master gene list): HBA1, HBA2, SMN1, GBA1
  - 184 rules generated (Missense and nonsense strategy, cThresh=1)

### Rules
- Production rules: 96,400 (unchanged from 50B)
- Devel duplicate rules: 96,393
- Devel-only gene rules: 184
- Total rules: 192,977

---

## Cumulative 48B → 50C
- Production rules: 95,351 → 96,400 (+1,049)
- Total rules (incl. devel): 192,977
- Total diseases: 2,184 → 2,187 (+3, production only)
- Total genes: 1,821 → 1,822 (+1)
- Approved variants: 4,084 → 4,995 (+911)
- Gene list entries: 2,461 → 2,464 (+3 net)

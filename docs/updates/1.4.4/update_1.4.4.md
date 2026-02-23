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
- Added 6 new entries (5 genes), but all have Science Name = NA so they are filtered out and do not yet generate rules:
  - `IFT140` — IFT140-related autosomal dominant polycystic kidney disease (AD, ClinVar P and LP)
  - `SLC7A9` — Autosomal dominant cystinuria, complex (AD, ClinVar P and LP)
  - `REN` — REN-related autosomal recessive renal tubular dysgenesis (AR, Missense and nonsense)
  - `AQP2` — AQP2-related autosomal recessive nephrogenic diabetes insipidus (AR, Missense and nonsense)
  - `SNORD118` — Leukoencephalopathy, brain calcifications, and cysts (AR, Missense and nonsense)
  - `SLC4A1` — Distal renal tubular acidosis 4 with hemolytic anemia (AR, Missense and nonsense)

### VariantCall Database
- Approved variants: 4,854 → 4,995 (+141)
- Unique genes (approved): 1,085 → 1,099 (+14)
- Unique diseases (approved): 1,244 → 1,258 (+14)

### Rules
- Total rules: 96,117 → 96,212 (+95)
- Total diseases: 2,182 → 2,181 (-1)

---

## 50B → 50C (devel_ rules with lower QC thresholds)

### No input changes
- Same master gene list, variant list, and variantCall database as 50B

### Devel rules added
- All 96,205 production rules duplicated with `devel_` prefix and lower QC:
  - `QUAL >= 22.4` → `QUAL >= 13`
  - `format_DP >= 8` → `format_DP >= 5`
  - `format_GQ >= 16` → `format_GQ >= 13`
- 7 validation/proficiency rules skipped (no QC filters to substitute)
- 4 devel-only genes added (not in master gene list): HBA1, HBA2, SMN1, GBA1
  - 184 rules generated (Missense and nonsense strategy, cThresh=1)

### Rules
- Production rules: 96,212 (unchanged from 50B)
- Devel duplicate rules: 96,205
- Devel-only gene rules: 184
- Total rules: 192,601

---

## Cumulative 48B → 50C
- Production rules: 95,351 → 96,212 (+861)
- Total rules (incl. devel): 192,601
- Total diseases: 2,184 → 2,181 (-3, production only)
- Approved variants: 4,084 → 4,995 (+911)
- Gene list entries: 2,461 → 2,464 (+3 net, but 6 new ones filtered due to missing Science Name)

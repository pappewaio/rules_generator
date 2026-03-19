# Rules Update Summary: Prior → Current (v1.4.4)

## Master Gene List Changes
- Deleted 3 gene-disease combinations:
  - `F2` — Prothrombin_thrombophilia (AD, ClinVar P and LP)
  - `F5` — Thrombophilia_due_to_activated_protein_C_resistance (AD, ClinVar P and LP)
  - `KRT82` — KRT82-associated_alopecia_areata
- Added 6 new gene-disease entries (5 existing genes + 1 new gene):
  - `IFT140` — ift140_related_autosomal_dominant_polycystic_kidney_disease (AD, ClinVar P and LP)
  - `SLC7A9` — autosomal_dominant_cystinuria_complex (AD, ClinVar P and LP)
  - `REN` — ren_related_autosomal_recessive_renal_tubular_dysgenesis (AR, Missense and nonsense)
  - `AQP2` — aqp2_related_autosomal_recessive_nephrogenic_diabetes_insipidus (AR, Missense and nonsense)
  - `SNORD118` — leukoencephalopathy_brain_calcifications_and_cysts (AR, Missense and nonsense)
  - `SLC4A1` — distal_renal_tubular_acidosis_4_with_hemolytic_anemia (AR, Missense and nonsense)

## VariantCall Database Changes
- Approved variants: 4,084 → 4,995 (+911)
- Unique genes (approved): 928 → 1,099 (+171)
- Unique diseases (approved): 1,074 → 1,258 (+184)

## Production Rules
- Total rules: 95,351 → 96,400 (+1,049)
- Total diseases: 2,184 → 2,187 (+3)
- Total genes: 1,821 → 1,822 (+1)
- Gene list entries: 2,461 → 2,464 (+3 net)

## Devel Rules (new)
- All 96,393 production rules duplicated with `devel_` prefix and lower QC:
  - `QUAL >= 22.4` → `QUAL >= 13`
  - `format_DP >= 8` → `format_DP >= 5`
  - `format_GQ >= 16` → `format_GQ >= 13`
- 4 devel-only genes added (not in master gene list): HBA1, HBA2, SMN1, GBA1
  - 184 rules generated (Missense and nonsense strategy, cThresh=1)
- Total devel rules: 96,577

## Total
- Production rules: 96,400
- Devel rules: 96,577
- Total rules in file: 192,977

# Rules Update Summary: Prior → Current (v1.4.4)

## Master Gene List Changes
- Deleted 3 gene-disease combinations:
  - `F2` — Prothrombin_thrombophilia (AD, ClinVar P and LP)
  - `F5` — Thrombophilia_due_to_activated_protein_C_resistance (AD, ClinVar P and LP)
  - `KRT82` — KRT82-associated_alopecia_areata
- Added 6 new entries (5 genes), but all have Science Name = NA so they are filtered out and do not yet generate rules:
  - `IFT140` — IFT140-related autosomal dominant polycystic kidney disease (AD, ClinVar P and LP)
  - `SLC7A9` — Autosomal dominant cystinuria, complex (AD, ClinVar P and LP)
  - `REN` — REN-related autosomal recessive renal tubular dysgenesis (AR, Missense and nonsense)
  - `AQP2` — AQP2-related autosomal recessive nephrogenic diabetes insipidus (AR, Missense and nonsense)
  - `SNORD118` — Leukoencephalopathy, brain calcifications, and cysts (AR, Missense and nonsense)
  - `SLC4A1` — Distal renal tubular acidosis 4 with hemolytic anemia (AR, Missense and nonsense)

## VariantCall Database Changes
- Approved variants: 4,084 → 4,995 (+911)
- Unique genes (approved): 928 → 1,099 (+171)
- Unique diseases (approved): 1,074 → 1,258 (+184)

## Production Rules
- Total rules: 95,351 → 96,212 (+861)
- Total diseases: 2,184 → 2,181 (-3)
- Gene list entries: 2,461 → 2,464 (+3 net, but 6 new ones filtered due to missing Science Name)

## Devel Rules (new)
- All 96,205 production rules duplicated with `devel_` prefix and lower QC:
  - `QUAL >= 22.4` → `QUAL >= 13`
  - `format_DP >= 8` → `format_DP >= 5`
  - `format_GQ >= 16` → `format_GQ >= 13`
- 4 devel-only genes added (not in master gene list): HBA1, HBA2, SMN1, GBA1
  - 184 rules generated (Missense and nonsense strategy, cThresh=1)
- Total devel rules: 96,389

## Total
- Production rules: 96,212
- Devel rules: 96,389
- Total rules in file: 192,601

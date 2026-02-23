# Plan: Step 50C — `devel_` Prefixed Rules with Lower QC Thresholds

## Goal

Add a set of **development-only rules** to the rules file, identifiable by a `devel_` prefix on the Disease name. These rules use lower quality control thresholds to capture variants that would be filtered out by production QC, enabling evaluation of borderline calls.

Two categories of devel rules:
1. **Duplicated rules:** Every existing (non-devel) rule is duplicated with `devel_` prefix and lower QC thresholds
2. **Devel-only genes:** New rules for genes not in the current master gene list: HBA1, HBA2, SMN1, GBA1

## Design Decisions

### 1. Post-processing approach

Take the finished rules file (e.g. 50B) as input and produce the new rules file (50C) by:
- Copying all original rules as-is
- Appending duplicated rules with `devel_` prefix and substituted QC values
- Appending new devel-only gene rules

This is implemented as a **separate Python script** (`bin/generate_devel_rules.py`) that runs after the main R rule generation. It doesn't touch the core rule generation logic at all.

### 2. Integration: `--devel-rules` flag on `generate_rules.sh`

Add a `--devel-rules` flag to the main `generate_rules.sh` script. When set:
1. The main R script runs normally and produces the base rules file
2. `generate_rules.sh` then calls `bin/generate_devel_rules.py` as a post-processing step
3. The post-processing script reads the base rules file + devel config, and writes the combined output

This keeps the workflow unified — one command to run everything:
```bash
./generate_rules.sh \
  --master-gene-list ... \
  --variant-list ... \
  --variantcall-database ... \
  --rules-version 50C \
  --compare-with-version 50B \
  --devel-rules \
  --version-comment "Added devel_ rules with lower QC"
```

### 3. Devel configuration: `config/devel/` in the step input folder

Each step's input folder already has a `config/` directory with rules templates, special cases, etc. The devel config lives alongside it:

```
generate_rules_input/version_50/step_50C/
├── config/
│   ├── devel/
│   │   ├── devel_settings.conf      # QC thresholds to use
│   │   └── devel_only_genes.tsv     # Extra genes (HBA1, HBA2, SMN1, GBA1)
│   ├── rules/
│   ├── special_cases/
│   ├── settings.conf
│   └── ...
```

**`devel_settings.conf`:**
```
DEVEL_QUAL=13
DEVEL_DP=5
DEVEL_GQ=13
DEVEL_CID_OFFSET=100000
```

**`devel_only_genes.tsv`:**
```
Gene	Disease	Inheritance	Carrier	Variants_To_Find
HBA1	devel_HBA1	NA	TRUE	Missense and nonsense
HBA2	devel_HBA2	NA	TRUE	Missense and nonsense
SMN1	devel_SMN1	NA	TRUE	Missense and nonsense
GBA1	devel_GBA1	NA	TRUE	Missense and nonsense
```

Since inheritance is NA and Carrier is TRUE, these get cThresh=1 (carrier genes always use threshold 1).

### 4. QC threshold substitution

Current production QC values in rules:
```
QUAL >= 22.4 && format_DP >= 8 && format_GQ >= 16
```

Devel QC values:
```
QUAL >= 13 && format_DP >= 5 && format_GQ >= 13
```

For each production rule that contains QC filters, the post-processing script:
1. Prepends `devel_` to the Disease name
2. Replaces the three QC values via literal string substitution
3. Offsets the cID by +100,000

**Rules without QC filters:** Only 7 rules in the entire file lack QC filters — 3 Validation rules and 4 CHEK2 proficiency training rules (all with cID >= 10000). These are special-purpose rules and are skipped during duplication since duplicating them would produce identical rules under a different disease name. All other rules, including variantCall database position-specific rules, do include QC filters and will be duplicated.

### 5. Devel-only genes (HBA1, HBA2, SMN1, GBA1)

These genes are not in the master gene list. The post-processing script generates rules for them using the same rule templates from `config/rules/` (non_splice_pos_rules, non_splice_rules, spliceai_rules, frequency_rules).

- **Strategy:** "Missense and nonsense" (most comprehensive)
- **Inheritance:** NA, Carrier=TRUE → cThresh=1 (not associated with any particular disease)
- **Disease names:** `devel_HBA1`, `devel_HBA2`, `devel_SMN1`, `devel_GBA1`
- **QC thresholds:** Uses the lower devel thresholds only
- **cID range:** Starts after the offset devel duplicates (e.g., 200,001+)

### 6. Output file structure

The 50C rules file contains, in order:
1. All original production rules (unchanged from 50B)
2. All `devel_`-prefixed duplicates of production rules (with lower QC, skipping rules without QC filters)
3. `devel_`-prefixed rules for devel-only genes (HBA1, HBA2, SMN1, GBA1)

Expected size: ~96,212 original + ~96,205 devel duplicates (7 validation/proficiency rules skipped) + ~80 devel-only gene rules ≈ ~192,500 rules

### 7. Open questions

- **Should the gnomADe_AF threshold also be relaxed for devel rules, or keep at < 0.01?**
- **Any additional devel-only genes beyond HBA1, HBA2, SMN1, GBA1?**
- **For devel-only genes, do they need terminal cutoff positions (from the Gene table), or skip those?**

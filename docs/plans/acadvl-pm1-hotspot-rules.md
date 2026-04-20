# Plan: ACADVL PM1 Hotspot Region Rules

## Goal

Add extra rules for ACADVL that detect variants in PM1 hotspot/functional regions with relaxed criteria:
- **MAF:** MAX_AF < 0.001 (all populations, instead of gnomADe_AF < 0.01)
- **Regions:** Only detect within specific PM1 protein regions using the new `protein_pos_start`/`protein_pos_end` fields
- **Consequences:** missense_variant, inframe_deletion, inframe_insertion (3 rules per region)
- **Coexistence:** These rules coexist with existing ACADVL rules during evaluation, distinguished by a reserved cID (9999)

Long-term, these rules will replace the current ACADVL rules once validated.

## Dependency: Protein Position Parser (Issue 586)

The rare variant classifier is being updated with a new `derive_vep_fields.sh` script that parses VEP's `Protein_position` field (e.g., `3/655`, `5-10/655`) into three derived numeric fields:
- `protein_pos_start` — start amino acid position
- `protein_pos_end` — end amino acid position
- `protein_pos_length` — total protein length

This means **rules can reference protein positions directly** instead of needing genomic coordinate conversion. Example rule condition:
```
protein_pos_start >= 1 && protein_pos_end <= 40
```

This eliminates the coordinate conversion problem entirely — no need to map protein positions to GRCh38 genomic coordinates or worry about negative strand orientation.

## Current State

ACADVL currently has 55 production rules (+ 55 devel duplicates = 110 total):
- Disease: `Very_long-chain_acyl-CoA_dehydrogenase_deficiency_VLCAD`
- Strategy: "Missense and nonsense" (frameshift, stop_gained, ClinVar, missense, splice, SpliceAI)
- cID: 587, cThresh: 1 (Carrier=TRUE)
- 9 position-specific rules from variantCall database
- All use `gnomADe_AF < 0.01` and standard QC filters

## Design Decisions

### 1. Implementation approach: post-processing (like devel rules)

Add the ACADVL PM1 rules as another post-processing step in `bin/generate_devel_rules.py` (or a new companion script). This is consistent with how devel rules work — a mechanical addition to the finished rules file without touching the core R generator.

**Rationale:** These are experimental/evaluation rules. Keeping them as post-processing means:
- No risk to existing rule generation
- Easy to add/remove/modify independently
- Clear separation between production rules and experimental rules

### 2. Configuration: `config/devel/acadvl_pm1_regions.tsv`

A config file defining the PM1 regions using protein positions directly:

```
# ACADVL PM1 hotspot regions
# Protein positions in HGVS nomenclature (full protein, including signal peptide)
# Note: positions from PMIDs marked with * are in mature protein nomenclature;
# +40 AA has been added to convert to HGVS nomenclature
Region_Name	Protein_Start	Protein_End	Description
signal_peptide	1	40	p.1-40 mitochondrial signal peptide
nucleotide_binding_1	254	263	p.214-223 (+40) nucleotide/substrate binding
nucleotide_binding_2	289	291	p.249-251 (+40) nucleotide/substrate binding
cpg_R326	326	326	p.R326 CpG dinucleotide
fad_binding	421	422	p.381-382 (+40) FAD binding and salt-bridge
cpg_R429	429	429	p.R429 CpG dinucleotide
fad_dimer_E441	441	441	p.E441 adjacent to FAD binding, dimer formation loop
dimerization_R459	459	459	p.R459 dimerization
membrane_binding	521	556	p.481-516 (+40) membrane binding
nucleotide_binding_3	602	602	p.562 (+40) nucleotide/substrate binding
```

**Note on +40 adjustment:** Entries from PMIDs 18227065 and 20060901 (marked with `*`) describe positions in mature protein nomenclature (without signal peptide). These have been adjusted by +40 to reach HGVS nomenclature. Entries from other PMIDs (9973285, 14517516) and the signal peptide itself are already in HGVS nomenclature and are used as-is. **These positions need to be verified before implementation.**

### 3. Rule structure

Each PM1 region generates **3 rules** — one per consequence type:

```
Very_long-chain_acyl-CoA_dehydrogenase_deficiency_VLCAD	SYMBOL == ACADVL && Consequence == missense_variant && protein_pos_start >= 1 && protein_pos_end <= 40 && MAX_AF < 0.001 && QUAL >= 22.4 && format_DP >= 8 && format_GQ >= 16	9999	>=	1
Very_long-chain_acyl-CoA_dehydrogenase_deficiency_VLCAD	SYMBOL == ACADVL && Consequence == inframe_deletion && protein_pos_start >= 1 && protein_pos_end <= 40 && MAX_AF < 0.001 && QUAL >= 22.4 && format_DP >= 8 && format_GQ >= 16	9999	>=	1
Very_long-chain_acyl-CoA_dehydrogenase_deficiency_VLCAD	SYMBOL == ACADVL && Consequence == inframe_insertion && protein_pos_start >= 1 && protein_pos_end <= 40 && MAX_AF < 0.001 && QUAL >= 22.4 && format_DP >= 8 && format_GQ >= 16	9999	>=	1
```

Key differences from standard ACADVL rules:
- **MAX_AF < 0.001** instead of `gnomADe_AF < 0.01` (stricter, all populations)
- **Protein position range** using `protein_pos_start >= X && protein_pos_end <= Y`
- **Consequence filter** limited to missense_variant, inframe_deletion, inframe_insertion
- **No ClinVar filter** — not filtering by ClinVar status
- **cID = 9999** — reserved, distinguishes from production cID 587

QC filters (QUAL, DP, GQ) remain at production levels.

**Expected rule count:** 10 regions × 3 consequences = **30 rules** (+ 30 devel-QC duplicates if desired)

### 4. cID = 9999 as reserved experimental ID

Using 9999 as a fixed cID for these rules:
- Clearly separable from production (cIDs 1–~2500) and validation (10000+) and devel (100000+)
- Same disease name as existing ACADVL rules so they can coexist
- cThresh = 1 (Carrier=TRUE, consistent with existing ACADVL)
- When ready to replace, remove cID 587 rules and change 9999 → 587 (or just reassign)

### 5. Devel duplicates

The devel-rules post-processing will also create `devel_` duplicates of these PM1 rules with lower QC thresholds (QUAL >= 13, DP >= 5, GQ >= 13), getting cID = 109999 (9999 + 100000 offset).

## Open Questions

1. **Protein position adjustment verification:** Are the +40 adjustments for mature protein positions correct? Need confirmation from the colleague who provided the PM1 regions.

2. **Should devel-QC duplicates of these PM1 rules also be generated?** (Currently assumed yes)

3. **Is MAX_AF the correct field name** in the pipeline's VCF annotation? Need to confirm the exact column name available after VEP annotation.

## Implementation Steps (pending approval)

1. Verify the protein positions in `acadvl_pm1_regions.tsv` (especially the +40 adjustments)
2. Create `config/devel/acadvl_pm1_regions.tsv` in the step input folder
3. Extend `bin/generate_devel_rules.py` to read the PM1 config and append rules (or create a companion script)
4. The `--devel-rules` flag on `generate_rules.sh` already triggers post-processing — extend it to also handle PM1 rules when the config file is present
5. Test with step_51A generation

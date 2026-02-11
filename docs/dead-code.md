# Dead Code Inventory

Identified 2026-02-11 after the main gene loop was inlined in `generate_rules()`.

## Summary

| File | Function | Lines | Status | Reason |
|------|----------|-------|--------|--------|
| rule_generator.R | generate_gene_rules | 286-326 | Dead | Logic inlined into main loop (lines 930-1012). Never called. |
| rule_generator.R | generate_ptv_only_rules | 497-518 | Dead | Only called from dead generate_gene_rules. Inlined at 939-942. |
| rule_generator.R | generate_clinvar_rules | 520-531 | Dead | Only called from dead generate_gene_rules. Inlined at 944-946. |
| rule_generator.R | generate_supplemental_rules | 533-564 | Dead | Only called from dead generate_gene_rules. Inlined at 948-966. |
| rule_generator.R | generate_missense_nonsense_rules | 612-660 | Dead | Only called from dead generate_gene_rules. Inlined at 968-1004. |
| generate_rules_utils.R | get_script_dir | 11-38 | Dead | Defined but never called anywhere in the project. |

Total: approximately 150 lines of dead code across 6 functions.

## Details

### 1. generate_gene_rules (rule_generator.R:286-326)

Dispatcher function that routed to generate_ptv_only_rules, generate_clinvar_rules,
generate_supplemental_rules, generate_missense_nonsense_rules, or generate_special_rules
based on the variants_to_find value. Its logic was inlined directly into the main gene loop
inside generate_rules() (starting at line 930) during the vectorization work.

No remaining call sites. generate_gene_rules( does not appear anywhere outside its definition.

### 2. generate_ptv_only_rules (rule_generator.R:497-518)

Created PTV-only rules (frameshift + stop_gained). Only call site is line 304, inside
generate_gene_rules (which is itself dead). The equivalent logic now lives at lines 939-942
of the main loop.

### 3. generate_clinvar_rules (rule_generator.R:520-531)

Created ClinVar P/LP rules. Only call site is line 307 inside dead generate_gene_rules.
Equivalent logic at lines 944-946.

### 4. generate_supplemental_rules (rule_generator.R:533-564)

Created supplemental variant list rules with ClinVar benign exclusion. Only call site is
line 310 inside dead generate_gene_rules. Equivalent logic at lines 948-966.

Note: process_supplemental_variants (called from within this function at line 560) is
NOT dead. It is also called directly from the main loop at line 965.

### 5. generate_missense_nonsense_rules (rule_generator.R:612-660)

Created missense/nonsense rules with position exclusion logic. Only call site is line 313
inside dead generate_gene_rules. Equivalent logic at lines 968-1004 of the main loop.

### 6. get_script_dir (generate_rules_utils.R:11-38)

Utility to determine the directory of the running script. Never called anywhere in the
project. The entrypoint generate_rules_simplified.R has its own inline version of
the same logic (lines 7-19).

## Functions that are NOT dead (but look like they might be)

These functions are called from dead code, but also have live call sites:

- exclusion_rule_function (line 268): Called from generate_special_rules (line 679),
  which is alive (called at line 1007). Also called from dead functions at lines 508/624.

- generate_special_rules (line 671): Called from the main loop at line 1007 for
  variants_to_find == "Special". Also called from dead generate_gene_rules at line 316.

- process_supplemental_variants (line 570): Called from the main loop at line 965.
  Also called from dead generate_supplemental_rules at line 560.

- add_homozygous_rules (line 724): Called from the main loop at line 1022.

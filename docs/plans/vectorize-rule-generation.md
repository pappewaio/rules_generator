# Plan: Optimize Rule Generation Performance

## Problem (original)

The rule generation step takes **294 seconds** out of a 305-second total run.
The initial assumption was that the bottleneck was the per-gene loop in
`generate_rules()` which processes 2,407 genes one at a time.

## Actual bottleneck (discovered 2026-02-11)

After adding timing instrumentation to every section, the real breakdown is:

| Section | Time | % of RULE GENERATION step |
|---------|------|---------------------------|
| **perform_quality_control** | **287.4s** | **98.2%** |
| main gene loop | 2.7s | 0.9% |
| fix_rule_spacing | 1.8s | 0.6% |
| generate_gene_list_json | 0.6s | 0.2% |
| cID_lookup build | 0.1s | <0.1% |
| flatten + write rules | 0.04s | <0.1% |

The main gene loop (which we spent phases A-E optimizing) only takes **2.7 seconds**.
Nearly all time is spent in `perform_quality_control()`, specifically a loop that
runs `grep(gene, rules_data$RULE)` for each of ~1,800 unique genes against 91,268
rule strings.

## What perform_quality_control does

The function (`rule_generator.R`, lines 1300-1333) runs after rules are written
to disk. It does two checks:

### Check 1: Find genes with no rules (the bottleneck)

```r
rules_data <- read.csv(output_filename, sep = "\t", stringsAsFactors = FALSE)

no_rules_genes <- character()
for (gene in unique(gene_list$Gene)) {
  if (is.na(gene)) next
  if (length(grep(gene, rules_data$RULE)) == 0) {
    no_rules_genes <- c(no_rules_genes, gene)
  }
}
```

This reads the entire 91,268-line rules TSV back into a data frame, then for
each of the ~1,800 unique genes, runs `grep(gene, rules_data$RULE)` which is
a **regex scan** of all 91,268 RULE strings. That means approximately
1,800 x 91,268 = **164 million regex comparisons**. This takes 287 seconds.

The purpose is to warn if any gene from the input gene list ended up with
zero rules in the output (which would indicate a bug or unhandled variant type).

### Check 2: Flag weird disease names

```r
disease_names <- unique(gene_list$Disease)
weird_names <- disease_names[grepl("[^a-zA-Z0-9_-]", disease_names)]
```

This is instant (tens of disease names checked against a simple regex).

## What has been done (Phases A-E)

All phases from the original plan were implemented and verified with
byte-identical output to version 48B:

| Phase | What | Result |
|-------|------|--------|
| A | Pre-compute FORMAT_GQ_THRESHOLD gsub, exclusion zone lookup | Done |
| B | Pre-compute cID assignments with cumsum | Done |
| C | Collect rules in memory list, single writeLines at end | Done |
| D | Inline missense/nonsense logic in main loop | Done |
| E | Inline all variant types (PTV, Clinvar, supplemental) in main loop | Done |
| - | Batch log_gene_processing writes | Done |

**Outcome**: The main gene loop now takes **2.7 seconds** (down from an estimated
similar amount before -- these optimizations were clean but the loop was never
the real bottleneck). Output is byte-identical to version 48B.

The original plan targeted the wrong code. The gene loop was already fast;
`perform_quality_control` was consuming 98% of the time.

## Plan: Fix perform_quality_control (the actual bottleneck)

### Current cost: 287.4 seconds (98% of the total)

The problem is `grep(gene, rules_data$RULE)` inside a loop. `grep` uses regex
matching, which is expensive, and it scans all 91K strings per gene.

### Proposed fix: Replace grep loop with a single vectorized lookup

Every rule string in the RULE column contains `SYMBOL == GENENAME ` as its
first element (that is how rules are constructed). Instead of doing regex per
gene, we can extract gene names from the rules once and use set operations:

```r
# Extract gene names from rules (all rules start with "SYMBOL == GENE ...")
rule_genes <- sub("^SYMBOL == (\\S+) .*", "\\1", rules_data$RULE)

# Also handle SpliceAI rules: "SpliceAI_pred_SYMBOL == GENE ..."
spliceai_mask <- startsWith(rules_data$RULE, "SpliceAI_pred_SYMBOL")
rule_genes[spliceai_mask] <- sub("^SpliceAI_pred_SYMBOL == (\\S+).*", "\\1",
                                  rules_data$RULE[spliceai_mask])

# Unique genes that have at least one rule
genes_with_rules <- unique(rule_genes)

# Genes with no rules = set difference
input_genes <- unique(gene_list$Gene)
input_genes <- input_genes[!is.na(input_genes)]
no_rules_genes <- setdiff(input_genes, genes_with_rules)
```

This does:
- One `sub()` pass over 91K strings to extract gene names (vectorized, no loop)
- One `unique()` call
- One `setdiff()` call

**Expected time**: Under 1 second (one vectorized regex pass instead of 1,800).

**Risk**: Low. The rule format is consistent (`SYMBOL == GENE ...` or
`SpliceAI_pred_SYMBOL == GENE ...`). We can validate by checking that the set
of no_rules_genes is identical before and after.

**Expected output change**: None. The function only produces warnings and returns
metadata; it does not modify the rules file.

### Verification

Run with both old and new implementation and compare:
- The `no_rules_genes` list must be identical
- The `weird_names` list must be identical (unchanged code)
- Total timing should drop from ~300s to ~13s

### Goal (updated)

Reduce the RULE GENERATION step from ~293s to under **10 seconds**
while maintaining byte-identical output.

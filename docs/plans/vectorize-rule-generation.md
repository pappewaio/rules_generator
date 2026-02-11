# Plan: Vectorize the Per-Gene Rule Generation Loop

## Problem

The rule generation step takes **294 seconds** out of a 305-second total run.
Almost all of that time is spent in a nested loop in `generate_rules()`
(`bin/R/rule_generator.R` ~line 861):

```r
for (disease_name in disease_order) {
  gene_list_here <- gene_lists_by_disease[[disease_name]]
  for (j in 1:nrow(gene_list_here)) {
    gene_info <- gene_list_here[j, , drop = FALSE]
    gene_rules <- generate_gene_rules(gene_info, ...)
    traced_writeLines(gene_rules, output_file)
    ...
  }
}
```

This processes **2,407 genes one at a time**, calling `generate_gene_rules()` on
each row, which in turn dispatches to one of five sub-functions depending on
`Variants.To.Find`. Each call does string concatenation with `paste()` and writes
results to disk immediately via `traced_writeLines()`.

## Input Distribution (version 48B)

| Variants.To.Find             | Count | Code Path                       |
|------------------------------|------:|---------------------------------|
| Missense and nonsense        | 1,824 | `generate_missense_nonsense_rules()` |
| Clinvar P and LP             |   408 | `generate_clinvar_rules()`       |
| See supplemental variant list|   148 | `generate_supplemental_rules()`  |
| PTV only                     |    23 | `generate_ptv_only_rules()`      |
| Special                      |     4 | `generate_special_rules()`       |

**Missense and nonsense** dominates at 76% of genes.

## Cost Breakdown Per Gene

Each gene iteration does:
1. **Row extraction**: `gene_list_here[j, , drop = FALSE]` (data frame subsetting)
2. **String assembly**: `paste0(gene_rule, template_rules, exclusion, frequency)` for multiple templates
3. **gsub per call**: `gsub("{FORMAT_GQ_THRESHOLD}", ...)` on `frequency_rule` (same value every time)
4. **Exclusion lookup**: `exclusion_rule_function(gene, cutoff_list)` with `rownames()` check
5. **Disk I/O**: `traced_writeLines()` which calls `normalizePath()`, `sys.calls()`, `format(Sys.time())`, `flush()` per write
6. **Logging**: `log_gene_processing()` per gene
7. **Homozygous duplication**: For AR non-carrier genes, regex-based `sub()` on every rule string, plus another `traced_writeLines()`

## Proposed Approach: Batch by Variants.To.Find Type

Instead of processing one gene at a time, group all genes by their
`Variants.To.Find` type and generate rules for each group in one vectorized pass.

### Step 1: Pre-compute shared values once (low risk, moderate gain)

Things computed identically for every gene but repeated 2,407 times:

- `frequency_rule`: `gsub("{FORMAT_GQ_THRESHOLD}", ..., config$rules$frequency_rules[1])` -- compute once before the loop
- `frequency_rule_special`: same pattern -- compute once
- Template vectors (`config$rules$clinvar_rules`, `config$rules$non_splice_pos_rules`, etc.) -- already vectors, just reference once

**Expected output change**: None. These are constant per run.

### Step 2: Batch "Clinvar P and LP" genes (low risk, moderate gain)

`generate_clinvar_rules()` is the simplest path -- it's just:

```r
strings <- paste(disease_name, paste0(gene_rule, clinvar_rules, frequency_rule), inheritance_rule, sep = "\t")
```

For all 408 Clinvar genes at once:
- Build `gene_rule` vector: `paste0("SYMBOL == ", genes, " ")`
- Build `inheritance_rule` vector: `paste(cIDs, cCond, cThresh, sep = "\t")`
- Use `outer()` or `expand.grid()` to combine each gene with each clinvar template
- Produce all rule strings in one vectorized `paste()` call

**Expected output change**: None. Same string concatenation, just batched.

### Step 3: Batch "PTV only" genes (low risk, small gain)

Same as Clinvar but with 2 PTV templates and an exclusion zone lookup.
Only 23 genes, so small absolute gain, but proves the pattern.

- Vectorize `exclusion_rule_function()` to accept a vector of genes and return a vector of exclusion strings
- Then batch-paste like Clinvar

**Expected output change**: None.

### Step 4: Batch "Missense and nonsense" genes (moderate risk, large gain)

This is the big one (1,824 genes, 76% of the work). The function generates
three rule categories (`non_splice_pos`, `non_splice`, `spliceai`) and then
applies position exclusions from config.

Vectorization approach:
- Build all gene rules as vectors
- Vectorize the exclusion zone lookup
- Batch-paste each of the three categories
- Apply position exclusions: pre-filter the exclusion table to matching genes,
  then apply `sub()` only to affected rules (instead of looping through all
  exclusions for every gene)

**Risk**: The position exclusion logic is the most complex part. Need careful
parity testing.

**Expected output change**: None if done correctly.

### Step 5: Handle "See supplemental variant list" genes (moderate risk, moderate gain)

This is more complex because each gene has a different number of variants from
the supplemental list, making uniform vectorization harder.

Approach:
- Pre-join `variant_list_data` with the gene list (one merge instead of 148
  individual subsets with `gsub()` comparisons)
- Group variant processing by type (in-gene SNV vs other)
- Generate rules per group

**Risk**: Variant parsing logic is gene-specific. Needs careful testing.

### Step 6: Reduce I/O overhead (low risk, moderate gain)

Currently `traced_writeLines()` is called ~2,454 times (once per gene plus
homozygous duplicates). Each call does:
- `summary(con)$description` to get file path
- `normalizePath()` on the path
- `sys.calls()` to get caller info
- `format(Sys.time())` for timestamp
- `writeLines()` + `flush()` on both the output file and the trace file

Instead:
- Collect all rule strings in a character vector
- Write once at the end with a single `writeLines(all_rules, output_file)`
- Write a single summary trace entry instead of per-gene trace entries

**Expected output change**: None to the rules file. Trace file will be shorter
(summary instead of per-operation entries).

### Step 7: Handle cID assignment (critical constraint)

The main complication for full vectorization is that `cID` increments
sequentially and AR non-carrier genes consume an extra cID for homozygous rules.
This creates a data dependency between iterations.

Solution: Pre-compute all cID assignments before generating any rules:

```r
# For each gene, determine how many cIDs it consumes
cid_increment <- ifelse(
  gene_list$Inheritance == "AR" & !gene_list$Carrier & gene_list$Variants.To.Find != "Special",
  2,  # one for main rules, one for homozygous
  1
)
cid_values <- cumsum(cid_increment)
```

This removes the sequential dependency entirely.

**Risk**: Must exactly match the current assignment logic. Verified by output diff.

## Implementation Order

| Phase | Steps | Risk | Gain |
|-------|-------|------|------|
| A     | 1 (pre-compute constants) | Very low | ~5-10% of rule gen time |
| B     | 7 + 2 + 3 (cID pre-compute, batch Clinvar + PTV) | Low | ~20% |
| C     | 6 (batch I/O) | Low | ~15-20% |
| D     | 4 (batch Missense) | Moderate | ~30-40% |
| E     | 5 (batch Supplemental) | Moderate | ~5-10% |

Each phase must produce byte-identical output to version 48B before proceeding.

## Verification

After each phase:

```bash
diff out_rule_generation/version_48/step_48B/outputs/*rules_file*.tsv \
     out_rule_generation/version_XX/outputs/*rules_file*.tsv
```

Must return 0 differences. Also compare:
- `list_of_analyzed_genes_science_pipeline_names.json`
- Line count of rules file
- `step_timings.json` for performance comparison

## Goal

Reduce the RULE GENERATION step from ~294s to under 60s (5x speedup)
while maintaining byte-identical output.

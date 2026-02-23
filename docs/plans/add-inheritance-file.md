# Plan: Add Disease-Gene Metadata File (issue-544)

## Goal

Generate a separate TSV file during rules generation that contains
disease-gene-specific information, starting with inheritance mode. This file
will be deployed alongside the existing rules TSV and gene-list JSON to S3,
and later consumed by RVC to match entries, add inheritance as a column to
variant hits, and write the result to JSON.

---

## Context

### What already exists

1. The **master gene list** (Excel input) already contains an `Inheritance`
   column. By the time it reaches the rule generator it is available as
   `gene_list$Inheritance` with values like `AR`, `AD`, `XLR`, `XLD`.
   The new TSV is essentially a 4-column subset of this data frame, written
   out with `traced_write_table()` (the same helper used for other TSV
   outputs in the codebase).

2. The `Carrier` flag (also from the master gene list, `gene_list$Carrier`,
   boolean) modifies the effective inheritance behaviour -- carriers are
   always treated as cThresh=1 regardless of inheritance mode. Both
   `Inheritance` and `Carrier` are included in the TSV so RVC has the full
   picture.

3. Deployment scripts push two files today:
   - Rules TSV -> `{version}/rules_main/`
   - Gene list JSON -> `{version}/`

### S3 production layout (version 1.4.0)

```
s3://nucleus-science-pipeline-permanent-files/
  rare_variant_classifier_associated_files/
    1.4.0/
      list_of_analyzed_genes_science_pipeline_names.json
      rules_main/
        2026-01-03_rules_file.tsv
```

The issue mentions *"the same folder hierarchy as we have for vcf_types"* and
anticipates that different vcf_types may have different inheritance modes in
the future. The metadata file will be placed in a `disease_gene_metadata_main/`
subdirectory, mirroring the `rules_main/` convention. When vcf_type
differentiation is needed, additional directories like
`disease_gene_metadata_{vcf_type}/` can be added alongside
`rules_{vcf_type}/`.

---

## Proposed TSV structure

One row per **gene-disease combination** (i.e. one row per entry in the
master gene list, matching the granularity of the rules file):

```
disease	gene	inheritance	carrier
Breast_cancer	BRCA1	AD	FALSE
Breast_cancer	BRCA2	AD	TRUE
Sickle_cell_disease	HBB	AR	FALSE
```

**Why TSV?**

- Consistent with the main rules file format (also TSV).
- Simple to produce from R (`write.table`), simple to consume downstream.
- Easy to extend with additional columns later (e.g. `cThresh`,
  `variants_to_find`).
- The JSON representation is the responsibility of RVC (downstream), not the
  rules generator.

**File name:** `YYYY-MM-DD_disease_gene_metadata.tsv` (date-prefixed, matching
the rules file convention)

---

## Implementation steps

### Step 1 -- New R function: `generate_disease_gene_metadata_tsv()`

**File:** `bin/R/rule_generator.R`

Add a new function that takes the `gene_list` data frame, subsets the four
relevant columns, and writes them as a TSV using `traced_write_table()`.

```r
generate_disease_gene_metadata_tsv <- function(gene_list, output_dir, logger) {
  log_info(logger, "Generating disease-gene metadata TSV file")

  valid <- !is.na(gene_list$Gene) & !is.na(gene_list$Disease)
  inheritance_df <- data.frame(
    disease     = gene_list$Disease[valid],
    gene        = gene_list$Gene[valid],
    inheritance = gene_list$Inheritance[valid],
    carrier     = gene_list$Carrier[valid],
    stringsAsFactors = FALSE
  )

  date_prefix <- format(Sys.Date(), "%Y-%m-%d")
  output_path <- file.path(output_dir, "outputs",
                           paste0(date_prefix, "_disease_gene_metadata.tsv"))
  traced_write_table(inheritance_df, output_path,
                     sep = "\t", row.names = FALSE, quote = FALSE)

  log_info(logger, paste("Generated disease-gene metadata TSV with",
                         nrow(inheritance_df), "entries"))
  invisible(output_path)
}
```

Four columns: `disease`, `gene`, `inheritance`, and `carrier`. More columns
can be added later without breaking downstream consumers.

### Step 2 -- Call the new function from `generate_rules()`

**File:** `bin/R/rule_generator.R`, inside `generate_rules()` right after
the `generate_gene_list_json()` call (around line 890).

```r
.t_inheritance <- proc.time()
inheritance_path <- generate_disease_gene_metadata_tsv(gene_list, config$output_dir, logger)
log_info(logger, paste("generate_disease_gene_metadata_tsv:",
                       round((proc.time() - .t_inheritance)["elapsed"], 2), "s"))
```

Also add `disease_gene_metadata_path = inheritance_path` to the returned result
list so downstream code (summary report, deployment) can reference it.

### Step 3 -- Deploy the new file to S3

The production deployment scripts (hand-written in
`out_rule_generation/version_XX/deployment/deploy_to_s3.sh`) and the
auto-generated template in `generate_rules_utils.R` both need to know
about the new file.

**3a.** Update `generate_deployment_script()` in `generate_rules_utils.R`
so the generated template references the new file. Since the generated
script delegates to `deployment/upload_to_s3.sh`, the cleanest approach
is to have `upload_to_s3.sh` automatically detect and upload
`YYYY-MM-DD_disease_gene_metadata.tsv` into a `disease_gene_metadata_main/`
subdirectory if the file exists in the outputs directory. This keeps
the per-version deploy scripts unchanged.

**3b.** For hand-written deploy scripts (like the ones for versions 48B
and 49), add an `aws s3 cp` line for the new file:

Production layout:
```bash
METADATA_FILE=$(ls "$OUTPUT_DIR"/outputs/*_disease_gene_metadata.tsv 2>/dev/null | head -1)
if [[ -n "$METADATA_FILE" ]]; then
    echo "Deploying disease-gene metadata TSV..."
    aws s3 cp "$METADATA_FILE" "$S3_BASE_PATH/$S3_VERSION/disease_gene_metadata_main/"
fi
```

Dev layout:
```bash
METADATA_FILE=$(ls "$OUTPUT_DIR"/outputs/*_disease_gene_metadata.tsv 2>/dev/null | head -1)
if [[ -n "$METADATA_FILE" ]]; then
    echo "Deploying disease-gene metadata TSV..."
    aws s3 cp "$METADATA_FILE" "$S3_BUCKET/disease_gene_metadata_main/"
fi
```

The `if` guard ensures backward compatibility: old versions that don't have
the file won't error.

**Resulting S3 layout (production):**

```
rare_variant_classifier_associated_files/
  1.5.0/
    list_of_analyzed_genes_science_pipeline_names.json
    disease_gene_metadata_main/
      YYYY-MM-DD_disease_gene_metadata.tsv  <-- NEW
    rules_main/
      YYYY-MM-DD_rules_file.tsv
```

### Step 4 -- Update `docs/generated_rule_files.md`

Add a row for the new file in the production and devel tables, and update
the naming conventions section.

### Step 5 -- Update summary report

**File:** `bin/R/generate_summary_report.R`

Two additions:

**5a. Part 3 -- Output Files table** (around line 1826, after the JSON
files loop). Add the metadata TSV to the `output_files` list so it appears
in the files table:

```r
metadata_tsv <- list.files(file.path(version_dir, "outputs"),
                           pattern = ".*_disease_gene_metadata\\.tsv$",
                           full.names = FALSE)
if (length(metadata_tsv) > 0) {
  output_files[["Disease-Gene Metadata"]] <- list(
    path = paste0("outputs/", metadata_tsv[1]),
    description = "Disease-gene metadata (inheritance, carrier status)"
  )
}
```

Also add `"Disease-Gene Metadata" = "Disease-Gene Metadata"` to the
`display_names` switch.

**5b. Part 2 -- New summary table** after the existing "Inheritance
Patterns" section (around line 1740). Add a small table summarising the
metadata TSV contents:

```r
# Disease-Gene Metadata Summary
metadata_file <- list.files(file.path(version_dir, "outputs"),
                            pattern = ".*_disease_gene_metadata\\.tsv$",
                            full.names = TRUE)
if (length(metadata_file) > 0) {
  metadata <- read.csv(metadata_file[1], sep = "\t", stringsAsFactors = FALSE)

  # Try to load previous version's metadata for comparison
  prev_metadata <- NULL
  if (!is.null(previous_version_dir)) {
    prev_metadata_file <- list.files(file.path(previous_version_dir, "outputs"),
                                     pattern = ".*_disease_gene_metadata\\.tsv$",
                                     full.names = TRUE)
    if (length(prev_metadata_file) > 0) {
      prev_metadata <- read.csv(prev_metadata_file[1], sep = "\t",
                                stringsAsFactors = FALSE)
    }
  }

  cur_inh <- table(metadata$inheritance)
  cur_carrier <- sum(metadata$carrier == TRUE | metadata$carrier == "TRUE")

  prev_inh <- if (!is.null(prev_metadata)) table(prev_metadata$inheritance) else NULL
  prev_carrier <- if (!is.null(prev_metadata))
    sum(prev_metadata$carrier == TRUE | prev_metadata$carrier == "TRUE") else NA

  # Build rows for each metric
  all_patterns <- sort(unique(c(names(cur_inh),
                                if (!is.null(prev_inh)) names(prev_inh))))
  metrics <- c("Total entries", all_patterns, "Carrier entries")
  cur_vals <- c(nrow(metadata), sapply(all_patterns, function(p) as.integer(cur_inh[p] %||% 0)), cur_carrier)
  prev_vals <- if (!is.null(prev_metadata)) {
    c(nrow(prev_metadata), sapply(all_patterns, function(p) as.integer(prev_inh[p] %||% 0)), prev_carrier)
  } else rep(NA, length(metrics))
  changes <- cur_vals - prev_vals

  meta_summary <- data.frame(
    Metric = metrics,
    Previous = prev_vals,
    Current = cur_vals,
    Change = changes,
    stringsAsFactors = FALSE
  )
  report <- c(report, "## Disease-Gene Metadata", "")
  report <- c(report, kable(meta_summary, format = "markdown",
                            align = c("l", "r", "r", "r")))
  report <- c(report, "")
  report <- c(report, paste0("**File:** `outputs/",
                             basename(metadata_file[1]), "`"))
  report <- c(report, "")
}
```

This produces a table like:

| Metric          | Previous | Current | Change |
|:----------------|--------:|--------:|-------:|
| Total entries   |   2,407 |   2,407 |      0 |
| AD              |     705 |     705 |      0 |
| AR              |   1,556 |   1,556 |      0 |
| XLD             |      36 |      36 |      0 |
| XLR             |     110 |     110 |      0 |
| Carrier entries |     312 |     312 |      0 |

---

## What is NOT in scope for the rules generator

As noted in the issue, the following are **RVC-side** tasks and out of scope
for this change:

- Adding a script in RVC's `main.sh` that reads `disease_gene_metadata.tsv`
- Matching entries to variant hits and adding inheritance as a column
- Writing inheritance into the output JSON

---

## Design decisions and rationale

| Decision | Choice | Rationale |
|----------|--------|-----------|
| File granularity | One row per gene-disease pair | Matches rules file granularity; RVC can do a simple lookup by (disease, gene) |
| File format | TSV | Consistent with the main rules file; simple to produce and consume; JSON is RVC's responsibility |
| What to include | `disease`, `gene`, `inheritance`, `carrier` columns | Inheritance + carrier together give RVC the full picture |
| S3 placement | `disease_gene_metadata_main/` subdirectory | Mirrors `rules_main/`; ready for `disease_gene_metadata_{vcf_type}/` expansion |
| Deploy mechanism | `if -f` guard in deploy scripts | Backward-compatible; old versions without the file won't fail |

---

## Verification

1. Run rules generation for an existing version and confirm
   `YYYY-MM-DD_disease_gene_metadata.tsv` appears in `outputs/`.
2. Validate the TSV: every (disease, gene) pair in the master gene list
   should have exactly one row.
3. Spot-check inheritance values against the source Excel.
4. Dry-run the deploy script and confirm the file is included in the S3 copy
   commands.

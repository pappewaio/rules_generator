# Data Flow (Current Production)

## Overview

This document traces how data flows through the rules generation system, from input files to final output.

## Input Files

### Master Gene List (Excel)
**Sheet**: 1

Contains genes to generate rules for:
- Gene name and disease
- Inheritance pattern
- Variants to find (strategy type)
- Terminal cutoff positions
- Carrier and complex status

### Variant List (Excel)
**Sheet**: 3 (not sheet 1!)

Contains specific variants for supplemental strategy genes:
- Gene name
- HGVSc notation
- Position, Ref, Alt
- Consequence

### VariantCall Database (Optional)
**Format**: CSV or Excel

External database of variant calls, used for additional analysis.

## Stage 1: Input Loading

### `load_excel_files()` in `rule_generator.R`

```
[master_gene_list.xlsx] ──▶ openxlsx::read.xlsx(sheet=1)
                                   │
                                   ▼
                           [gene_list_raw]
                                   │
                          column mapping
                                   │
                                   ▼
                           [gene_list] (standardized)
                           
[variant_list.xlsx] ──▶ openxlsx::read.xlsx(sheet=3)
                                   │
                                   ▼
                          [variant_list_raw]
                                   │
                          filter by omit column
                                   │
                          column mapping
                                   │
                                   ▼
                          [variant_list] (standardized)
```

### Output: `prepared_data`

```r
prepared_data = list(
  gene_list = data.frame(...),      # Standardized genes
  variant_list = data.frame(...),   # Standardized variants
  cutoff_list = data.frame(...),    # Terminal cutoffs by gene
  file_info = list(...)             # Path and existence info
)
```

## Stage 2: Filtering

### `filter_incomplete_entries()` in `rule_generator.R`

Removes rows missing essential fields:
- Gene
- Disease
- Inheritance
- Variants.To.Find

```
[prepared_data$gene_list]
         │
         ▼
  check essential fields
         │
         ├── complete rows ──▶ [cleaned_gene_list]
         │
         └── incomplete rows ──▶ [filtered_incomplete_entries.tsv]
                                  (saved for review)
```

### Output

```r
filtering_result = list(
  cleaned_data = data.frame(...),    # Clean gene list
  filtering_stats = list(
    total_entries = N,
    complete_entries = M,
    filtered_entries = N-M,
    filtering_details = data.frame(...)
  )
)
```

## Stage 3: Usage Tracking

### `track_effective_variant_usage()` in `effective_usage_tracker.R`

Tracks which genes/variants from input actually contribute to rules.

```
[gene_list] + [variant_list]
         │
         ▼
  analyze supplemental genes
  match to variant list
         │
         ▼
  [current_usage] = list(
    genes_using_supplemental = N,
    variants_used = M,
    unused_variants = K
  )
```

## Stage 4: Rule Generation

### `generate_rules()` in `rule_generator.R`

This is the core logic - the largest function in the system.

```
[gene_list] + [variant_list] + [cutoff_list] + [config]
         │
         ▼
  for each gene:
         │
         ├── determine strategy (Variants.To.Find)
         │
         ├── determine inheritance → cThresh (1 or 2)
         │
         ├── generate gene-specific rules:
         │     │
         │     ├── PTV rules (frameshift, stop_gained, etc.)
         │     │
         │     ├── ClinVar rules (Pathogenic, Likely_pathogenic)
         │     │
         │     ├── Missense rules (with position filters)
         │     │
         │     └── HGVSc rules (for supplemental)
         │
         └── add frequency conditions (QUAL, DP, GQ)
         
         │
         ▼
  combine all rules
  add exclusion zones (terminal cutoffs)
  assign cIDs (compound het identifiers)
         │
         ▼
  [all_rules] = data.frame(
    rule_condition,
    category,
    cID, cCond, cThresh,
    gene, disease
  )
```

### Rule Structure

Each rule has these fields:

| Field | Example | Purpose |
|-------|---------|---------|
| `rule_condition` | `SYMBOL == BRCA1 && Consequence =~ frameshift...` | The actual rule expression |
| `category` | `Pathogenic` | Classification category |
| `cID` | `1` | Compound het group ID |
| `cCond` | `>=` | Compound het condition |
| `cThresh` | `2` | Compound het threshold |
| `gene` | `BRCA1` | Gene symbol |
| `disease` | `Breast cancer` | Disease name |

### Compound Heterozygote Logic

For autosomal recessive (AR) inheritance:
- Multiple rules for same gene get same `cID`
- `cThresh = 2` means need 2 variants
- `cCond = ">="` means 2 or more

For dominant inheritance:
- `cThresh = 1` means 1 variant sufficient

## Stage 5: Output Generation

### Main Outputs

```
[all_rules]
    │
    ├──▶ [*_rules_file_from_carrier_list_nr_XX.tsv]
    │         Tab-separated rules file
    │
    ├──▶ [list_of_analyzed_genes.json]
    │         Gene list as JSON
    │
    ├──▶ [list_of_analyzed_genes_comms_names.json]
    │         Gene list with communications names
    │
    └──▶ [list_of_analyzed_genes_science_pipeline_names.json]
              Gene list with science names
```

### Rules File Format

```tsv
rule_condition\tcategory\tcID\tcCond\tcThresh
SYMBOL == BRCA1 && Consequence =~ frameshift...\tPathogenic\t1\t>=\t2
```

## Stage 6: Reporting

### `generate_summary_report_with_data()` in `generate_summary_report.R`

```
[prepared_data] + [previous_data] + [rule_results] + [comparison]
         │
         ▼
  Calculate statistics:
    - Input file stats
    - Rule counts by type
    - Changes from previous version
         │
         ▼
  [SUMMARY_REPORT.md]
```

## Complete Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           INPUT FILES                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  master_gene_list.xlsx       variant_list.xlsx       (optional)         │
│        │                           │                 variantcall.csv    │
└────────┼───────────────────────────┼─────────────────────┼──────────────┘
         │                           │                     │
         ▼                           ▼                     ▼
    ┌────────────────────────────────────────────────────────────────┐
    │                    load_excel_files()                           │
    │                                                                 │
    │   Apply column mappings, normalize data                        │
    └─────────────────────────┬──────────────────────────────────────┘
                              │
                              ▼
                      [prepared_data]
                       gene_list
                       variant_list
                       cutoff_list
                              │
                              ▼
    ┌────────────────────────────────────────────────────────────────┐
    │                filter_incomplete_entries()                      │
    │                                                                 │
    │   Remove rows missing essential fields                         │
    └─────────────────────────┬──────────────────────────────────────┘
                              │
                              ▼
                     [cleaned gene_list]
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
   track_usage()      compare_inputs()      predict_changes()
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
    ┌────────────────────────────────────────────────────────────────┐
    │                    generate_rules()                             │
    │                                                                 │
    │   For each gene:                                               │
    │     1. Determine strategy                                      │
    │     2. Generate rule conditions                                │
    │     3. Add frequency filters                                   │
    │     4. Assign compound het metadata                            │
    └─────────────────────────┬──────────────────────────────────────┘
                              │
                              ▼
                         [all_rules]
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
   write_tsv()          write_json()       generate_report()
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           OUTPUT FILES                                   │
├─────────────────────────────────────────────────────────────────────────┤
│  rules_file_*.tsv    list_of_analyzed_*.json    SUMMARY_REPORT.md       │
│                                                                          │
│  logs/*.log          version_metadata.json      trace_write_file.txt    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Transformation Points

### 1. Column Mapping (load_excel_files)
- Excel column names → Internal standardized names
- Location: `rule_generator.R`, lines 102-246

### 2. Strategy Determination
- `Variants.To.Find` value → Rule types to generate
- Location: `rule_generator.R`, `generate_gene_rules()`

### 3. Rule Construction
- Gene info + template → Rule condition string
- Location: `rule_generator.R`, `generate_gene_rules()`

### 4. Compound Het Assignment
- Inheritance pattern → cID, cCond, cThresh
- Location: `rule_generator.R`, `generate_rules()`

## See Also

- [Architecture](architecture.md) - Module structure
- [Configuration](configuration.md) - Config system

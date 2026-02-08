# Current Architecture (from optimize-rules-gen branch)

This is a copy of docs/rules_generation/current-architecture.md from the optimize-rules-gen branch. It documents the baseline to preserve during optimization.

## Usage Reference
For up-to-date run instructions and required inputs, use the README referenced by the main framework. Prefer the latest README.md alongside the framework wrapper.

## Current Rules Generation Architecture

### Purpose
Describe how rules are generated today, the dataflow, modules, inputs/outputs, and known caveats. This is the baseline we will preserve while optimizing and refactoring.

### Entry Points and Orchestration
- **Wrapper**: ./generate_rules.sh (project root) orchestrates runs, handles overwrite protection, colored output, and output directory layout.
- **Core workflow runner**: bin/rule_generation/lib/generate_rules_simplified.R parses CLI args, initializes logging and tracing, loads configuration and inputs once, then calls the modules in sequence.

### High-level Workflow
1. Input validation and configuration load
2. Input files read and normalized (Excel to standardized columns)
3. Optional variantCall database load
4. Predictive analysis (expected changes)
5. Rules generation (apply templates, special cases, exclusions)
6. Results analysis and comparison to previous version
7. Prediction validation
8. Outputs, logs, metadata, and deployment script generation

### Core Modules (source of truth in bin/rule_generation/lib/)

| Module | Purpose |
|--------|---------|
| generate_rules_simplified.R | CLI, setup, logging, tracing, version metadata, input copy, sequencing of steps |
| rule_generator.R | Input loading/mapping, filtering, core emission of rules, application of templates and special cases |
| config_reader.R | Settings parser, column mappings, templates, exclusions readers |
| predictor.R | Predictive analysis before generation |
| prediction_validator.R | Validates predicted vs actual changes |
| input_comparator.R | Analyzes differences in successive input sets |
| rules_analysis_comparator.R | Compares generated outputs across versions |
| effective_usage_tracker.R | Tracks which inputs/variants contribute to final rules |
| trace_file_writer.R | Traces all file writes with absolute paths |
| logger.R | Logging helpers with levels and sections |
| variant_changes_config_loader.R, variant_changes_processor.R | Helpers for variant-change oriented workflows |

### Configuration and Templates

| Type | Location | Purpose |
|------|----------|---------|
| Settings | config/settings.conf | Thresholds like FORMAT_GQ_THRESHOLD, output naming, retention |
| Column mappings | config/column_mappings.conf | Logical to actual Excel column names |
| Rule templates | config/rules/*.txt | Template fragments combined per gene |
| Special cases | config/special_cases/*.txt | Gene/position exclusions, benign ClinVar, validation variants |

### Inputs
- Master gene list (Excel)
- Variant supplemental list (Excel)
- Optional variantCall database (CSV/Excel)
- For stepwise replays, curated sets in generate_rules_input/version_XX/step_YY/ provide fully pinned inputs and configs

### Outputs (by version in out_rule_generation/version_XX/)

```
outputs/
  *_rules_file_from_carrier_list_nr_XX.tsv  (deployment artifact)
  list_of_analyzed_genes*.json

analysis/
  input_comparison/
  predictions/
  prediction_validation/

logs/
  (timestamped execution logs)

trace_write_file.txt       (absolute-path trace of file writes)
config/                    (snapshot of effective configuration)
deployment/               (helper scripts, e.g., S3 upload)
version_metadata.json     (metadata: counts, lineage, accuracy)
```

### Data Loading and Normalization
- Excel files read via openxlsx once; standardized columns created using centralized mappings
- Duplicate detection on key tuple (Disease, Gene, Variants.To.Find, Inheritance)
- Incomplete rows filtered with a saved report (filtered_incomplete_entries.tsv)

### Building Blocks Today
- Human-editable template lines combined into rule strings
- Special-case exclusions applied post-template expansion (gene-level, position-level)
- Configuration constants interpolated into rule fragments

### Known Caveats (captured from existing docs)

1. **Gene exclusions bug**: ENABLE_GENE_EXCLUSIONS is loaded but not enforced by logic in some flows; excluded genes can still appear in outputs

2. **Legacy cID assignment**: Framework uses Version 43-style cID assignment for later versions for better compound-het handling; this can differ from original v44 behavior

### Reproducibility Aids Already in Place
- Inputs copied into version directories
- Configuration snapshot saved per run
- Write-trace log ensures files land in the correct version-scoped paths

This document is the authoritative baseline to preserve output parity while we optimize inner loops and improve reporting.

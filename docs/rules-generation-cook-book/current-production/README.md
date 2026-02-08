# Current Production: bin/rule_generation/

This is the active, battle-tested rules generation system currently in use.

## Location
`bin/rule_generation/` on master branch

## Entry Point

The system is invoked via the bash wrapper at the project root:

```bash
./generate_rules.sh --master-gene-list /path/to/master_gene_list.xlsx \
                    --variant-list /path/to/variant_list.xlsx \
                    --rules-version 45
```

The wrapper handles:
- Prerequisites checking (R, packages)
- Overwrite protection for existing versions
- Directory structure creation
- Colored output
- S3 deployment (optional)

## Core Workflow (7 Steps)

The R script `lib/generate_rules_simplified.R` orchestrates:

1. **Configuration** - Load settings (no default fallback, input-specific only)
2. **Input Analysis** - Load Excel files, filter incomplete entries, track usage
3. **Prediction Analysis** - Predict expected changes (if comparing versions)
4. **Rules Generation** - Apply templates, handle special cases
5. **Prediction Validation** - Validate predictions against actual output
6. **Deployment Scripts** - Generate helper scripts
7. **Summary Report** - Comprehensive SUMMARY_REPORT.md

## Key Files

| File | Lines | Purpose |
|------|-------|---------|
| `lib/generate_rules_simplified.R` | 513 | Main orchestrator |
| `lib/rule_generator.R` | 1,189 | Core rule logic |
| `lib/generate_summary_report.R` | 2,048 | Report generation |
| `lib/rules_analysis_comparator.R` | 864 | Version comparison |
| `lib/generate_rules_utils.R` | 589 | Utilities |
| `lib/config_reader.R` | 378 | Configuration loading |
| `lib/predictor.R` | 336 | Predictive analysis |
| `lib/prediction_validator.R` | 364 | Validation |
| `lib/input_comparator.R` | 304 | Input diff analysis |
| `lib/logger.R` | 193 | Logging |
| `lib/effective_usage_tracker.R` | 158 | Usage tracking |
| `lib/trace_file_writer.R` | 188 | File tracing |
| `lib/variant_changes_*.R` | 342 | Variant processing |

**Total**: ~7,500 lines of R code

## Output Structure

```
out_rule_generation/version_XX/
├── outputs/
│   ├── *_rules_file_from_carrier_list_nr_XX.tsv  # Main rules file
│   ├── list_of_analyzed_genes.json
│   ├── list_of_analyzed_genes_comms_names.json
│   └── list_of_analyzed_genes_science_pipeline_names.json
├── analysis/
│   ├── input_comparison/
│   ├── predictions/
│   └── prediction_validation/
├── logs/
│   └── generation_YYYYMMDD_HHMMSS.log
├── inputs/                    # Archived input files
├── config/                    # Configuration snapshot
├── deployment/                # Helper scripts
├── trace_write_file.txt       # Absolute path trace
├── version_metadata.json      # Run metadata
└── SUMMARY_REPORT.md          # Main output for review
```

## Stepwise Versioning

Supports incremental changes via alphanumeric versions:

```
out_rule_generation/
└── version_45/
    ├── step_45A/             # First step
    ├── step_45B/             # Builds on 45A
    ├── step_45C/             # Builds on 45B
    └── (base version files)  # Final combined version
```

## Key Features

### Effective Usage Tracking
Tracks which genes/variants from input files actually contribute to generated rules.

### Version Comparison
Compares current generation with previous version:
- Rule count changes
- New/removed rules
- Gene/disease changes

### Prediction/Validation
Before generating rules, predicts what changes to expect. After generation, validates predictions against actual results.

### Comprehensive Reporting
SUMMARY_REPORT.md includes:
- Input file statistics
- Rule generation summary
- Version comparison
- Prediction accuracy
- File verification

## Known Issues

1. **Gene exclusions bug**: `ENABLE_GENE_EXCLUSIONS` is loaded but not fully enforced
2. **Legacy cID assignment**: Uses V43-style for compound-het handling
3. **Large file sizes**: rule_generator.R (1,189 lines) does too much
4. **Row-by-row loops**: Some operations could be vectorized

## See Also

- [Architecture](architecture.md) - Module structure and dependencies
- [Configuration](configuration.md) - Config system details  
- [Data Flow](data-flow.md) - How data moves through the system

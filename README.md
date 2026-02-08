# Rules Generator

Generates classification rules for the rare variant classifier from gene and variant lists.

## Quick Start

```bash
./generate_rules.sh \
    --master-gene-list /path/to/master_gene_list.xlsx \
    --variant-list /path/to/variant_list.xlsx \
    --rules-version 45
```

## Requirements

- R with packages: `openxlsx`, `jsonlite`, `knitr`
- Bash

## Inputs

- **Master Gene List** (Excel) - genes, diseases, inheritance patterns, variants to find
- **Variant List** (Excel) - specific variants for supplemental strategy genes

## Outputs

Generated in `out_rule_generation/version_XX/`:

- `outputs/*_rules_file_*.tsv` - Main rules file
- `outputs/list_of_analyzed_genes*.json` - Gene lists
- `SUMMARY_REPORT.md` - Comprehensive report
- `logs/` - Execution logs

## Usage

```bash
# Check prerequisites
./generate_rules.sh --check

# Basic generation
./generate_rules.sh \
    --master-gene-list data/master_gene_list.xlsx \
    --variant-list data/variant_list.xlsx \
    --rules-version 45

# With version comparison
./generate_rules.sh \
    --master-gene-list data/master_gene_list.xlsx \
    --variant-list data/variant_list.xlsx \
    --rules-version 46 \
    --compare-with-version 45

# Overwrite existing version
./generate_rules.sh \
    --master-gene-list data/master_gene_list.xlsx \
    --variant-list data/variant_list.xlsx \
    --rules-version 45 \
    --overwrite
```

## Directory Structure

```
rules_generator/
├── generate_rules.sh       # Entry point
├── bin/R/                  # Core R modules
├── config/                 # Configuration (optional)
├── tests/data/             # Sample test data
└── docs/                   # Documentation
```

## Testing

```bash
# Test with sample data
./generate_rules.sh \
    --master-gene-list tests/data/sample_master_gene_list.xlsx \
    --variant-list tests/data/sample_variant_list.xlsx \
    --rules-version test1
```

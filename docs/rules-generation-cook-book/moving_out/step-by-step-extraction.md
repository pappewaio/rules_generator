# Step-by-Step Extraction to rules_generator Repo

This document lists exactly what to move from `Nucleus-rare_variant_classifier` to the new `rules_generator` repo.

## Prerequisites

1. Archive or delete the old `/home/ubuntu/jesper/rules_generator/` folder
2. Create fresh `rules_generator` repo

```bash
# Archive the old attempt (optional, for reference)
mv /home/ubuntu/jesper/rules_generator /home/ubuntu/jesper/rules_generator_old_attempt

# Create fresh repo
mkdir -p /home/ubuntu/jesper/rules_generator
cd /home/ubuntu/jesper/rules_generator
git init
```

## What to Move

### 1. Core R Code
**Source**: `bin/rule_generation/lib/`  
**Destination**: `bin/R/` or `lib/`

| File | Purpose | Priority |
|------|---------|----------|
| `generate_rules_simplified.R` | Main orchestrator | Required |
| `rule_generator.R` | Core rule logic | Required |
| `generate_rules_utils.R` | Utilities | Required |
| `config_reader.R` | Configuration | Required |
| `logger.R` | Logging | Required |
| `trace_file_writer.R` | File tracing | Required |
| `generate_summary_report.R` | Reporting | Required |
| `rules_analysis_comparator.R` | Version comparison | Required |
| `effective_usage_tracker.R` | Usage tracking | Optional |
| `input_comparator.R` | Input diff | Optional |
| `predictor.R` | Predictions | Optional |
| `prediction_validator.R` | Validation | Optional |
| `variant_changes_*.R` | Variant processing | Optional |

### 2. Entry Point Script
**Source**: `generate_rules.sh` (project root)  
**Destination**: `generate_rules.sh` (new repo root)

This needs adaptation to:
- Remove RVC-specific paths
- Update FRAMEWORK_DIR references
- Simplify if possible

### 3. Configuration (if externalizing)
**Source**: Currently hardcoded in `config_reader.R`  
**Destination**: `config/` folder

Consider creating:
- `config/settings.conf` - Thresholds, flags
- `config/column_mappings.conf` - Excel column mappings

### 4. Tests
**Source**: `bin/rule_generation/tests/`  
**Destination**: `tests/`

| Item | Purpose |
|------|---------|
| `sample_data/` | Test Excel files |
| Any test scripts | Unit/integration tests |

### 5. Documentation
**Source**: This cookbook!  
**Destination**: `docs/`

Move the relevant parts:
- `current-production/` docs become the main docs
- `optimize-branch/stepwise-improvements.md` becomes the roadmap

## What NOT to Move

These stay in `Nucleus-rare_variant_classifier`:

| Item | Reason |
|------|--------|
| `bin/rust_code/` | RVC-specific classifier code |
| `rare_variant_classifier.sh` | RVC entry point |
| `assets/` | RVC truthsets and assets |
| `tests/e2e/` | RVC end-to-end tests |
| `tests/unit/` | RVC unit tests |
| `.github/workflows/` | RVC CI/CD |
| `Dockerfile` | RVC container |
| `deprecated/` | Keep with RVC history |

## Extraction Steps

### Step 1: Create New Repo Structure

```bash
cd /home/ubuntu/jesper/rules_generator

mkdir -p bin/R
mkdir -p config
mkdir -p tests/data
mkdir -p docs
```

### Step 2: Copy Core Files

```bash
# Copy R code
cp /home/ubuntu/jesper/Nucleus-rare_variant_classifier/bin/rule_generation/lib/*.R bin/R/

# Copy entry point
cp /home/ubuntu/jesper/Nucleus-rare_variant_classifier/generate_rules.sh .

# Copy test data
cp -r /home/ubuntu/jesper/Nucleus-rare_variant_classifier/bin/rule_generation/tests/sample_data tests/data/
```

### Step 3: Adapt Entry Point

Edit `generate_rules.sh` to:
1. Update `FRAMEWORK_DIR` to new location
2. Update `R_SCRIPT` path
3. Remove RVC-specific features if any

### Step 4: Create Wrapper in RVC

After extraction, create a thin wrapper in RVC that calls the external repo:

```bash
# In Nucleus-rare_variant_classifier/generate_rules.sh
#!/bin/bash
# Wrapper that calls the external rules_generator

RULES_GENERATOR_DIR="${RULES_GENERATOR_DIR:-../rules_generator}"

if [[ ! -d "$RULES_GENERATOR_DIR" ]]; then
    echo "Error: rules_generator not found at $RULES_GENERATOR_DIR"
    echo "Set RULES_GENERATOR_DIR environment variable or clone the repo"
    exit 1
fi

"$RULES_GENERATOR_DIR/generate_rules.sh" "$@"
```

### Step 5: Update References

In the new repo, search and replace:
- `bin/rule_generation/lib/` → `bin/R/`
- Any hardcoded RVC paths

### Step 6: Test

```bash
cd /home/ubuntu/jesper/rules_generator

# Basic check
./generate_rules.sh --help

# Full test with sample data
./generate_rules.sh \
    --master-gene-list tests/data/sample_master_gene_list.xlsx \
    --variant-list tests/data/sample_variant_list.xlsx \
    --rules-version test1
```

### Step 7: Parity Check

Run generation with both old (in RVC) and new (standalone) and compare outputs:

```bash
# Generate with RVC version
cd /home/ubuntu/jesper/Nucleus-rare_variant_classifier
./generate_rules.sh --master-gene-list ... --rules-version baseline

# Generate with new standalone
cd /home/ubuntu/jesper/rules_generator
./generate_rules.sh --master-gene-list ... --rules-version test

# Compare essential outputs
diff out_rule_generation/version_baseline/outputs/*.tsv \
     out_rule_generation/version_test/outputs/*.tsv
```

## Post-Extraction Cleanup

### In RVC Repo

1. Replace `bin/rule_generation/` with minimal README pointing to new repo
2. Keep `generate_rules.sh` wrapper
3. Update any CI/CD that referenced the internal code

### In rules_generator Repo

1. Create proper README.md
2. Set up .gitignore
3. Add LICENSE if needed
4. Set up CI/CD for parity testing

## Timeline Suggestion

| Phase | Action |
|-------|--------|
| 1 | Copy files to new repo, test locally |
| 2 | Run parity checks, fix any issues |
| 3 | Create wrapper in RVC |
| 4 | Use new repo for next rule generation |
| 5 | Remove old code from RVC after confidence period |

## Files Checklist

```
rules_generator/
├── generate_rules.sh           # Entry point
├── README.md                   # Documentation
├── .gitignore                  # Ignore patterns
├── bin/
│   └── R/
│       ├── generate_rules_simplified.R
│       ├── rule_generator.R
│       ├── generate_rules_utils.R
│       ├── config_reader.R
│       ├── logger.R
│       ├── trace_file_writer.R
│       ├── generate_summary_report.R
│       ├── rules_analysis_comparator.R
│       ├── effective_usage_tracker.R
│       ├── input_comparator.R
│       ├── predictor.R
│       ├── prediction_validator.R
│       └── variant_changes_*.R
├── config/
│   └── (optional external config files)
├── tests/
│   └── data/
│       ├── sample_master_gene_list.xlsx
│       └── sample_variant_list.xlsx
└── docs/
    └── (documentation)
```

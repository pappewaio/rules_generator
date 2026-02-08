# Configuration System (from rules_generator repo)

The standalone rules_generator repo uses a modular configuration approach with separate .conf files.

## Structure

```
config/
  main.conf                 # Main loader, sources other configs
  settings.conf             # Runtime settings
  column_mappings.conf      # Column name mappings
  paths.conf                # Path configuration
  colors.conf               # Terminal color codes
  rules_assets/
    rules.conf              # Rule templates
    strategy_mapping.conf   # Strategy to rule type mapping
    special_cases/
      clinvar_benign_exclusions.txt
      gene_exclusions.txt
      position_exclusions.txt
      special_disease_rules.txt
      validation_rules.txt
```

## main.conf

The central configuration loader that coordinates all other files:

```bash
# Get framework root directory
FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source paths first
source "$FRAMEWORK_DIR/config/paths.conf"

# Load utilities
source "$COMMON_UTILS"

# Load all configs and functions
load_all_configs
load_all_functions
```

## settings.conf

Runtime parameters:

```conf
FORMAT_GQ_THRESHOLD=19
RULES_INDEX=44
OUTPUT_PREFIX=rules_file_from_carrier_list
CREATE_JSON_OUTPUTS=true
CREATE_ANALYSIS=true
ENABLE_GENE_EXCLUSIONS=false
ENABLE_LEGACY_CID_ASSIGNMENT=true
```

## column_mappings.conf

Maps logical names to actual Excel column names:

```conf
# Master Gene List
GENE_NAME=Gene.→.Gene.Name
DISEASE_NAME=Name
VARIANTS_TO_FIND=Report.Gene.→.Variants.To.Find
INHERITANCE=Report.Gene.→.Inheritance
TERMINAL_CUTOFF_MISSENSE=Gene.→.Terminal.Cutoff.Missense

# Variant List
VARIANT_GENE=gene_name
VARIANT_NUCLEOTIDE=HGVS_nucleotide
VARIANT_DISEASE=Disease
```

## Benefits of This Approach

1. **Separation of Concerns**: Each config file has a clear purpose
2. **Easy to Override**: Can pass different config directory
3. **Version Control Friendly**: Small focused files are easier to review
4. **Self-Documenting**: File names explain their content

## Comparison with Production

| Aspect | Production | Standalone |
|--------|------------|------------|
| Column mappings | Hardcoded in config_reader.R | External column_mappings.conf |
| Settings | Mixed, some hardcoded | External settings.conf |
| Rule templates | Deprecated, mostly hardcoded | External rules_assets/ |
| Special cases | Deprecated | External special_cases/ |
| Configuration loading | In R code | Bash main.conf loader |

## Key Differences

1. **Bash-based loading**: main.conf is a bash script that loads other configs
2. **Path utilities**: Dedicated path_utils.sh for path handling
3. **R reads bash configs**: R scripts read the pre-loaded configuration
4. **Clear separation**: Bash handles orchestration, R handles logic

## Lesson for Production

Consider externalizing configuration that changes between runs or deployments:
- Column mappings (rarely change, but external = visible)
- Settings like thresholds (may need adjustment)
- Rule templates (if they need to be human-editable)

Keep hardcoded what is truly constant and should not change.

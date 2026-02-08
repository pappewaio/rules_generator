# Configuration System (Current Production)

## Overview

The configuration system has evolved and is currently in a transitional state:
- **Old approach**: External `.conf` files in `config/` directory
- **Current approach**: Most configuration is hardcoded in `config_reader.R`
- **Deprecated**: `config/` directory exists but is marked deprecated

## Column Mappings

Column mappings translate between logical names (used in code) and actual Excel column names.

### Current Mappings (Hardcoded in `config_reader.R`)

```r
# Master Gene List Mappings
GENE_NAME            = "Gene.→.Gene.Name"
SCIENCE_NAME         = "Science.Name"
DISEASE_NAME         = "Name"
CARRIER_STATUS       = "Is.Carrier"
COMPLEX_STATUS       = "Is.V1.Complex"
VARIANTS_TO_FIND     = "Report.Gene.→.Variants.To.Find"
COMMS_NAME           = "Comms.Name"
INHERITANCE          = "Report.Gene.→.Inheritance"
TERMINAL_CUTOFF_MISSENSE   = "Gene.→.Terminal.Cutoff.Missense"
TERMINAL_CUTOFF_FRAMESHIFT = "Gene.→.Terminal.Cutoff.Frameshift"
CHROMOSOME           = "Gene.→.Chromosome"

# Variant List Mappings
VARIANT_OMIT         = "omit"
VARIANT_GENE         = "gene_name"
VARIANT_NUCLEOTIDE   = "HGVS_nucleotide"
VARIANT_DISEASE      = "Disease"
VARIANT_POSITION     = "Position"
VARIANT_REF          = "Ref"
VARIANT_ALT          = "Alt"
VARIANT_CONSEQUENCE  = "Consequence"
```

### Standardized Internal Column Names

After loading, data is normalized to these internal column names:

**Gene List**:
- `Disease` - Disease name
- `Gene` - Gene symbol
- `Carrier` - Is carrier status
- `Complex` - Is complex status
- `Variants.To.Find` - Strategy type
- `Report.Comms.Name` - Communications name
- `Inheritance` - Inheritance pattern
- `Terminal.Cutoff.Missense` - Missense cutoff position
- `Terminal.Cutoff.Frameshift` - Frameshift cutoff position
- `Chromosome` - Chromosome

**Variant List**:
- `Gene` - Gene symbol
- `Variant` - HGVSc notation
- `Disease` - Disease name
- `Position` - Genomic position
- `Ref` - Reference allele
- `Alt` - Alternate allele
- `Consequence` - Variant consequence

## Settings

### Key Settings (Hardcoded or via config)

| Setting | Default | Purpose |
|---------|---------|---------|
| `FORMAT_GQ_THRESHOLD` | 19 | Minimum genotype quality |
| `ENABLE_GENE_EXCLUSIONS` | false | Enable gene exclusion filtering |
| `ENABLE_LEGACY_CID_ASSIGNMENT` | true | Use V43-style compound IDs |

### Frequency Rule Template

The frequency rule template is applied to all non-frequency rules:

```
&& QUAL >= 22.4 && format_DP >= 8 && format_GQ >= {FORMAT_GQ_THRESHOLD}
```

Where `{FORMAT_GQ_THRESHOLD}` is replaced with the configured value.

## Rule Templates (Deprecated)

Previously stored in `config/rules/*.txt`, now mostly hardcoded in `rule_generator.R`.

### Strategy Mapping

Maps `Variants.To.Find` values to rule types:

| Strategy | Rule Types Generated |
|----------|---------------------|
| PTV only | PTV, ClinVar P/LP |
| ClinVar P and LP | ClinVar P, ClinVar LP |
| Missense and nonsense | Missense, Nonsense, ClinVar P/LP |
| See supplemental variant list | HGVSc-specific rules |

## Special Cases (Deprecated)

Previously stored in `config/special_cases/`:

- `gene_exclusions.txt` - Genes to exclude
- `position_exclusions.txt` - Position-based exclusions
- `clinvar_benign_exclusions.txt` - ClinVar benign genes
- `special_disease_rules.txt` - Disease-specific rules
- `validation_rules.txt` - Validation rules

**Note**: These are largely deprecated. Special case handling is now embedded in `rule_generator.R`.

## Configuration Loading

### Function: `load_simple_config()`

Located in `generate_rules_utils.R`:

```r
load_simple_config <- function(config_path, version_dir) {
  # Returns list with:
  #   - settings: key-value pairs
  #   - columns: column mappings
  #   - rules: rule templates (deprecated)
  #   - special_cases: exclusions (deprecated)
  #   - config_source: where config came from
}
```

### No Default Fallback

The current system does **not** fall back to default configuration. Configuration is expected to be:
1. Passed explicitly via arguments
2. Or use hardcoded values in code

This was a deliberate change to make configuration more explicit and avoid hidden defaults.

## Version-Specific Configuration

Each generated version can have its own configuration snapshot:

```
out_rule_generation/version_XX/
└── config/
    └── (configuration snapshot for reproducibility)
```

## Future Direction

The gradual optimization effort should:

1. **Document all hardcoded values** - Make them explicit
2. **Consider re-externalizing** - For values that change between runs
3. **Keep column mappings central** - These rarely change
4. **Remove deprecated config files** - Clean up unused files

## See Also

- [Architecture](architecture.md) - Where config is loaded
- [Data Flow](data-flow.md) - How config affects processing

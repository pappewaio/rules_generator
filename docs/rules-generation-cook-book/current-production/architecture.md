# Current Production Architecture

## Module Dependency Graph

```
generate_rules.sh (bash wrapper)
    │
    └─▶ generate_rules_simplified.R (orchestrator)
            │
            ├─▶ generate_rules_utils.R (utilities)
            │       └─▶ validate_input_files()
            │       └─▶ create_version_directories()
            │       └─▶ create_version_metadata()
            │       └─▶ copy_input_files()
            │       └─▶ load_simple_config()
            │       └─▶ generate_deployment_script()
            │       └─▶ finalize_timing()
            │
            ├─▶ logger.R (logging)
            │       └─▶ init_logger()
            │       └─▶ log_info/warning/error/section()
            │       └─▶ close_logger()
            │
            ├─▶ trace_file_writer.R (file tracing)
            │       └─▶ init_write_trace()
            │       └─▶ trace_write()
            │       └─▶ close_write_trace()
            │
            ├─▶ config_reader.R (configuration)
            │       └─▶ load_simple_config()
            │       └─▶ Column mappings (hardcoded)
            │
            ├─▶ rule_generator.R (core rule logic)
            │       └─▶ load_excel_files()
            │       └─▶ filter_incomplete_entries()
            │       └─▶ generate_rules()
            │       └─▶ generate_gene_rules()
            │       └─▶ exclusion_rule_function()
            │
            ├─▶ effective_usage_tracker.R
            │       └─▶ track_effective_variant_usage()
            │       └─▶ load_previous_effective_usage()
            │       └─▶ compare_effective_usage()
            │       └─▶ save_effective_usage()
            │
            ├─▶ input_comparator.R
            │       └─▶ compare_inputs()
            │
            ├─▶ predictor.R
            │       └─▶ predict_changes()
            │
            ├─▶ prediction_validator.R
            │       └─▶ validate_predictions()
            │
            ├─▶ rules_analysis_comparator.R
            │       └─▶ (version comparison logic)
            │
            └─▶ generate_summary_report.R
                    └─▶ generate_summary_report_with_data()
```

## Module Responsibilities

### Orchestrator: `generate_rules_simplified.R`
- Parse CLI arguments
- Initialize logging and tracing
- Coordinate the 7-step workflow
- Handle errors and cleanup

### Utilities: `generate_rules_utils.R`
- Input file validation
- Directory creation
- Version metadata management
- Input file archiving
- Configuration loading
- Deployment script generation
- Timing utilities

### Core Rule Logic: `rule_generator.R`
**This is the largest module (1,189 lines) and primary optimization target.**

Functions:
- `load_excel_files()` - Load and normalize Excel inputs
- `filter_incomplete_entries()` - Remove incomplete gene entries
- `generate_rules()` - Main rule generation entry point
- `generate_gene_rules()` - Per-gene rule generation
- `exclusion_rule_function()` - Terminal cutoff handling

### Configuration: `config_reader.R`
- Load settings from config files
- Hardcoded column mappings (moved from config files)
- Settings parsing

### Tracking: `effective_usage_tracker.R`
- Track which inputs contribute to rules
- Compare usage between versions
- Save usage data as JSON

### Comparison: `input_comparator.R`
- Compare current vs previous inputs
- Identify added/removed/changed entries

### Prediction: `predictor.R` + `prediction_validator.R`
- Predict expected rule changes before generation
- Validate predictions after generation

### Reporting: `generate_summary_report.R`
**Second largest module (2,048 lines).**

Generates comprehensive SUMMARY_REPORT.md with:
- Input statistics
- Rule generation summary
- Version comparison
- Prediction accuracy
- File verification

## Data Flow Between Modules

```
[Excel Files] ─────────────────────────────────────────────────────────────▶
                                                                            │
                ┌───────────────────────────────────────────────────────────┘
                │
                ▼
        load_excel_files() ─▶ prepared_data {
                                gene_list: data.frame
                                variant_list: data.frame
                                cutoff_list: data.frame
                                variantcall_database: data.frame (optional)
                              }
                │
                ▼
        filter_incomplete_entries() ─▶ cleaned prepared_data
                │
                ▼
        track_effective_variant_usage() ─▶ current_usage
                │
                ▼ (if comparing)
        compare_inputs() ─▶ comparison_results
                │
                ▼
        predict_changes() ─▶ prediction_results
                │
                ▼
        generate_rules() ─▶ rule_results {
                             output_file: path
                             total_rules: count
                           }
                │
                ▼
        validate_predictions() ─▶ validation_results
                │
                ▼
        generate_summary_report_with_data() ─▶ SUMMARY_REPORT.md
```

## Global State and Shared Data

### Logger
Passed to most functions for consistent logging.

### Prepared Data
Loaded once and passed to modules that need it:
- `gene_list` - normalized gene data
- `variant_list` - normalized variant data
- `cutoff_list` - terminal cutoffs
- `variantcall_database` - optional external database

### Configuration
Loaded once, contains:
- `settings` - thresholds and flags
- `columns` - column mappings
- `rules` - rule templates (deprecated, now hardcoded)
- `special_cases` - exclusions (deprecated)

## Entry Point Details

### Bash Wrapper (`generate_rules.sh`)

```bash
# Key responsibilities:
1. Parse CLI arguments
2. Check prerequisites (R, packages)
3. Handle version directory structure
4. Overwrite protection with user prompt
5. Convert relative paths to absolute
6. Invoke Rscript with arguments
7. Handle S3 deployment (optional)
```

### R Orchestrator (`generate_rules_simplified.R`)

```r
main <- function() {
  # Parse arguments
  config <- parse_arguments(args)
  
  # Validate inputs
  validate_input_files(...)
  
  # Create directories
  version_dir <- create_version_directories(...)
  
  # Initialize logging
  logger <- init_logger(log_file, "INFO")
  trace_file_path <- init_write_trace(version_dir, logger)
  
  # Create metadata
  create_version_metadata(version_dir, config, logger)
  copy_input_files(...)
  
  # Load config and data ONCE
  system_config <- load_simple_config(...)
  prepared_data <- load_excel_files(...)
  
  # Filter incomplete entries
  filtering_result <- filter_incomplete_entries(...)
  prepared_data$gene_list <- filtering_result$cleaned_data
  
  # Track usage
  current_usage <- track_effective_variant_usage(...)
  
  # Compare with previous (if specified)
  if (!is.null(config$compare_with)) {
    # Load previous data
    # Compare inputs
    # Compare usage
  }
  
  # Predict changes
  if (!is.null(comparison_results)) {
    prediction_results <- predict_changes(...)
  }
  
  # Generate rules (the core purpose)
  rule_results <- generate_rules(...)
  
  # Validate predictions
  if (!is.null(prediction_results)) {
    validation_results <- validate_predictions(...)
  }
  
  # Generate deployment script
  deployment_script <- generate_deployment_script(...)
  
  # Generate summary report
  generate_summary_report_with_data(...)
  
  # Cleanup
  finalize_timing(logger, version_dir)
  close_write_trace()
  close_logger(logger)
}
```

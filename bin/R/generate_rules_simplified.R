#!/usr/bin/env Rscript

# Simplified Rules Generation Framework
# Focuses on the core workflow: analyze inputs -> predict changes -> generate rules -> validate predictions

# Load utilities and core libraries
script_dir <- tryCatch({
  if (interactive()) {
    "bin/R"
  } else {
    args <- commandArgs(trailingOnly = FALSE)
    script_path <- sub("--file=", "", args[grep("--file=", args)])
    if (length(script_path) == 0) {
      "bin/R"
    } else {
      dirname(script_path)
    }
  }
}, error = function(e) "bin/R")

source(file.path(script_dir, "generate_rules_utils.R"))
source(file.path(script_dir, "logger.R"))
source(file.path(script_dir, "trace_file_writer.R"))

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

#' Parse command line arguments (simplified)
parse_arguments <- function(args) {
  config <- list(
    master_gene_list = NULL,
    variant_list = NULL,
    variantcall_database = NULL,
    output_dir = "out_rule_generation",
    rules_version = NULL,
    version_comment = NULL,
    compare_with = NULL,
    skip_checker = FALSE,
    help = FALSE
  )
  
  i <- 1
  while (i <= length(args)) {
    arg <- args[i]
    
    if (arg == "--help" || arg == "-h") {
      config$help <- TRUE
    } else if (arg == "--master-gene-list") {
      i <- i + 1; if (i <= length(args)) config$master_gene_list <- args[i]
    } else if (arg == "--variant-list") {
      i <- i + 1; if (i <= length(args)) config$variant_list <- args[i]
    } else if (arg == "--variantcall-database") {
      i <- i + 1; if (i <= length(args)) config$variantcall_database <- args[i]
    } else if (arg == "--output-dir") {
      i <- i + 1; if (i <= length(args)) config$output_dir <- args[i]
    } else if (arg == "--rules-version") {
      i <- i + 1; if (i <= length(args)) config$rules_version <- args[i]  # Keep as string for alphanumeric support
    } else if (arg == "--version-comment") {
      i <- i + 1; if (i <= length(args)) config$version_comment <- args[i]
    } else if (arg == "--compare-with") {
      i <- i + 1; if (i <= length(args)) config$compare_with <- args[i]
    } else if (arg == "--skip-checker") {
      config$skip_checker <- TRUE
    }
    
    i <- i + 1
  }
  
  return(config)
}

#' Print simplified usage
print_usage <- function() {
  cat("Simplified Rules Generation Framework\n")
  cat("Usage: Rscript generate_rules_simplified.R [options]\n\n")
  cat("Required:\n")
  cat("  --master-gene-list FILE     Path to master gene list Excel file\n")
  cat("  --variant-list FILE         Path to variant list Excel file\n")
  cat("  --rules-version VER         Version identifier (e.g., 45, 45A, 45B)\n\n")
  cat("Optional:\n")
  cat("  --variantcall-database FILE Path to variantCall database Excel/CSV file\n")
  cat("  --version-comment TEXT      Comment describing this version's changes\n")
  cat("  --compare-with VERSION      Previous version to compare with\n")
  cat("  --output-dir DIR            Output directory (default: out_rule_generation)\n")
  cat("  --help, -h                  Show this help\n\n")
  cat("Note: Use generate_rules.sh wrapper for overwrite handling and colored output\n\n")
}

#' Main simplified workflow
main <- function() {
  config <- parse_arguments(args)
  
  if (config$help) {
    print_usage()
    return(0)
  }
  
  # Validate inputs (variantCall database is optional for step 46A)
  if (is.null(config$rules_version) || is.null(config$master_gene_list) || is.null(config$variant_list)) {
    cat("Error: --rules-version, --master-gene-list, and --variant-list are required\n")
    print_usage()
    return(1)
  }
  
  validate_input_files(config$master_gene_list, config$variant_list, config$variantcall_database)
  
  # Setup version directory path
  version_dir <- file.path(config$output_dir, paste0("version_", config$rules_version))
  
  # Create version directories (bash script handles overwrite logic)
  version_dir <- create_version_directories(config$output_dir, config$rules_version)
  
  # Initialize logging
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  log_file <- file.path(version_dir, "logs", paste0("generation_", timestamp, ".log"))
  logger <- init_logger(log_file, "INFO")
  
  # Initialize file write tracing
  trace_file_path <- init_write_trace(version_dir, logger)
  
  log_section(logger, "SIMPLIFIED RULES GENERATION STARTUP")
  log_info(logger, paste("Version:", config$rules_version))
  log_info(logger, paste("Master gene list:", config$master_gene_list))
  log_info(logger, paste("Variant list:", config$variant_list))
  if (!is.null(config$variantcall_database)) {
    log_info(logger, paste("VariantCall database:", config$variantcall_database))
  } else {
    log_info(logger, "VariantCall database: Not provided")
  }
  if (!is.null(config$version_comment)) {
    log_info(logger, paste("Version comment:", config$version_comment))
  }
  
  # Create version metadata file
  log_section(logger, "VERSION METADATA")
  create_version_metadata(version_dir, config, logger)
  
  # Copy input files to version directory for future comparison
  log_section(logger, "ARCHIVING INPUT FILES")
  copy_input_files(version_dir, config$master_gene_list, config$variant_list, config$variantcall_database, logger)
  
  tryCatch({
    
    # Step 1: Load input-specific configuration (no fallback to default)
    log_section(logger, "LOADING CONFIGURATION")
    system_config <- load_simple_config(NULL, version_dir)  # No default config path
    log_info(logger, paste("Configuration loaded from:", system_config$config_source))
    
    # Step 2: Load Input Data Once (centralized data loading)
    log_section(logger, "LOADING INPUT DATA")
    source(file.path(script_dir, "rule_generator.R"))  # For load_excel_files
    
    # Load and prepare data once - this will be reused by all modules
    prepared_data <- load_excel_files(
      config$master_gene_list, 
      config$variant_list, 
      system_config$columns,  # Parameter name matches function signature
      logger
    )
    
    # Load variantCall database if provided (supports both CSV and Excel)
    if (!is.null(config$variantcall_database)) {
      log_info(logger, "Loading variantCall database...")
      tryCatch({
        # Determine file type and load accordingly
        if (grepl("\\.csv$", config$variantcall_database, ignore.case = TRUE)) {
          # Load CSV file
          variantcall_data <- read.csv(config$variantcall_database, stringsAsFactors = FALSE)
          log_info(logger, "Loaded variantCall database as CSV file")
        } else if (grepl("\\.(xlsx|xls)$", config$variantcall_database, ignore.case = TRUE)) {
          # Load Excel file
          variantcall_data <- openxlsx::read.xlsx(
            config$variantcall_database, 
            sheet = 1, 
            colNames = TRUE, 
            startRow = 1
          )
          log_info(logger, "Loaded variantCall database as Excel file")
        } else {
          stop("Unsupported file format. Please provide CSV or Excel file.")
        }
        
        prepared_data$variantcall_database <- variantcall_data
        log_info(logger, paste("✅ VariantCall database loaded:", nrow(variantcall_data), "rows"))
        log_info(logger, paste("Columns:", paste(names(variantcall_data), collapse = ", ")))
        
        # Show sample of approval statuses (R converts spaces to dots in column names)
        if ("Approval.Status" %in% names(variantcall_data)) {
          status_counts <- table(variantcall_data$Approval.Status)
          log_info(logger, paste("Approval status distribution:", paste(names(status_counts), "=", status_counts, collapse = ", ")))
        }
        
      }, error = function(e) {
        log_error(logger, paste("Failed to load variantCall database:", e$message))
        prepared_data$variantcall_database <- NULL
      })
    } else {
      prepared_data$variantcall_database <- NULL
    }
    
    log_info(logger, "✅ Input data loaded and prepared for reuse across all modules")
    
    # Step 2.5: Filter incomplete entries (early filtering for robustness)
    log_info(logger, "Filtering incomplete entries with missing essential information...")
    source(file.path(script_dir, "rule_generator.R"))  # For filter_incomplete_entries
    
    # Keep unfiltered gene list for summary report input comparison
    # (so Previous and Current both show raw input counts, apples-to-apples)
    prepared_data$gene_list_unfiltered <- prepared_data$gene_list
    
    filtering_result <- filter_incomplete_entries(
      gene_list = prepared_data$gene_list,
      output_dir = version_dir,
      logger = logger
    )
    
    # Update prepared_data with filtered gene list
    prepared_data$gene_list <- filtering_result$cleaned_data
    prepared_data$filtering_stats <- filtering_result$filtering_stats
    
    log_info(logger, paste("✅ Filtering completed:", 
                          filtering_result$filtering_stats$complete_entries, "entries retained,", 
                          filtering_result$filtering_stats$filtered_entries, "entries excluded"))
    
    # Step 3: Input Analysis (effective usage + input comparison for predictions)
    log_section(logger, "INPUT ANALYSIS")
    source(file.path(script_dir, "effective_usage_tracker.R"))
    
    # Track current usage using prepared data
    current_usage <- track_effective_variant_usage(
      gene_list = prepared_data$gene_list,
      variant_list_data = prepared_data$variant_list,
      logger = logger
    )
    
    # Compare with previous version if specified
    previous_usage <- NULL
    usage_comparison <- NULL
    comparison_results <- NULL
    
    if (!is.null(config$compare_with)) {
      # Load previous version data using the same centralized approach
      log_info(logger, paste("Loading previous version data for comparison with:", config$compare_with))
      previous_prepared_data <- NULL
      
      # Find previous version input files using robust path resolution
      current_dir_name <- basename(version_dir)
      if (grepl("^step_", current_dir_name)) {
        # Current is step-wise, output root is two levels up
        output_root <- dirname(dirname(version_dir))
      } else {
        # Current is standard version, output root is one level up
        output_root <- dirname(version_dir)
      }
      
      # Build previous version path using the same robust logic as rules_analysis_comparator
      # Remove "version_" prefix if present
      version_id <- gsub("^version_", "", config$compare_with)
      
      # Parse version to check if it's step-wise
      if (grepl("^([0-9]+)([A-Za-z]+)$", version_id)) {
        # Previous is step-wise version (e.g., "44A")
        base_version <- gsub("[A-Za-z].*$", "", version_id)
        previous_version_dir <- file.path(output_root, paste0("version_", base_version), paste0("step_", version_id))
      } else {
        # Previous is standard version (e.g., "43")
        previous_version_dir <- file.path(output_root, paste0("version_", version_id))
      }
      
      previous_inputs_dir <- file.path(previous_version_dir, "inputs")
      
      if (dir.exists(previous_inputs_dir)) {
        previous_gene_files <- list.files(previous_inputs_dir, pattern = "master_gene_list.*\\.xlsx$", full.names = TRUE)
        previous_variant_files <- list.files(previous_inputs_dir, pattern = ".*variant.*\\.xlsx$", full.names = TRUE)
        
        if (length(previous_gene_files) > 0 && length(previous_variant_files) > 0) {
          tryCatch({
            # Use the same centralized loading function for previous data
            previous_prepared_data <- load_excel_files(
              master_gene_list = previous_gene_files[1],
              variant_list = previous_variant_files[1],
              column_mappings = system_config$columns,
              logger = logger
            )
            log_info(logger, "✅ Previous version data loaded successfully using centralized function")
            
            # Keep unfiltered gene list for summary report input comparison
            previous_prepared_data$gene_list_unfiltered <- previous_prepared_data$gene_list
            
            # Apply filtering to previous data as well
            # Write to current version dir (previous dir may be read-only)
            log_info(logger, "Filtering previous version incomplete entries...")
            previous_filtering_result <- filter_incomplete_entries(
              gene_list = previous_prepared_data$gene_list,
              output_dir = version_dir,
              logger = logger
            )
            
            # Update previous prepared_data with filtered gene list
            previous_prepared_data$gene_list <- previous_filtering_result$cleaned_data
            previous_prepared_data$filtering_stats <- previous_filtering_result$filtering_stats
            
            log_info(logger, paste("✅ Previous data filtering completed:", 
                                  previous_filtering_result$filtering_stats$complete_entries, "entries retained,", 
                                  previous_filtering_result$filtering_stats$filtered_entries, "entries excluded"))
            
            # Also load previous variantcall database if it exists
            previous_variantcall_files <- list.files(previous_inputs_dir, pattern = "query_result.*_mod\\.(csv|xlsx)$", full.names = TRUE)
            if (length(previous_variantcall_files) == 0) {
              # Try without _mod suffix
              previous_variantcall_files <- list.files(previous_inputs_dir, pattern = "query_result.*\\.(csv|xlsx)$", full.names = TRUE)
            }
            
            if (length(previous_variantcall_files) > 0) {
              tryCatch({
                prev_vc_file <- previous_variantcall_files[1]
                log_info(logger, paste("Loading previous variantcall database:", basename(prev_vc_file)))
                
                if (grepl("\\.csv$", prev_vc_file, ignore.case = TRUE)) {
                  prev_variantcall_data <- read.csv(prev_vc_file, stringsAsFactors = FALSE)
                } else {
                  prev_variantcall_data <- readxl::read_excel(prev_vc_file)
                }
                
                previous_prepared_data$variantcall_database <- prev_variantcall_data
                prev_approved_count <- sum(prev_variantcall_data$Approval.Status == "approved", na.rm = TRUE)
                log_info(logger, paste("✅ Previous variantcall database loaded:", nrow(prev_variantcall_data), "rows,", prev_approved_count, "approved"))
              }, error = function(e) {
                log_warning(logger, paste("Could not load previous variantcall database:", e$message))
                previous_prepared_data$variantcall_database <- NULL
              })
            } else {
              log_info(logger, "No previous variantcall database found (may not have been used in previous version)")
              previous_prepared_data$variantcall_database <- NULL
            }
          }, error = function(e) {
            log_error(logger, paste("Failed to load previous version data:", e$message))
            previous_prepared_data <- NULL
          })
        } else {
          log_warning(logger, "Previous version input files not found")
        }
      } else {
        log_warning(logger, paste("Previous version directory not found:", previous_inputs_dir))
      }
      
      # Effective usage comparison - use centralized data when available
      if (!is.null(previous_prepared_data)) {
        # Calculate previous usage from centralized data (same as current)
        log_info(logger, "Calculating previous effective usage from centralized previous data")
        previous_usage <- track_effective_variant_usage(
          gene_list = previous_prepared_data$gene_list,
          variant_list_data = previous_prepared_data$variant_list,
          logger = logger
        )
      } else {
        # Fallback to JSON file if centralized data not available
        log_info(logger, "Loading previous effective usage from saved JSON file")
        previous_usage <- load_previous_effective_usage(
          output_dir = config$output_dir,
          compare_with = config$compare_with,
          logger = logger
        )
      }
      
      usage_comparison <- compare_effective_usage(
        current_usage = current_usage,
        previous_usage = previous_usage,
        logger = logger
      )
      
      # Input comparison - pass both current and previous prepared data (no loading in comparator)
      source(file.path(script_dir, "input_comparator.R"))
      comparison_results <- compare_inputs(
        current_gene_list = prepared_data$gene_list,
        current_variant_list = prepared_data$variant_list,
        previous_gene_list = if (!is.null(previous_prepared_data)) previous_prepared_data$gene_list else NULL,
        previous_variant_list = if (!is.null(previous_prepared_data)) previous_prepared_data$variant_list else NULL,
        current_config = list(
          settings = system_config$settings,
          rules = system_config$rules,
          special_cases = system_config$special_cases,
          column_mappings = system_config$columns
        ),
        output_dir = version_dir,
        compare_with = config$compare_with,
        logger = logger
      )
      
      # Store previous data in comparison results for summary report
      if (!is.null(comparison_results)) {
        comparison_results$previous_data <- previous_prepared_data
      }
    }
    
    # Save analysis results
    save_effective_usage(
      usage_data = current_usage,
      comparison_data = usage_comparison,
      output_dir = version_dir,  # Fix: pass version_dir instead of config$output_dir
      logger = logger
    )
    
    # Step 4: Prediction Analysis (if we have comparison data)
    prediction_results <- NULL
    if (!is.null(comparison_results)) {
      log_section(logger, "PREDICTION ANALYSIS")
      source(file.path(script_dir, "predictor.R"))
      
      prediction_results <- predict_changes(
        comparison_results = comparison_results,
        config = list(
          settings = system_config$settings,
          rules = system_config$rules,
          special_cases = system_config$special_cases
        ),
        output_dir = version_dir,
        logger = logger
      )
    }
    
    # Step 5: Generate Rules (the core purpose) - Using pre-loaded data objects
    log_section(logger, "RULE GENERATION")
    
    rule_results <- generate_rules(
      master_gene_list = prepared_data$gene_list,
      variant_list = prepared_data$variant_list,
      cutoff_list = prepared_data$cutoff_list,
      config = list(
        output_dir = version_dir,
        rules_version = config$rules_version,
        settings = system_config$settings,
        rules = system_config$rules,
        special_cases = system_config$special_cases,
        column_mappings = system_config$columns,  # Using simplified columns
        prepared_data = prepared_data  # Pass the full prepared_data including variantCall database
      ),
      logger = logger
    )
    
    log_info(logger, paste("Generated", rule_results$total_rules, "rules"))
    log_info(logger, paste("Output file:", rule_results$output_file))
    
    # Step 6: Prediction Validation (if we made predictions)
    validation_results <- NULL
    if (!is.null(prediction_results)) {
      log_section(logger, "PREDICTION VALIDATION")
      source(file.path(script_dir, "prediction_validator.R"))
      
      validation_results <- validate_predictions(
        predictions = prediction_results,
        current_rules_file = rule_results$output_file,
        output_dir = version_dir,
        compare_with = config$compare_with,
        logger = logger
      )
    }
    
    # Step 7: Generate deployment script
    deployment_script <- generate_deployment_script(version_dir, config$rules_version)
    log_info(logger, paste("Generated deployment script:", deployment_script))
    
    # Step 8: Generate comprehensive summary report (FINAL STEP)
    log_section(logger, "GENERATING COMPREHENSIVE SUMMARY REPORT")
    
    # Generate summary report using prepared data to avoid redundant loading
    log_info(logger, "Generating comprehensive summary report with prepared data")
    source(file.path(script_dir, "generate_summary_report.R"))
    
    # Call the summary report function directly with prepared data
    tryCatch({
      # Extract previous data from comparison results if available
      previous_prepared_data <- NULL
      if (!is.null(comparison_results) && !is.null(comparison_results$previous_data)) {
        previous_prepared_data <- comparison_results$previous_data
      }
      
      summary_output <- generate_summary_report_with_data(
        version_dir = version_dir,
        prepared_data = prepared_data,
        previous_prepared_data = previous_prepared_data,
        compare_with = config$compare_with,
        logger = logger
      )
      log_info(logger, paste("✅ Comprehensive summary report successfully generated:", summary_output))
    }, error = function(e) {
      error_msg <- paste("Summary report generation failed:", e$message)
      log_error(logger, error_msg)
      close_write_trace()
      close_logger(logger)
      stop(error_msg)
    })
    
    log_section(logger, "🎉 SIMPLIFIED RULES GENERATION COMPLETED SUCCESSFULLY")
    
    # Finalize timing and write timing report
    finalize_timing(logger, version_dir)
    
    cat("Rules generation completed successfully!\n")
    cat("Output files are available in:", config$output_dir, "\n")
    
  }, error = function(e) {
    log_error(logger, paste("Error:", e$message))
    close_write_trace()
    close_logger(logger)
    stop(e$message)
  })
  
  # Close the file write trace
  close_write_trace()
  log_info(logger, paste("File write trace saved to:", trace_file_path))
  
  close_logger(logger)
  return(0)
}


# Execute if run directly
if (!interactive()) {
  exit_code <- main()
  quit(status = exit_code)
} 
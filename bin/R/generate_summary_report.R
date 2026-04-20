#!/usr/bin/env Rscript

# Rules Generation Summary Report Generator
# Analyzes all output files and creates a comprehensive summary

# Load required libraries
suppressMessages({
  library(jsonlite)
  library(openxlsx)
  library(knitr)
})

# Load rules analysis comparator module
if (!exists("compare_rule_types")) {
  source("bin/R/rules_analysis_comparator.R")
}

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  cat("Usage: Rscript generate_summary_report.R <version_dir> [output_file]\n")
  cat("Example: Rscript generate_summary_report.R out_rule_generation/version_44\n")
  quit(status = 1)
}

version_dir <- args[1]
output_file <- if (length(args) >= 2) args[2] else paste0(version_dir, "/SUMMARY_REPORT.md")

# Helper functions
format_number <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x)) return("N/A")
  formatC(x, format = "d", big.mark = ",")
}

format_percentage <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x)) return("N/A")
  paste0(round(x * 100, 1), "%")
}

#' Basename of archived master gene list xlsx under inputs/.
#' Convention: master_gene_list*.xlsx; else version_metadata$input_files$master_gene_list if present;
#' else first .xlsx whose name does not contain "variant" (variant supplemental list).
find_archived_master_gene_xlsx <- function(inputs_dir, version_metadata = NULL) {
  if (!dir.exists(inputs_dir)) return(character(0))
  by_pattern <- list.files(inputs_dir, pattern = "master_gene_list.*\\.xlsx$", full.names = FALSE)
  if (length(by_pattern) > 0) return(by_pattern[[1]])
  meta_name <- NULL
  if (!is.null(version_metadata) && !is.null(version_metadata$input_files)) {
    meta_name <- version_metadata$input_files$master_gene_list
  }
  if (!is.null(meta_name) && length(meta_name) > 0) {
    mn <- as.character(meta_name)[[1]]
    if (nzchar(mn) && file.exists(file.path(inputs_dir, mn))) return(mn)
  }
  all_x <- list.files(inputs_dir, pattern = "\\.xlsx$", full.names = FALSE)
  non_variant <- all_x[!grepl("variant", all_x, ignore.case = TRUE)]
  if (length(non_variant) > 0) return(non_variant[[1]])
  character(0)
}

#' Generate input statistics from prepared data
#' @param prepared_data Pre-loaded and column-mapped data from load_excel_files
#' @return List containing input statistics
generate_input_stats_from_prepared_data <- function(prepared_data) {
  tryCatch({
    # Use unfiltered gene list when available so Previous and Current
    # show the same raw input counts. Filtering details are shown
    # separately in the Entry Filtering Summary section.
    gene_data <- prepared_data$gene_list_unfiltered %||% prepared_data$gene_list
    variant_data <- prepared_data$variant_list
    
    # Analyze gene list (data already has mapped columns)
    total_entries <- nrow(gene_data)  # Total rows in the file
    unique_genes <- length(unique(gene_data[, "Gene"]))  # Unique gene names
    
    # Count genes by "Variants To Find" categories
    supplemental_genes <- sum(gene_data[, "Variants.To.Find"] == "See supplemental variant list", na.rm = TRUE)
    other_genes <- total_entries - supplemental_genes
    
    # Count unique genes in supplemental category (excluding NAs consistently)
    supplemental_mask <- !is.na(gene_data[, "Variants.To.Find"]) & 
                        gene_data[, "Variants.To.Find"] == "See supplemental variant list"
    supplemental_gene_names <- unique(gene_data[supplemental_mask, "Gene"])
    unique_supplemental_genes <- length(supplemental_gene_names)
    
    # Calculate unique gene-disease combinations for supplemental genes (using same filtering)
    supplemental_subset <- gene_data[supplemental_mask, ]
    unique_supplemental_combinations <- nrow(unique(supplemental_subset[, c("Gene", "Disease")]))
    
    # Count unique diseases
    unique_diseases <- length(unique(gene_data[, "Disease"]))
    
    # Calculate gene-disease combinations
    gene_disease_combinations <- nrow(gene_data)
    
    # Analyze variant list (data already has mapped columns)
    total_variants <- nrow(variant_data)
    unique_variant_genes <- length(unique(variant_data[, "Gene"]))
    
    # Count variants for supplemental genes
    variants_for_supplemental <- sum(variant_data[, "Gene"] %in% supplemental_gene_names, na.rm = TRUE)
    
    # Enhanced gene usage analysis
    master_gene_names <- unique(gene_data[, "Gene"])
    variant_gene_names <- unique(variant_data[, "Gene"])
    
    # Genes in variant list but NOT in master gene list (unused variant genes)
    unused_variant_genes <- setdiff(variant_gene_names, master_gene_names)
    unused_variant_genes_count <- length(unused_variant_genes)
    
    # Genes in master gene list but NOT marked for supplemental variants (non-supplemental genes)
    non_supplemental_mask <- is.na(gene_data[, "Variants.To.Find"]) | 
                            gene_data[, "Variants.To.Find"] != "See supplemental variant list"
    non_supplemental_gene_names <- unique(gene_data[non_supplemental_mask, "Gene"])
    non_supplemental_genes_count <- length(non_supplemental_gene_names)
    
    # Count variants for unused genes (genes in variant list but not in master list)
    variants_for_unused_genes <- sum(variant_data[, "Gene"] %in% unused_variant_genes, na.rm = TRUE)
    
    # Data Quality Analysis: NA entries (incomplete entries)
    na_gene_rows <- which(is.na(gene_data[, "Gene"]) | gene_data[, "Gene"] == "")
    na_inheritance_rows <- which(is.na(gene_data[, "Inheritance"]) | gene_data[, "Inheritance"] == "")
    na_variants_to_find_rows <- which(is.na(gene_data[, "Variants.To.Find"]) | gene_data[, "Variants.To.Find"] == "")
    
    # Combine all rows with critical NA values
    critical_na_rows <- unique(c(na_gene_rows, na_inheritance_rows, na_variants_to_find_rows))
    
    # Get details of NA entries
    na_entries_details <- data.frame()
    if (length(critical_na_rows) > 0) {
      na_entries_details <- gene_data[critical_na_rows, c("Gene", "Disease", "Inheritance", "Variants.To.Find")]
      # Create unique identifier for each entry
      na_entries_details$ID <- paste0(
        ifelse(is.na(na_entries_details$Gene) | na_entries_details$Gene == "", "[NO_GENE]", na_entries_details$Gene),
        "_",
        ifelse(is.na(na_entries_details$Disease) | na_entries_details$Disease == "", "[NO_DISEASE]", na_entries_details$Disease)
      )
      na_entries_details$Row <- critical_na_rows
    }
    
    # Detailed column breakdowns for reporting
    # Variants To Find breakdown
    variants_to_find_breakdown <- table(gene_data[, "Variants.To.Find"], useNA = "ifany")
    variants_to_find_breakdown <- as.data.frame(variants_to_find_breakdown)
    colnames(variants_to_find_breakdown) <- c("Category", "Count")
    variants_to_find_breakdown$Category <- as.character(variants_to_find_breakdown$Category)
    variants_to_find_breakdown$Category[is.na(variants_to_find_breakdown$Category)] <- "[MISSING]"
    
    # Inheritance breakdown  
    inheritance_breakdown <- table(gene_data[, "Inheritance"], useNA = "ifany")
    inheritance_breakdown <- as.data.frame(inheritance_breakdown)
    colnames(inheritance_breakdown) <- c("Pattern", "Count")
    inheritance_breakdown$Pattern <- as.character(inheritance_breakdown$Pattern)
    inheritance_breakdown$Pattern[is.na(inheritance_breakdown$Pattern)] <- "[MISSING]"
    
    return(list(
      gene_stats = list(
        total_entries = total_entries,
        unique_genes = unique_genes,
        unique_diseases = unique_diseases,
        gene_disease_combinations = gene_disease_combinations,
        supplemental_entries = supplemental_genes,
        unique_supplemental_genes = unique_supplemental_genes,
        unique_supplemental_combinations = unique_supplemental_combinations,
        other_entries = other_genes,
        non_supplemental_genes = non_supplemental_genes_count,
        non_supplemental_gene_names = non_supplemental_gene_names
      ),
      variant_stats = list(
        total_variants = total_variants,
        unique_variant_genes = unique_variant_genes,
        for_supplemental_genes = variants_for_supplemental,
        unused = total_variants - variants_for_supplemental,
        unused_variant_genes = unused_variant_genes_count,
        unused_variant_gene_names = unused_variant_genes,
        variants_for_unused_genes = variants_for_unused_genes
      ),
      na_stats = list(
        total_incomplete_entries = length(critical_na_rows),
        na_gene_count = length(na_gene_rows),
        na_inheritance_count = length(na_inheritance_rows),
        na_variants_to_find_count = length(na_variants_to_find_rows),
        incomplete_entries_details = na_entries_details
      ),
      column_breakdowns = list(
        variants_to_find = variants_to_find_breakdown,
        inheritance = inheritance_breakdown
      )
    ))
  }, error = function(e) {
    return(list(error = paste("Failed to analyze prepared input data:", e$message)))
  })
}

#' Analyze NA entries comparison between versions
#' @param current_na_stats Current version NA statistics
#' @param previous_na_stats Previous version NA statistics  
#' @return List with categorized NA entries (deleted, remaining, new)
analyze_na_entries_comparison <- function(current_na_stats, previous_na_stats) {
  tryCatch({
    # Handle case where one or both stats are missing
    if (is.null(current_na_stats) || is.null(previous_na_stats)) {
      return(list(
        deleted = data.frame(),
        remaining = data.frame(), 
        new = data.frame(),
        summary = list(deleted_count = 0, remaining_count = 0, new_count = 0)
      ))
    }
    
    current_entries <- current_na_stats$incomplete_entries_details
    previous_entries <- previous_na_stats$incomplete_entries_details
    
    # Handle empty data frames
    if (nrow(current_entries) == 0 && nrow(previous_entries) == 0) {
      return(list(
        deleted = data.frame(),
        remaining = data.frame(),
        new = data.frame(),
        summary = list(deleted_count = 0, remaining_count = 0, new_count = 0)
      ))
    }
    
    if (nrow(previous_entries) == 0) {
      # All current entries are new
      return(list(
        deleted = data.frame(),
        remaining = data.frame(),
        new = current_entries,
        summary = list(deleted_count = 0, remaining_count = 0, new_count = nrow(current_entries))
      ))
    }
    
    if (nrow(current_entries) == 0) {
      # All previous entries were deleted
      return(list(
        deleted = previous_entries,
        remaining = data.frame(),
        new = data.frame(),
        summary = list(deleted_count = nrow(previous_entries), remaining_count = 0, new_count = 0)
      ))
    }
    
    # Compare based on ID (Gene_Disease combination)
    current_ids <- current_entries$ID
    previous_ids <- previous_entries$ID
    
    # Categorize entries
    deleted_ids <- setdiff(previous_ids, current_ids)
    remaining_ids <- intersect(previous_ids, current_ids)
    new_ids <- setdiff(current_ids, previous_ids)
    
    deleted_entries <- previous_entries[previous_entries$ID %in% deleted_ids, ]
    remaining_entries <- current_entries[current_entries$ID %in% remaining_ids, ]
    new_entries <- current_entries[current_entries$ID %in% new_ids, ]
    
    return(list(
      deleted = deleted_entries,
      remaining = remaining_entries,
      new = new_entries,
      summary = list(
        deleted_count = nrow(deleted_entries),
        remaining_count = nrow(remaining_entries), 
        new_count = nrow(new_entries)
      )
    ))
  }, error = function(e) {
    return(list(
      error = paste("Failed to analyze NA entries comparison:", e$message),
      deleted = data.frame(),
      remaining = data.frame(),
      new = data.frame(),
      summary = list(deleted_count = 0, remaining_count = 0, new_count = 0)
    ))
  })
}



#' Generate comprehensive summary report using prepared data
#' @param version_dir Version directory path
#' @param prepared_data Pre-loaded and column-mapped current data from load_excel_files
#' @param previous_prepared_data Pre-loaded and column-mapped previous data (optional)
#' @param logger Logger instance (optional)
#' @return Path to generated summary report
generate_summary_report_with_data <- function(version_dir, prepared_data, previous_prepared_data = NULL, compare_with = NULL, logger = NULL) {
  output_file <- file.path(version_dir, "SUMMARY_REPORT.md")
  
  if (!is.null(logger)) {
    log_info(logger, paste("Generating summary report using prepared data"))
    log_info(logger, paste("Output file:", output_file))
  }
  
  # Load and analyze data using the original functions (rules analysis, JSON files, etc.)
  rules_analysis <- analyze_rules_file(version_dir)
  
  # Load previous rules analysis if comparison data is available
  previous_rules_analysis <- NULL
  if (!is.null(compare_with)) {
    # Use robust path resolution like in other functions
    current_dir_name <- basename(version_dir)
    if (grepl("^step_", current_dir_name)) {
      # Current is step-wise, output root is two levels up
      output_root <- dirname(dirname(version_dir))
    } else {
      # Current is standard version, output root is one level up
      output_root <- dirname(version_dir)
    }
    
    # Build previous version path using the same robust logic as other functions
    # Remove "version_" prefix if present
    version_id <- gsub("^version_", "", compare_with)
    
    # Parse version to check if it's step-wise
    if (grepl("^([0-9]+)([A-Za-z]+)$", version_id)) {
      # Previous is step-wise version (e.g., "44A")
      base_version <- gsub("[A-Za-z].*$", "", version_id)
      previous_version_dir <- file.path(output_root, paste0("version_", base_version), paste0("step_", version_id))
    } else {
      # Previous is standard version (e.g., "43")
      previous_version_dir <- file.path(output_root, paste0("version_", version_id))
    }
    
    if (dir.exists(previous_version_dir)) {
      tryCatch({
        previous_rules_analysis <- analyze_rules_file(previous_version_dir)
        if (!is.null(logger)) {
          log_info(logger, paste("✅ Previous rules analysis loaded from:", compare_with))
        }
      }, error = function(e) {
        if (!is.null(logger)) {
          log_warning(logger, paste("Failed to load previous rules analysis:", e$message))
        }
        previous_rules_analysis <- NULL
      })
    } else {
      if (!is.null(logger)) {
        log_warning(logger, paste("Previous version directory not found:", previous_version_dir))
      }
    }
  }
  
  # Generate input statistics from prepared data (no redundant loading)
  input_stats <- generate_input_stats_from_prepared_data(prepared_data)
  
  # Generate previous input statistics if previous data is provided
  previous_stats <- NULL
  if (!is.null(previous_prepared_data)) {
    previous_stats <- generate_input_stats_from_prepared_data(previous_prepared_data)
  }
  
  # Load JSON analyses (these are still loaded from files as before)
  input_comparison_files <- list.files(file.path(version_dir, "analysis", "input_comparison"), pattern = "*.json", full.names = TRUE)
  predictions_files <- list.files(file.path(version_dir, "analysis", "predictions"), pattern = "*.json", full.names = TRUE)
  validation_files <- list.files(file.path(version_dir, "analysis", "prediction_validation"), pattern = "*.json", full.names = TRUE)
  
  input_comparison <- if (length(input_comparison_files) > 0) load_json_file(input_comparison_files[1]) else NULL
  predictions <- if (length(predictions_files) > 0) load_json_file(predictions_files[1]) else NULL
  validation <- if (length(validation_files) > 0) load_json_file(validation_files[1]) else NULL
  
  # Load metadata
  metadata_file <- file.path(version_dir, "metadata.json")
  metadata <- load_json_file(metadata_file)
  
  # Load version metadata (new stepwise versioning system)
  version_metadata_file <- file.path(version_dir, "version_metadata.json")
  version_metadata <- load_json_file(version_metadata_file)
  
  # Generate the report using prepared data
  generate_report_content(version_dir, rules_analysis, previous_rules_analysis, input_stats, previous_stats, input_comparison, 
                         predictions, validation, metadata, output_file, compare_with, prepared_data, previous_prepared_data, version_metadata)
  
  if (!is.null(logger)) {
    log_info(logger, paste("✅ Summary report generated successfully:", output_file))
  }
  
  return(output_file)
}

#' Generate the main report content (extracted from original main logic)
#' @param version_dir Version directory path  
#' @param rules_analysis Rules analysis results
#' @param previous_rules_analysis Previous rules analysis results (optional)
#' @param input_stats Current input statistics 
#' @param previous_stats Previous input statistics (optional)
#' @param input_comparison Input comparison results
#' @param predictions Prediction results
#' @param validation Validation results
#' @param metadata Metadata
#' @param output_file Output file path
generate_report_content <- function(version_dir, rules_analysis, previous_rules_analysis, input_stats, previous_stats, input_comparison, 
                                   predictions, validation, metadata, output_file, compare_with = NULL, prepared_data = NULL, previous_prepared_data = NULL, version_metadata = NULL) {

  report <- character()

  # Header with enhanced version information
  version_num <- basename(version_dir)
  
  # Create enhanced title with version type indicator
  title_suffix <- ""
  if (!is.null(version_metadata) && !is.null(version_metadata$version_type)) {
    if (version_metadata$version_type == "stepwise") {
      title_suffix <- paste0(" (Step-wise Version ", version_metadata$version, ")")
    }
  }
  
  report <- c(report, paste0("# Rules Generation Summary Report", title_suffix))
  report <- c(report, paste0("**Version:** ", version_num))
  
  # Add version comment if available
  if (!is.null(version_metadata) && !is.null(version_metadata$comment) && nchar(version_metadata$comment) > 0) {
    report <- c(report, paste0("**Version Comment:** ", version_metadata$comment))
  }
  
  # Add stepwise lineage if applicable
  if (!is.null(version_metadata) && !is.null(version_metadata$lineage) && !is.null(version_metadata$lineage$stepwise_sequence)) {
    if (length(version_metadata$lineage$stepwise_sequence) > 1) {
      lineage_text <- paste(version_metadata$lineage$stepwise_sequence, collapse = " → ")
      report <- c(report, paste0("**Step-wise Lineage:** ", lineage_text))
    }
  }
  
  report <- c(report, paste0("**Generated:** ", Sys.time()))
  if (!is.null(metadata) && !is.null(metadata$generation_timestamp)) {
    report <- c(report, paste0("**Rules Generated:** ", metadata$generation_timestamp))
  }
  
  # Show comparison target prominently if available
  compared_version <- NULL
  if (!is.null(input_comparison) && !is.null(input_comparison$compared_with)) {
    compared_version <- input_comparison$compared_with
    report <- c(report, paste0("**Compared with:** ", compared_version))
  }
  report <- c(report, "")

  # TABLE OF CONTENTS
  report <- c(report, "## Table of Contents")
  report <- c(report, "")
  report <- c(report, "- **[Part 1: Input Analysis & Comparison](#part-1-input-analysis--comparison)**")
  report <- c(report, "  - Comparison Setup & Data Availability")
  report <- c(report, "  - Master Gene List Analysis")
  report <- c(report, "    - Variants To Find Breakdown")
  report <- c(report, "    - Inheritance Pattern Breakdown")
  report <- c(report, "  - Data Quality Analysis")
  report <- c(report, "    - Entry Filtering Summary")
  report <- c(report, "  - Supplemental Genes Analysis")
  report <- c(report, "  - V1 Variant Supplemental List Analysis")
  report <- c(report, "  - VariantCall Database Analysis")
  report <- c(report, "  - Functional Impact Analysis")
  report <- c(report, "  - Key Changes Summary")
  report <- c(report, "")
  report <- c(report, "- **[Part 2: Rules Generation Results](#part-2-rules-generation-results)**")
  report <- c(report, "  - Data Availability & Output Files")
  report <- c(report, "  - Summary Overview")
  report <- c(report, "  - Rule Types Analysis")
  report <- c(report, "  - Inheritance Patterns")
  report <- c(report, "  - Disease-Gene Metadata")
  report <- c(report, "")
  
  # Part 3 (Rule Change Analysis) removed - not production ready
  
  report <- c(report, "- **[Part 3: Output Files Summary](#part-3-output-files-summary)**")
  report <- c(report, "  - Rules File")
  report <- c(report, "  - Gene List (Science Pipeline)")
  report <- c(report, "  - Disease-Gene Metadata")
  report <- c(report, "  - Analysis Files")
  report <- c(report, "  - Configuration & Metadata")
  report <- c(report, "  - Logs & Deployment")
  report <- c(report, "")
  
  report <- c(report, "- **[Part 4: Rules Generation Logic](#part-4-rules-generation-logic)**")
  report <- c(report, "  - Core Decision Framework")
  report <- c(report, "  - Inheritance Pattern Logic")
  report <- c(report, "  - Rule Generation Strategies")
  report <- c(report, "  - Quality Control & Filters")
  report <- c(report, "  - Rule Templates & Decision Flow")
  report <- c(report, "")
  report <- c(report, "---")
  report <- c(report, "")

  # MAIN PART 1: INPUT ANALYSIS & COMPARISON
  report <- c(report, "# Part 1: Input Analysis & Comparison")
  
  if (!is.null(compared_version)) {
    report <- c(report, paste0("*Primary focus: Changes from ", compared_version, " to ", version_num, " with context provided by current totals*"))
  } else {
    report <- c(report, "*Analysis of input data for this version (no previous version available for comparison)*")
  }
  report <- c(report, "")

  # 1. COMPARISON SETUP & DATA AVAILABILITY (First - confirms correct inputs)
  if (!is.null(input_comparison) && !is.null(input_comparison$compared_with)) {
    
    # File Status Check
    report <- c(report, "## Comparison Setup & Data Availability")
    report <- c(report, "")
    
    # Check if comparison files exist and create unified table for both versions
    # Use output root directory approach for robust path resolution
    current_dir_name <- basename(version_dir)
    if (grepl("^step_", current_dir_name)) {
      # Current is step-wise, output root is two levels up
      output_root <- dirname(dirname(version_dir))
    } else {
      # Current is standard version, output root is one level up
      output_root <- dirname(version_dir)
    }
    
    # Find previous version directory using the same robust logic
    compared_version_dir <- find_previous_version_path(output_root, version_dir, compared_version)
    compared_inputs_dir <- if (!is.null(compared_version_dir)) file.path(compared_version_dir, "inputs") else NULL
    
    current_inputs_dir <- file.path(version_dir, "inputs")
    
    # Create file status table for both versions
    file_status_list <- list()
    
    # Current version files
    file_status_list[["Current Version Directory"]] <- list(
      path = paste0(version_num, "/"),
      status = if (dir.exists(version_dir)) "✅ EXISTS" else "❌ MISSING"
    )
    
    if (dir.exists(current_inputs_dir)) {
      current_gene_file <- find_archived_master_gene_xlsx(current_inputs_dir, version_metadata)
      current_variant_files <- list.files(current_inputs_dir, pattern = ".*variant.*\\.xlsx$", full.names = FALSE)
      
      file_status_list[["Current Gene List"]] <- list(
        path = if (length(current_gene_file) > 0) paste0(version_num, "/inputs/", current_gene_file) else paste0(version_num, "/inputs/[no gene list found]"),
        status = if (length(current_gene_file) > 0) "✅ EXISTS" else "❌ MISSING"
      )
      
      file_status_list[["Current Variant List"]] <- list(
        path = if (length(current_variant_files) > 0) paste0(version_num, "/inputs/", current_variant_files[1]) else paste0(version_num, "/inputs/[no variant list found]"),
        status = if (length(current_variant_files) > 0) "✅ EXISTS" else "❌ MISSING"
      )
      
      # Check for variantCall database files
      current_variantcall_files <- list.files(current_inputs_dir, pattern = "query_result.*\\.(csv|xlsx)$", full.names = FALSE)
      
      file_status_list[["Current VariantCall Database"]] <- list(
        path = if (length(current_variantcall_files) > 0) paste0(version_num, "/inputs/", current_variantcall_files[1]) else paste0(version_num, "/inputs/[no variantCall database found]"),
        status = if (length(current_variantcall_files) > 0) "✅ EXISTS" else "❌ MISSING"
      )
      
      # Check config folder and required files/directories
      current_config_dir <- file.path(current_inputs_dir, "config")
      config_status <- "❌ MISSING"
      config_details <- "config/, rules/, special_cases/, column_mappings.conf, settings.conf"
      
      if (dir.exists(current_config_dir)) {
        # Check for required subdirectories and files
        rules_dir <- file.path(current_config_dir, "rules")
        special_cases_dir <- file.path(current_config_dir, "special_cases")
        column_mappings_file <- file.path(current_config_dir, "column_mappings.conf")
        settings_file <- file.path(current_config_dir, "settings.conf")
        
        if (dir.exists(rules_dir) && dir.exists(special_cases_dir) && 
            file.exists(column_mappings_file) && file.exists(settings_file)) {
          config_status <- "✅ EXISTS"
        } else {
          config_status <- "⚠️ INCOMPLETE"
        }
      }
      
      file_status_list[["Current Config"]] <- list(
        path = paste0(version_num, "/inputs/", config_details),
        status = config_status
      )
    }
    
    # Previous version files
    # Display the actual directory path relative to output root
    if (!is.null(compared_version_dir)) {
      # Get relative path from output root for display
      relative_path <- gsub(paste0("^", output_root, "/"), "", compared_version_dir)
    file_status_list[["Previous Version Directory"]] <- list(
        path = paste0(relative_path, "/"),
      status = if (dir.exists(compared_version_dir)) "✅ EXISTS" else "❌ MISSING"
    )
    } else {
      file_status_list[["Previous Version Directory"]] <- list(
        path = paste0(compared_version, "/"),
        status = "❌ MISSING"
      )
    }
    
    if (!is.null(compared_inputs_dir) && dir.exists(compared_inputs_dir)) {
      previous_metadata <- NULL
      prev_meta_file <- file.path(compared_version_dir, "version_metadata.json")
      if (file.exists(prev_meta_file)) previous_metadata <- load_json_file(prev_meta_file)
      gene_files <- find_archived_master_gene_xlsx(compared_inputs_dir, previous_metadata)
      variant_files <- list.files(compared_inputs_dir, pattern = ".*variant.*\\.xlsx$", full.names = FALSE)
      
      # Get relative path for display
      relative_path <- gsub(paste0("^", output_root, "/"), "", compared_version_dir)
      
      file_status_list[["Previous Gene List"]] <- list(
        path = if (length(gene_files) > 0) paste0(relative_path, "/inputs/", gene_files[1]) else paste0(relative_path, "/inputs/[no gene list found]"),
        status = if (length(gene_files) > 0) "✅ EXISTS" else "❌ MISSING"
      )
      
      file_status_list[["Previous Variant List"]] <- list(
        path = if (length(variant_files) > 0) paste0(relative_path, "/inputs/", variant_files[1]) else paste0(relative_path, "/inputs/[no variant list found]"),
        status = if (length(variant_files) > 0) "✅ EXISTS" else "❌ MISSING"
      )
      
      # Check for previous variantCall database files
      previous_variantcall_files <- list.files(compared_inputs_dir, pattern = "query_result.*\\.(csv|xlsx)$", full.names = FALSE)
      
      file_status_list[["Previous VariantCall Database"]] <- list(
        path = if (length(previous_variantcall_files) > 0) paste0(relative_path, "/inputs/", previous_variantcall_files[1]) else paste0(relative_path, "/inputs/[no variantCall database found]"),
        status = if (length(previous_variantcall_files) > 0) "✅ EXISTS" else "❌ MISSING"
      )
      
      # Check previous config folder and required files/directories
      previous_config_dir <- file.path(compared_inputs_dir, "config")
      previous_config_status <- "❌ MISSING"
      config_details <- "config/, rules/, special_cases/, column_mappings.conf, settings.conf"
      
      if (dir.exists(previous_config_dir)) {
        # Check for required subdirectories and files
        rules_dir <- file.path(previous_config_dir, "rules")
        special_cases_dir <- file.path(previous_config_dir, "special_cases")
        column_mappings_file <- file.path(previous_config_dir, "column_mappings.conf")
        settings_file <- file.path(previous_config_dir, "settings.conf")
        
        if (dir.exists(rules_dir) && dir.exists(special_cases_dir) && 
            file.exists(column_mappings_file) && file.exists(settings_file)) {
          previous_config_status <- "✅ EXISTS"
    } else {
          previous_config_status <- "⚠️ INCOMPLETE"
        }
      }
      
      file_status_list[["Previous Config"]] <- list(
        path = paste0(relative_path, "/inputs/", config_details),
        status = previous_config_status
      )
    } else {
      # Get relative path for display or fallback to raw version string
      display_path <- if (!is.null(compared_version_dir)) {
        relative_path <- gsub(paste0("^", output_root, "/"), "", compared_version_dir)
        paste0(relative_path, "/inputs/")
      } else {
        paste0(compared_version, "/inputs/")
      }
      
      file_status_list[["Previous Inputs Directory"]] <- list(
        path = display_path,
        status = "❌ MISSING"
      )
    }
    
    # Create clean status table without duplicate row names
    file_status_df <- data.frame(
      "File/Directory" = names(file_status_list),
      "Location" = sapply(file_status_list, function(x) x$path),
      "Status" = sapply(file_status_list, function(x) x$status),
      stringsAsFactors = FALSE,
      check.names = FALSE,
      row.names = NULL
    )
    
    file_status_table <- kable(file_status_df, format = "markdown", align = c("l", "l", "c"), row.names = FALSE)
    report <- c(report, file_status_table)
    report <- c(report, "")
  }

  # 2. DESCRIPTIVE STATISTICS OF INPUT FILES (with previous vs current)
  if (!is.null(input_stats$error)) {
    report <- c(report, paste("**Error loading input statistics:** ", input_stats$error))
      report <- c(report, "")
  } else {
    
    # Master Gene List Statistics (with comparison)
    report <- c(report, "## Master Gene List Analysis")
    report <- c(report, "")
    
    if (!is.null(previous_stats)) {
      gene_stats_df <- data.frame(
        "Category" = c("Total Entries", "Unique Genes", "Unique Diseases", "Gene-Disease Combinations"),
        "Previous" = c(
          format_number(previous_stats$gene_stats$total_entries),
          format_number(previous_stats$gene_stats$unique_genes),
          format_number(previous_stats$gene_stats$unique_diseases),
          format_number(previous_stats$gene_stats$gene_disease_combinations)
        ),
        "Current" = c(
          format_number(input_stats$gene_stats$total_entries),
          format_number(input_stats$gene_stats$unique_genes),
          format_number(input_stats$gene_stats$unique_diseases),
          format_number(input_stats$gene_stats$gene_disease_combinations)
        ),
        "Description" = c(
          "Total rows in master gene list file",
          "Distinct gene names in master gene list",
          "Distinct diseases/conditions covered",
          "Unique combinations of genes and diseases"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    } else {
      gene_stats_df <- data.frame(
        "Category" = c("Total Entries", "Unique Genes", "Unique Diseases", "Gene-Disease Combinations"),
        "Current" = c(
          format_number(input_stats$gene_stats$total_entries),
          format_number(input_stats$gene_stats$unique_genes),
          format_number(input_stats$gene_stats$unique_diseases),
          format_number(input_stats$gene_stats$gene_disease_combinations)
        ),
        "Description" = c(
          "Total rows in master gene list file",
          "Distinct gene names in master gene list",
          "Distinct diseases/conditions covered",
          "Unique combinations of genes and diseases"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
    
    gene_stats_table <- kable(gene_stats_df, format = "markdown", align = c("l", "r", "r", "l"))
    report <- c(report, gene_stats_table)
    report <- c(report, "")
    
    # Detailed Column Breakdowns
    report <- c(report, "### Variants To Find Breakdown")
    report <- c(report, "")
    report <- c(report, "**Distribution of variant finding strategies across all gene-disease combinations:**")
    report <- c(report, "")
    
    # Create Variants To Find comparison table
    if (!is.null(previous_stats) && !is.null(previous_stats$column_breakdowns) && !is.null(input_stats$column_breakdowns)) {
      # Merge current and previous data for comparison
      current_vtf <- input_stats$column_breakdowns$variants_to_find
      previous_vtf <- previous_stats$column_breakdowns$variants_to_find
      
      # Get all unique categories
      all_vtf_categories <- unique(c(current_vtf$Category, previous_vtf$Category))
      
      # Create comparison data frame
      vtf_comparison_df <- data.frame(
        "Strategy" = all_vtf_categories,
        "Previous" = sapply(all_vtf_categories, function(cat) {
          idx <- which(previous_vtf$Category == cat)
          if (length(idx) > 0) format_number(previous_vtf$Count[idx]) else "0"
        }),
        "Current" = sapply(all_vtf_categories, function(cat) {
          idx <- which(current_vtf$Category == cat)
          if (length(idx) > 0) format_number(current_vtf$Count[idx]) else "0"
        }),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      
      # Calculate changes
      vtf_comparison_df$Change <- sapply(1:nrow(vtf_comparison_df), function(i) {
        prev_val <- as.numeric(gsub(",", "", vtf_comparison_df$Previous[i]))
        curr_val <- as.numeric(gsub(",", "", vtf_comparison_df$Current[i]))
        change_val <- curr_val - prev_val
        if (change_val > 0) paste0("+", format_number(change_val))
        else if (change_val < 0) as.character(change_val)
        else "0"
      })
      
      vtf_table <- kable(vtf_comparison_df, format = "markdown", align = c("l", "r", "r", "r"))
    } else {
      # Current only
      current_vtf <- input_stats$column_breakdowns$variants_to_find
      vtf_table <- kable(current_vtf, format = "markdown", align = c("l", "r"))
    }
    
    report <- c(report, vtf_table)
    report <- c(report, "")
    
    # Inheritance Pattern Breakdown
    report <- c(report, "### Inheritance Pattern Breakdown")
    report <- c(report, "")
    report <- c(report, "**Distribution of inheritance patterns across all gene-disease combinations:**")
    report <- c(report, "")
    
    # Create Inheritance comparison table
    if (!is.null(previous_stats) && !is.null(previous_stats$column_breakdowns) && !is.null(input_stats$column_breakdowns)) {
      # Merge current and previous data for comparison
      current_inh <- input_stats$column_breakdowns$inheritance
      previous_inh <- previous_stats$column_breakdowns$inheritance
      
      # Get all unique patterns
      all_inh_patterns <- unique(c(current_inh$Pattern, previous_inh$Pattern))
      
      # Create comparison data frame
      inh_comparison_df <- data.frame(
        "Pattern" = all_inh_patterns,
        "Previous" = sapply(all_inh_patterns, function(pat) {
          idx <- which(previous_inh$Pattern == pat)
          if (length(idx) > 0) format_number(previous_inh$Count[idx]) else "0"
        }),
        "Current" = sapply(all_inh_patterns, function(pat) {
          idx <- which(current_inh$Pattern == pat)
          if (length(idx) > 0) format_number(current_inh$Count[idx]) else "0"
        }),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      
      # Calculate changes
      inh_comparison_df$Change <- sapply(1:nrow(inh_comparison_df), function(i) {
        prev_val <- as.numeric(gsub(",", "", inh_comparison_df$Previous[i]))
        curr_val <- as.numeric(gsub(",", "", inh_comparison_df$Current[i]))
        change_val <- curr_val - prev_val
        if (change_val > 0) paste0("+", format_number(change_val))
        else if (change_val < 0) as.character(change_val)
        else "0"
      })
      
      inh_table <- kable(inh_comparison_df, format = "markdown", align = c("l", "r", "r", "r"))
    } else {
      # Current only
      current_inh <- input_stats$column_breakdowns$inheritance
      inh_table <- kable(current_inh, format = "markdown", align = c("l", "r"))
    }
    
    report <- c(report, inh_table)
    report <- c(report, "")
    
    # Data Quality Analysis (NA/incomplete entries)
    report <- c(report, "## Data Quality Analysis")
    report <- c(report, "")
    report <- c(report, "**Analysis of incomplete entries with missing critical information (Gene Name, Inheritance, Variants To Find)**")
    report <- c(report, "")
    
    # Entry Filtering Summary (new filtering system)
    if (!is.null(prepared_data$filtering_stats)) {
      filtering_stats <- prepared_data$filtering_stats
      
      report <- c(report, "### Entry Filtering Summary")
      report <- c(report, "")
      report <- c(report, "**Automatic filtering of entries missing essential information for rule generation:**")
      report <- c(report, "")
      
      # Create filtering summary table
      filtering_summary_df <- data.frame(
        "Category" = c("Original Entries", "Complete Entries", "Filtered Entries", "Success Rate"),
        "Count" = c(
          format_number(filtering_stats$total_entries),
          format_number(filtering_stats$complete_entries),
          format_number(filtering_stats$filtered_entries),
          paste0(round((filtering_stats$complete_entries / filtering_stats$total_entries) * 100, 1), "%")
        ),
        "Description" = c(
          "Total entries in master gene list file",
          "Entries with all essential fields (used for rule generation)",
          "Entries excluded due to missing Gene, Disease, Inheritance, or Variants To Find",
          "Percentage of entries that passed filtering"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      
      filtering_table <- kable(filtering_summary_df, format = "markdown", align = c("l", "r", "l"))
      report <- c(report, filtering_table)
      report <- c(report, "")
      
      # Add information about filtered entries file
      if (filtering_stats$filtered_entries > 0) {
        report <- c(report, paste("**📁 Filtered Entries File:** `filtered_incomplete_entries.tsv` contains", 
                                 filtering_stats$filtered_entries, "excluded entries with detailed exclusion reasons for manual review."))
        report <- c(report, "")
        
        # Show sample of filtered entries (first 5)
        if (nrow(filtering_stats$filtering_details) > 0) {
          report <- c(report, "**Sample of Filtered Entries:**")
          report <- c(report, "")
          
          sample_size <- min(5, nrow(filtering_stats$filtering_details))
          for (i in 1:sample_size) {
            entry <- filtering_stats$filtering_details[i, ]
            gene_text <- ifelse(entry$Gene == "[MISSING]", "[MISSING]", entry$Gene)
            disease_text <- ifelse(entry$Disease == "[MISSING]", "[MISSING]", entry$Disease)
            
            report <- c(report, paste("- **Row", entry$Row_Number, ":** Gene:", gene_text, 
                                     "| Disease:", disease_text, "| Reason:", entry$Exclusion_Reason))
          }
          
          if (nrow(filtering_stats$filtering_details) > 5) {
            report <- c(report, paste("- ... and", nrow(filtering_stats$filtering_details) - 5, "more entries (see `filtered_incomplete_entries.tsv`)"))
          }
          report <- c(report, "")
        }
      } else {
        report <- c(report, "**✅ All entries passed filtering** - no incomplete entries were found.")
        report <- c(report, "")
      }
    }
    
    # Generate NA comparison if previous stats available
    if (!is.null(previous_stats) && !is.null(previous_stats$na_stats) && !is.null(input_stats$na_stats)) {
      na_comparison <- analyze_na_entries_comparison(input_stats$na_stats, previous_stats$na_stats)
      
      # Create summary table
      prev_total <- previous_stats$na_stats$total_incomplete_entries
      curr_total <- input_stats$na_stats$total_incomplete_entries
      na_summary_df <- data.frame(
        "Category" = c("Deleted", "Remaining", "New", "**Total**"),
        "Previous" = c(
          format_number(na_comparison$summary$deleted_count),
          format_number(na_comparison$summary$remaining_count),
          format_number(na_comparison$summary$new_count),
          format_number(prev_total)
        ),
        "Current" = c(
          format_number(na_comparison$summary$deleted_count),
          format_number(na_comparison$summary$remaining_count),
          format_number(na_comparison$summary$new_count),
          format_number(curr_total)
        ),
        "Change" = c(
          if (na_comparison$summary$deleted_count > 0) paste0("-", na_comparison$summary$deleted_count) else "0",
          "0",
          if (na_comparison$summary$new_count > 0) paste0("+", na_comparison$summary$new_count) else "0",
          as.character(curr_total - prev_total)
        ),
        "Description" = c(
          "Incomplete entries that were resolved (no longer missing critical data)",
          "Incomplete entries that persist from previous version",
          "New incomplete entries (missing Gene, Inheritance, or Variants To Find)",
          "All entries currently missing critical information"
            ),
            stringsAsFactors = FALSE,
            check.names = FALSE
          )
          
      na_summary_table <- kable(na_summary_df, format = "markdown", align = c("l", "r", "r", "r", "l"))
      report <- c(report, na_summary_table)
          report <- c(report, "")
          
      # Add detailed lists if there are entries
      if (na_comparison$summary$deleted_count > 0) {
        report <- c(report, "### Deleted (Resolved) Incomplete Entries")
        report <- c(report, "")
        report <- c(report, paste("**", na_comparison$summary$deleted_count, "entries** that had missing data in the previous version but are now complete or removed:"))
        report <- c(report, "")
        if (nrow(na_comparison$deleted) <= 10) {
          for (i in 1:nrow(na_comparison$deleted)) {
            entry <- na_comparison$deleted[i, ]
            report <- c(report, paste("- **", entry$Disease, "** (Gene:", ifelse(is.na(entry$Gene), "[MISSING]", entry$Gene), ")"))
          }
            } else {
          for (i in 1:5) {
            entry <- na_comparison$deleted[i, ]
            report <- c(report, paste("- **", entry$Disease, "** (Gene:", ifelse(is.na(entry$Gene), "[MISSING]", entry$Gene), ")"))
          }
          report <- c(report, paste("- ... and", nrow(na_comparison$deleted) - 5, "more entries"))
            }
            report <- c(report, "")
          }
      
      if (na_comparison$summary$new_count > 0) {
        report <- c(report, "### New Incomplete Entries")
        report <- c(report, "")
        report <- c(report, paste("**", na_comparison$summary$new_count, "new entries** with missing critical information:"))
        report <- c(report, "")
        if (nrow(na_comparison$new) <= 10) {
          for (i in 1:nrow(na_comparison$new)) {
            entry <- na_comparison$new[i, ]
            missing_fields <- c()
            if (is.na(entry$Gene) || entry$Gene == "") missing_fields <- c(missing_fields, "Gene")
            if (is.na(entry$Inheritance) || entry$Inheritance == "") missing_fields <- c(missing_fields, "Inheritance")
            if (is.na(entry$Variants.To.Find) || entry$Variants.To.Find == "") missing_fields <- c(missing_fields, "Variants To Find")
            report <- c(report, paste("- **", entry$Disease, "** (Missing:", paste(missing_fields, collapse = ", "), ")"))
          }
        } else {
          for (i in 1:5) {
            entry <- na_comparison$new[i, ]
            missing_fields <- c()
            if (is.na(entry$Gene) || entry$Gene == "") missing_fields <- c(missing_fields, "Gene")
            if (is.na(entry$Inheritance) || entry$Inheritance == "") missing_fields <- c(missing_fields, "Inheritance")
            if (is.na(entry$Variants.To.Find) || entry$Variants.To.Find == "") missing_fields <- c(missing_fields, "Variants To Find")
            report <- c(report, paste("- **", entry$Disease, "** (Missing:", paste(missing_fields, collapse = ", "), ")"))
          }
          report <- c(report, paste("- ... and", nrow(na_comparison$new) - 5, "more entries"))
        }
        report <- c(report, "")
      }
      
      if (na_comparison$summary$remaining_count > 0) {
        report <- c(report, "### Persistent Incomplete Entries")
  report <- c(report, "")
        report <- c(report, paste("**", na_comparison$summary$remaining_count, "entries** with missing data that persist from the previous version."))
    report <- c(report, "")
      }
      
    } else {
      # No comparison available, just show current NA stats
      current_incomplete <- input_stats$na_stats$total_incomplete_entries
      if (current_incomplete > 0) {
        report <- c(report, paste("**", format_number(current_incomplete), "incomplete entries** found with missing critical information."))
    report <- c(report, "")
    
        na_breakdown_df <- data.frame(
          "Missing Field" = c("Gene Name", "Inheritance", "Variants To Find", "**Any Critical Field**"),
      "Count" = c(
            format_number(input_stats$na_stats$na_gene_count),
            format_number(input_stats$na_stats$na_inheritance_count),
            format_number(input_stats$na_stats$na_variants_to_find_count),
            format_number(input_stats$na_stats$total_incomplete_entries)
      ),
      "Description" = c(
            "Entries missing gene symbol",
            "Entries missing inheritance pattern", 
            "Entries missing variant finding strategy",
            "Total entries with any missing critical field"
      ),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    
        na_breakdown_table <- kable(na_breakdown_df, format = "markdown", align = c("l", "r", "l"))
        report <- c(report, na_breakdown_table)
    report <- c(report, "")
      } else {
        report <- c(report, "✅ **No incomplete entries found** - All entries have complete Gene Name, Inheritance, and Variants To Find information.")
        report <- c(report, "")
      }
    }
    
    # Supplemental Genes Analysis (with comparison)
    report <- c(report, "## Supplemental Genes Analysis")
    report <- c(report, "")
    
    if (!is.null(previous_stats)) {
    supplemental_df <- data.frame(
      "Category" = c("Supplemental Entries", "Unique Supplemental Genes", "Unique Gene-Disease Combinations"),
        "Previous" = c(
          format_number(previous_stats$gene_stats$supplemental_entries),
          format_number(previous_stats$gene_stats$unique_supplemental_genes),
          format_number(previous_stats$gene_stats$unique_supplemental_combinations)
        ),
        "Current" = c(
        format_number(input_stats$gene_stats$supplemental_entries),
        format_number(input_stats$gene_stats$unique_supplemental_genes),
        format_number(input_stats$gene_stats$unique_supplemental_combinations)
      ),
      "Description" = c(
        "Total rows with 'See supplemental variant list' in Variants To Find column",
        "Distinct genes marked for supplemental variant list",
        "Unique combinations of supplemental genes and diseases"
      ),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    } else {
      supplemental_df <- data.frame(
        "Category" = c("Supplemental Entries", "Unique Supplemental Genes", "Unique Gene-Disease Combinations"),
        "Current" = c(
          format_number(input_stats$gene_stats$supplemental_entries),
          format_number(input_stats$gene_stats$unique_supplemental_genes),
          format_number(input_stats$gene_stats$unique_supplemental_combinations)
        ),
        "Description" = c(
          "Total rows with 'See supplemental variant list' in Variants To Find column",
          "Distinct genes marked for supplemental variant list",
          "Unique combinations of supplemental genes and diseases"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
    
    supplemental_table <- kable(supplemental_df, format = "markdown", align = c("l", "r", "r", "l"))
    report <- c(report, supplemental_table)
    report <- c(report, "")
    
    # V1 Variant Supplemental List Analysis (with comparison)
    report <- c(report, "## V1 Variant Supplemental List Analysis")
    report <- c(report, "")
    
    if (!is.null(previous_stats)) {
    variant_stats_df <- data.frame(
      "Category" = c("Total Variants", "Unique Variant Genes", "Used Variants", "Unused Variants"),
        "Previous" = c(
          format_number(previous_stats$variant_stats$total_variants),
          format_number(previous_stats$variant_stats$unique_variant_genes),
          format_number(previous_stats$variant_stats$for_supplemental_genes),
          format_number(previous_stats$variant_stats$unused)
        ),
        "Current" = c(
        format_number(input_stats$variant_stats$total_variants),
        format_number(input_stats$variant_stats$unique_variant_genes),
        format_number(input_stats$variant_stats$for_supplemental_genes),
        format_number(input_stats$variant_stats$unused)
      ),
      "Description" = c(
        "All variants in supplemental variant list",
        "Distinct genes with variants in supplemental list",
        "Variants for genes marked as 'See supplemental variant list'",
        "Variants for genes not in current master gene list"
      ),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    } else {
      variant_stats_df <- data.frame(
        "Category" = c("Total Variants", "Unique Variant Genes", "Used Variants", "Unused Variants"),
        "Current" = c(
          format_number(input_stats$variant_stats$total_variants),
          format_number(input_stats$variant_stats$unique_variant_genes),
          format_number(input_stats$variant_stats$for_supplemental_genes),
          format_number(input_stats$variant_stats$unused)
        ),
        "Description" = c(
          "All variants in supplemental variant list",
          "Distinct genes with variants in supplemental list",
          "Variants for genes marked as 'See supplemental variant list'",
          "Variants for genes not in current master gene list"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
    
    variant_stats_table <- kable(variant_stats_df, format = "markdown", align = c("l", "r", "r", "l"))
    report <- c(report, variant_stats_table)
    report <- c(report, "")
  }

  # VariantCall Database Analysis
  report <- c(report, "## VariantCall Database Analysis")
  report <- c(report, "")
  
  # Check if variantCall database data is available in prepared_data
  if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database)) {
    variantcall_data <- prepared_data$variantcall_database
    
    # Analyze variantCall database statistics
    total_variants <- nrow(variantcall_data)
    approved_variants <- sum(variantcall_data$Approval.Status == "approved", na.rm = TRUE)
    rejected_variants <- sum(variantcall_data$Approval.Status == "rejected", na.rm = TRUE)
    pending_variants <- total_variants - approved_variants - rejected_variants
    
    # Analyze approved variants
    if (approved_variants > 0) {
      approved_data <- variantcall_data[variantcall_data$Approval.Status == "approved", ]
      unique_genes <- length(unique(approved_data$Gene.Name[!is.na(approved_data$Gene.Name)]))
      unique_diseases <- length(unique(approved_data$Report.Science.ID[!is.na(approved_data$Report.Science.ID)]))
    } else {
      unique_genes <- 0
      unique_diseases <- 0
    }
    
    # Create comparison table if previous data is available
    if (!is.null(previous_prepared_data) && !is.null(previous_prepared_data$variantcall_database)) {
      previous_variantcall_data <- previous_prepared_data$variantcall_database
      previous_total <- nrow(previous_variantcall_data)
      previous_approved <- sum(previous_variantcall_data$Approval.Status == "approved", na.rm = TRUE)
      previous_rejected <- sum(previous_variantcall_data$Approval.Status == "rejected", na.rm = TRUE)
      previous_pending <- previous_total - previous_approved - previous_rejected
      
      if (previous_approved > 0) {
        previous_approved_data <- previous_variantcall_data[previous_variantcall_data$Approval.Status == "approved", ]
        previous_unique_genes <- length(unique(previous_approved_data$Gene.Name[!is.na(previous_approved_data$Gene.Name)]))
        previous_unique_diseases <- length(unique(previous_approved_data$Report.Science.ID[!is.na(previous_approved_data$Report.Science.ID)]))
      } else {
        previous_unique_genes <- 0
        previous_unique_diseases <- 0
      }
      
      variantcall_stats_df <- data.frame(
        "Category" = c("Total Variants", "Approved Variants", "Rejected Variants", "Pending/Other Variants", "Unique Genes (Approved)", "Unique Diseases (Approved)"),
        "Previous" = c(
          format_number(previous_total),
          format_number(previous_approved),
          format_number(previous_rejected),
          format_number(previous_pending),
          format_number(previous_unique_genes),
          format_number(previous_unique_diseases)
        ),
        "Current" = c(
          format_number(total_variants),
          format_number(approved_variants),
          format_number(rejected_variants),
          format_number(pending_variants),
          format_number(unique_genes),
          format_number(unique_diseases)
        ),
        "Description" = c(
          "All variants in variantCall database",
          "Variants with 'approved' status (used for rule generation)",
          "Variants with 'rejected' status (excluded from rules)",
          "Variants with blank or other status values",
          "Distinct genes with approved variants",
          "Distinct diseases/conditions with approved variants"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    } else {
      variantcall_stats_df <- data.frame(
        "Category" = c("Total Variants", "Approved Variants", "Rejected Variants", "Pending/Other Variants", "Unique Genes (Approved)", "Unique Diseases (Approved)"),
        "Current" = c(
          format_number(total_variants),
          format_number(approved_variants),
          format_number(rejected_variants),
          format_number(pending_variants),
          format_number(unique_genes),
          format_number(unique_diseases)
        ),
        "Description" = c(
          "All variants in variantCall database",
          "Variants with 'approved' status (used for rule generation)",
          "Variants with 'rejected' status (excluded from rules)",
          "Variants with blank or other status values",
          "Distinct genes with approved variants",
          "Distinct diseases/conditions with approved variants"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
    
    variantcall_stats_table <- kable(variantcall_stats_df, format = "markdown", align = c("l", "r", "r", "l"))
    report <- c(report, variantcall_stats_table)
    report <- c(report, "")
    
    # Add explanation of variantCall database usage
    report <- c(report, "**VariantCall Database Usage:**")
    report <- c(report, "- Only variants with 'approved' status are processed into classification rules")
    report <- c(report, "- Each approved variant generates a position-specific rule with gene and genomic coordinates")
    report <- c(report, "- Rules include SYMBOL, CHROM, POS, REF, ALT conditions plus standard quality filters")
    report <- c(report, "- This replaces the previous config-based variant changes system")
    report <- c(report, "")
  } else {
    report <- c(report, "**No VariantCall Database:** This version does not include a variantCall database file.")
    report <- c(report, "")
  }

  # 3. FUNCTIONAL IMPACT ANALYSIS (after descriptive stats)
  if (!is.null(input_comparison) && !is.null(input_comparison$compared_with)) {
    # Effective Usage Analysis (focus on functional impact)
    if (file.exists(file.path(version_dir, "analysis", "effective_usage_comparison.json"))) {
      report <- c(report, "## Functional Impact Analysis")
      report <- c(report, "")
      report <- c(report, "**Why This Matters:** File changes don't always translate to rule changes. This analysis identifies")
      report <- c(report, "which input modifications actually affect the generated classification rules, helping prioritize")
      report <- c(report, "validation efforts and understand the real scope of changes.")
      report <- c(report, "")
      report <- c(report, "**Key Insights:**")
      report <- c(report, "- **ALL Master Gene List changes affect rules** - Every gene generates rules regardless of strategy")
      report <- c(report, "- **Variant List changes affect subset** - Only genes marked 'See supplemental variant list' use variant file")
      report <- c(report, "- **VariantCall Database adds position-specific rules** - Each approved variant generates a targeted rule")
      report <- c(report, "- **Total impact = Master Gene List + Variant List + VariantCall Database impacts**")
      report <- c(report, "")
      
      effective_usage <- load_json_file(file.path(version_dir, "analysis", "effective_usage_comparison.json"))
      
      if (!is.null(effective_usage) && !("error" %in% names(effective_usage))) {
        
        # Create comprehensive functional impact table covering ALL impacts
        functional_impact_df <- data.frame(
          "Functional Metric" = c(
            "🧬 MASTER GENE LIST IMPACT",
            "Total Rule-Generating Genes",
            "Gene-Disease Combinations", 
            "Non-Supplemental Genes",
            "📋 VARIANT LIST IMPACT",
            "Supplemental Genes",
            "Actually Used Variants",
            "Variant File Utilization Rate",
            "Unused Variant Genes",
            "🔬 VARIANTCALL DATABASE IMPACT",
            "Total Approved Variants",
            "Unique Genes (Approved)",
            "Unique Diseases (Approved)",
            "Position-Specific Rules Generated"
          ),
          "Previous" = c(
            "", # Section header
            if (!is.null(previous_stats)) format_number(previous_stats$gene_stats$unique_genes) else "N/A",
            if (!is.null(previous_stats)) format_number(previous_stats$gene_stats$gene_disease_combinations) else "N/A",
            if (!is.null(previous_stats)) format_number(previous_stats$gene_stats$non_supplemental_genes) else "N/A",
            "", # Section header  
            format_number(effective_usage$previous_supplemental_genes),
            format_number(effective_usage$previous_used_variants),
            if(effective_usage$previous_used_variants > 0 && !is.null(previous_stats)) {
              paste0(format_percentage(effective_usage$previous_used_variants / previous_stats$variant_stats$total_variants))
            } else "N/A",
            if (!is.null(previous_stats)) format_number(previous_stats$variant_stats$unused_variant_genes) else "N/A",
            "", # Section header
            if (!is.null(previous_prepared_data) && !is.null(previous_prepared_data$variantcall_database)) {
              sum(previous_prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE)
            } else "0",
            if (!is.null(previous_prepared_data) && !is.null(previous_prepared_data$variantcall_database)) {
              approved_data <- previous_prepared_data$variantcall_database[previous_prepared_data$variantcall_database$Approval.Status == "approved", ]
              if (nrow(approved_data) > 0) length(unique(approved_data$Gene.Name[!is.na(approved_data$Gene.Name)])) else "0"
            } else "0",
            if (!is.null(previous_prepared_data) && !is.null(previous_prepared_data$variantcall_database)) {
              approved_data <- previous_prepared_data$variantcall_database[previous_prepared_data$variantcall_database$Approval.Status == "approved", ]
              if (nrow(approved_data) > 0) length(unique(approved_data$Report.Science.ID[!is.na(approved_data$Report.Science.ID)])) else "0"
            } else "0",
            if (!is.null(previous_prepared_data) && !is.null(previous_prepared_data$variantcall_database)) {
              sum(previous_prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE)
            } else "0"
          ),
          "Current" = c(
            "", # Section header
            format_number(input_stats$gene_stats$unique_genes),
            format_number(input_stats$gene_stats$gene_disease_combinations),
            format_number(input_stats$gene_stats$non_supplemental_genes),
            "", # Section header
            format_number(effective_usage$current_supplemental_genes),
            format_number(effective_usage$current_used_variants),
            paste0(format_percentage(effective_usage$current_used_variants / input_stats$variant_stats$total_variants)),
            format_number(input_stats$variant_stats$unused_variant_genes),
            "", # Section header
            if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database)) {
              format_number(sum(prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE))
            } else "0",
            if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database)) {
              approved_data <- prepared_data$variantcall_database[prepared_data$variantcall_database$Approval.Status == "approved", ]
              if (nrow(approved_data) > 0) format_number(length(unique(approved_data$Gene.Name[!is.na(approved_data$Gene.Name)]))) else "0"
            } else "0",
            if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database)) {
              approved_data <- prepared_data$variantcall_database[prepared_data$variantcall_database$Approval.Status == "approved", ]
              if (nrow(approved_data) > 0) format_number(length(unique(approved_data$Report.Science.ID[!is.na(approved_data$Report.Science.ID)]))) else "0"
            } else "0",
            if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database)) {
              format_number(sum(prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE))
            } else "0"
          ),
          "Change" = c(
            "", # Section header
            # Master Gene List changes  
            if (!is.null(previous_stats) && !is.null(input_stats)) {
              diff <- input_stats$gene_stats$unique_genes - previous_stats$gene_stats$unique_genes
              if (diff != 0) paste0(if(diff > 0) "+" else "", diff) else "0"
            } else "N/A",
            if (!is.null(previous_stats) && !is.null(input_stats)) {
              diff <- input_stats$gene_stats$gene_disease_combinations - previous_stats$gene_stats$gene_disease_combinations
              if (diff != 0) paste0(if(diff > 0) "+" else "", diff) else "0"
            } else "N/A",
            if (!is.null(previous_stats) && !is.null(input_stats)) {
              diff <- input_stats$gene_stats$non_supplemental_genes - previous_stats$gene_stats$non_supplemental_genes
              if (diff != 0) paste0(if(diff > 0) "+" else "", diff) else "0"
            } else "N/A",
            "", # Section header
            # Variant List changes
            if(effective_usage$current_supplemental_genes != effective_usage$previous_supplemental_genes) {
              paste0(if(effective_usage$current_supplemental_genes > effective_usage$previous_supplemental_genes) "+" else "",
                     effective_usage$current_supplemental_genes - effective_usage$previous_supplemental_genes)
            } else "0",
            if(effective_usage$current_used_variants != effective_usage$previous_used_variants) {
              paste0(if(effective_usage$current_used_variants > effective_usage$previous_used_variants) "+" else "",
                     effective_usage$current_used_variants - effective_usage$previous_used_variants)
            } else "0",
            if(effective_usage$current_used_variants != effective_usage$previous_used_variants && !is.null(previous_stats)) {
              current_rate <- effective_usage$current_used_variants / input_stats$variant_stats$total_variants
              previous_rate <- effective_usage$previous_used_variants / previous_stats$variant_stats$total_variants
              rate_change <- current_rate - previous_rate
              paste0(if(rate_change > 0) "+" else "", format_percentage(rate_change))
            } else "0%",
            if (!is.null(previous_stats) && !is.null(input_stats)) {
              diff <- input_stats$variant_stats$unused_variant_genes - previous_stats$variant_stats$unused_variant_genes
              if (diff != 0) paste0(if(diff > 0) "+" else "", diff) else "0"
            } else "N/A",
            "", # Section header
            # VariantCall Database changes
            if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database) && 
                !is.null(previous_prepared_data) && !is.null(previous_prepared_data$variantcall_database)) {
              current_approved <- sum(prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE)
              previous_approved <- sum(previous_prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE)
              diff <- current_approved - previous_approved
              if (diff != 0) paste0(if(diff > 0) "+" else "", diff) else "0"
            } else if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database)) {
              paste0("+", sum(prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE))
            } else "0",
            if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database) && 
                !is.null(previous_prepared_data) && !is.null(previous_prepared_data$variantcall_database)) {
              current_approved_data <- prepared_data$variantcall_database[prepared_data$variantcall_database$Approval.Status == "approved", ]
              previous_approved_data <- previous_prepared_data$variantcall_database[previous_prepared_data$variantcall_database$Approval.Status == "approved", ]
              current_genes <- if (nrow(current_approved_data) > 0) length(unique(current_approved_data$Gene.Name[!is.na(current_approved_data$Gene.Name)])) else 0
              previous_genes <- if (nrow(previous_approved_data) > 0) length(unique(previous_approved_data$Gene.Name[!is.na(previous_approved_data$Gene.Name)])) else 0
              diff <- current_genes - previous_genes
              if (diff != 0) paste0(if(diff > 0) "+" else "", diff) else "0"
            } else if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database)) {
              approved_data <- prepared_data$variantcall_database[prepared_data$variantcall_database$Approval.Status == "approved", ]
              if (nrow(approved_data) > 0) paste0("+", length(unique(approved_data$Gene.Name[!is.na(approved_data$Gene.Name)]))) else "0"
            } else "0",
            if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database) && 
                !is.null(previous_prepared_data) && !is.null(previous_prepared_data$variantcall_database)) {
              current_approved_data <- prepared_data$variantcall_database[prepared_data$variantcall_database$Approval.Status == "approved", ]
              previous_approved_data <- previous_prepared_data$variantcall_database[previous_prepared_data$variantcall_database$Approval.Status == "approved", ]
              current_diseases <- if (nrow(current_approved_data) > 0) length(unique(current_approved_data$Report.Science.ID[!is.na(current_approved_data$Report.Science.ID)])) else 0
              previous_diseases <- if (nrow(previous_approved_data) > 0) length(unique(previous_approved_data$Report.Science.ID[!is.na(previous_approved_data$Report.Science.ID)])) else 0
              diff <- current_diseases - previous_diseases
              if (diff != 0) paste0(if(diff > 0) "+" else "", diff) else "0"
            } else if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database)) {
              approved_data <- prepared_data$variantcall_database[prepared_data$variantcall_database$Approval.Status == "approved", ]
              if (nrow(approved_data) > 0) paste0("+", length(unique(approved_data$Report.Science.ID[!is.na(approved_data$Report.Science.ID)]))) else "0"
            } else "0",
            if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database) && 
                !is.null(previous_prepared_data) && !is.null(previous_prepared_data$variantcall_database)) {
              current_approved <- sum(prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE)
              previous_approved <- sum(previous_prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE)
              diff <- current_approved - previous_approved
              if (diff != 0) paste0(if(diff > 0) "+" else "", diff) else "0"
            } else if (!is.null(prepared_data) && !is.null(prepared_data$variantcall_database)) {
              paste0("+", sum(prepared_data$variantcall_database$Approval.Status == "approved", na.rm = TRUE))
            } else "0"
          ),
          "Description" = c(
            "**Master Gene List affects ALL rule generation**",
            "Every unique gene generates rules (PTV only, ClinVar P+LP, Missense+nonsense, Supplemental variants)",
            "Each gene-disease combination creates distinct rule sets with inheritance-specific thresholds",
            "Genes using PTV/ClinVar/Missense strategies (generate rules without needing variant file)",
            "**Variant file affects only supplemental genes**", 
            "Genes marked 'See supplemental variant list' (these generate variant-specific HGVSc rules)",
            "Specific variants from supplemental list actually used in rule generation",
            "Percentage of variant file entries that are functionally utilized",
            "Genes in variant list that are NOT in master gene list (unused entries)",
            "**VariantCall Database affects position-specific rules**",
            "Approved variants from variantCall database (each generates a position-specific rule)",
            "Distinct genes with approved variants (rules include SYMBOL + genomic coordinates)",
            "Distinct diseases/conditions with approved variants (rules target specific conditions)",
            "Position-specific rules generated (SYMBOL + CHROM + POS + REF + quality filters)"
          ),
          stringsAsFactors = FALSE,
          check.names = FALSE
        )
        
        functional_table <- kable(functional_impact_df, format = "markdown", align = c("l", "r", "r", "r", "l"))
        report <- c(report, functional_table)
        report <- c(report, "")
        
        # Comprehensive impact assessment covering both Master Gene List and Variant List changes
        report <- c(report, "### Comprehensive Impact Assessment")
        report <- c(report, "")
        
        # Calculate Master Gene List impact
        master_gene_changes <- 0
        if (!is.null(previous_stats) && !is.null(input_stats)) {
          gene_diff <- input_stats$gene_stats$unique_genes - previous_stats$gene_stats$unique_genes
          combo_diff <- input_stats$gene_stats$gene_disease_combinations - previous_stats$gene_stats$gene_disease_combinations
          master_gene_changes <- abs(gene_diff) + abs(combo_diff)
        }
        
        # Calculate Variant List impact
        variant_changes <- 0
        if (!is.null(effective_usage$variant_changes)) {
          variant_changes <- abs(effective_usage$variant_changes$net_change)
        }
        
        # Total functional impact
        total_functional_impact <- master_gene_changes + variant_changes
        
        if (total_functional_impact > 0) {
          report <- c(report, paste0("**Total Functional Impact:** ", total_functional_impact, " functional changes affecting rule generation"))
          report <- c(report, "")
          
          # Master Gene List impact
          if (master_gene_changes > 0) {
            report <- c(report, paste0("📋 **Master Gene List Impact:** ", master_gene_changes, " changes"))
            if (!is.null(previous_stats) && !is.null(input_stats)) {
              gene_diff <- input_stats$gene_stats$unique_genes - previous_stats$gene_stats$unique_genes
              combo_diff <- input_stats$gene_stats$gene_disease_combinations - previous_stats$gene_stats$gene_disease_combinations
              if (gene_diff != 0) {
                report <- c(report, paste0("- **Gene Changes:** ", if(gene_diff > 0) "+" else "", gene_diff, " genes → affects ALL rule strategies"))
              }
              if (combo_diff != 0) {
                report <- c(report, paste0("- **Gene-Disease Changes:** ", if(combo_diff > 0) "+" else "", combo_diff, " combinations → affects inheritance logic"))
              }
            }
            report <- c(report, "")
          }
          
          # Variant List impact
          if (variant_changes > 0 && !is.null(effective_usage$variant_changes)) {
            net_change <- effective_usage$variant_changes$net_change
            report <- c(report, paste0("🧬 **Variant List Impact:** ", variant_changes, " changes to supplemental rules"))
            report <- c(report, paste0("- **Supplemental Variants:** ", if(net_change > 0) "+" else "", net_change, " variants → affects HGVSc-specific rules"))
            report <- c(report, "")
          }
          
          # Combined implications
          report <- c(report, "**🎯 Validation Priorities:**")
          if (master_gene_changes > 0) {
            report <- c(report, "- **Master Gene List changes affect ALL rules** - Priority for comprehensive validation")
          }
          if (variant_changes > 0) {
            report <- c(report, "- **Variant List changes affect supplemental genes only** - Focus on HGVSc-specific rules")
          }
          report <- c(report, "- **Testing Strategy:** Validate both broad rule changes and specific variant rules")
          
        } else {
          report <- c(report, "**Total Functional Impact:** No functional changes affecting rule generation")
          report <- c(report, "- **Stable Rules:** Input file changes do not affect rule generation logic")
          report <- c(report, "- **Low Risk:** Changes are likely administrative or formatting updates")
          report <- c(report, "- **Minimal Testing:** Focus on rule quality rather than coverage changes")
        }
        report <- c(report, "")
        
        # Add detailed gene usage breakdown
        report <- c(report, "### Gene Usage Breakdown")
        report <- c(report, "")
        
        # Information about unused variant genes (genes in variant list but not in master list)
        if (input_stats$variant_stats$unused_variant_genes > 0) {
          report <- c(report, paste0("**Unused Variant Genes (", input_stats$variant_stats$unused_variant_genes, " genes):**"))
          report <- c(report, paste0("These genes have ", format_number(input_stats$variant_stats$variants_for_unused_genes), 
                                   " variants in the supplemental list but are not present in the master gene list."))
          
          # Show first few unused genes as examples
          unused_genes_sample <- head(input_stats$variant_stats$unused_variant_gene_names, 10)
          if (length(unused_genes_sample) > 0) {
            report <- c(report, "")
            if (length(unused_genes_sample) <= 5) {
              report <- c(report, paste0("- **All unused genes:** ", paste(unused_genes_sample, collapse = ", ")))
            } else {
              report <- c(report, paste0("- **Examples:** ", paste(head(unused_genes_sample, 5), collapse = ", ")))
              if (input_stats$variant_stats$unused_variant_genes > 5) {
                report <- c(report, paste0("- **Total:** ", input_stats$variant_stats$unused_variant_genes, " unused genes"))
              }
            }
          }
          report <- c(report, "- **Action:** Consider adding these genes to the master list or removing obsolete variants")
          report <- c(report, "")
        }
        
        # Information about non-supplemental genes (genes in master list but not using variants)
        if (input_stats$gene_stats$non_supplemental_genes > 0) {
          report <- c(report, paste0("**Non-Supplemental Genes (", input_stats$gene_stats$non_supplemental_genes, " genes):**"))
          report <- c(report, "These genes are in the master list but do not reference the supplemental variant list.")
          
          # Show first few non-supplemental genes as examples
          non_supplemental_sample <- head(input_stats$gene_stats$non_supplemental_gene_names, 10)
          if (length(non_supplemental_sample) > 0) {
            report <- c(report, "")
            if (length(non_supplemental_sample) <= 5) {
              report <- c(report, paste0("- **Examples:** ", paste(non_supplemental_sample, collapse = ", ")))
            } else {
              report <- c(report, paste0("- **Examples:** ", paste(head(non_supplemental_sample, 5), collapse = ", ")))
              if (input_stats$gene_stats$non_supplemental_genes > 5) {
                report <- c(report, paste0("- **Total:** ", input_stats$gene_stats$non_supplemental_genes, " non-supplemental genes"))
              }
            }
          }
          report <- c(report, "- **Action:** Consider if any of these genes should reference specific variants")
          report <- c(report, "")
        }
        

      }
    }
  }

  # 4. KEY CHANGES SUMMARY (end of Part 1)
  if (!is.null(input_comparison) && !is.null(input_comparison$compared_with)) {
    # Main Changes Analysis
    if (!is.null(input_comparison$gene_comparison)) {
      report <- c(report, "## Key Changes Summary")
      report <- c(report, "")
      
      gene_comp <- input_comparison$gene_comparison
      variant_comp <- input_comparison$variant_comparison
      
      # Create a summary changes table
      changes_df <- data.frame(
        "Input Type" = c("Gene List Entries", "Gene List Entries", "Gene List Entries", "Variant List", "Variant List"),
        "Change Type" = c("Added", "Deleted", "Modified", "Added", "Deleted"),
        "Count" = c(
          format_number(gene_comp$total_added),
          format_number(gene_comp$total_deleted), 
          format_number(gene_comp$total_modified),
          format_number(variant_comp$added_variants),
          format_number(variant_comp$deleted_variants)
        ),
        "Impact" = c(
          if(gene_comp$total_added > 0) "New rules will be generated" else "No impact",
          if(gene_comp$total_deleted > 0) "Some rules will be removed" else "No impact", 
          if(gene_comp$total_modified > 0) "Some rules may change" else "No impact",
          if(variant_comp$added_variants > 0) "New specific variants covered" else "No impact",
          if(variant_comp$deleted_variants > 0) "Some specific variants no longer covered" else "No impact"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      
      changes_table <- kable(changes_df, format = "markdown", align = c("l", "l", "r", "l"))
      report <- c(report, changes_table)
      report <- c(report, "")
    }
  }

  # MAIN PART 2: RULES GENERATION RESULTS  
  report <- c(report, "# Part 2: Rules Generation Results")
  report <- c(report, "*Summary of generated classification rules with statistics, distributions, and output files*")
  report <- c(report, "")

  # Data Availability Section for Part 2
  report <- c(report, "## Data Availability & Output Files")
  report <- c(report, "")
  
  # Check for current rules file
  current_rules_files <- list.files(file.path(version_dir, "outputs"), pattern = ".*rules_file.*\\.tsv$", full.names = FALSE)
  current_rules_status <- if (length(current_rules_files) > 0) "✅ EXISTS" else "❌ MISSING"
  current_rules_location <- if (length(current_rules_files) > 0) paste0(basename(version_dir), "/outputs/", current_rules_files[1]) else "N/A"
  
  # Check for previous rules file if comparison is enabled
  previous_rules_status <- "N/A"
  previous_rules_location <- "N/A"
  if (!is.null(compare_with)) {
    # Use same robust path resolution as in rules analysis loading
    current_dir_name <- basename(version_dir)
    if (grepl("^step_", current_dir_name)) {
      # Current is step-wise, output root is two levels up
      output_root <- dirname(dirname(version_dir))
    } else {
      # Current is standard version, output root is one level up
      output_root <- dirname(version_dir)
    }
    
    # Use the same robust logic as Part 1 to find previous version path
    previous_version_dir <- find_previous_version_path(output_root, version_dir, compare_with)
    if (!is.null(previous_version_dir) && dir.exists(previous_version_dir)) {
      previous_rules_files <- list.files(file.path(previous_version_dir, "outputs"), pattern = ".*rules_file.*\\.tsv$", full.names = FALSE)
      previous_rules_status <- if (length(previous_rules_files) > 0) "✅ EXISTS" else "❌ MISSING"
      # Get relative path from output root for display consistency
      relative_path <- gsub(paste0("^", output_root, "/"), "", previous_version_dir)
      previous_rules_location <- if (length(previous_rules_files) > 0) paste0(relative_path, "/outputs/", previous_rules_files[1]) else "N/A"
    } else {
      previous_rules_status <- "❌ MISSING"
      previous_rules_location <- "N/A"
    }
  }
  
  # Create availability table
  availability_df <- data.frame(
    "File/Directory" = c("Current Rules File", "Previous Rules File"),
    "Location" = c(current_rules_location, previous_rules_location),
    "Status" = c(current_rules_status, previous_rules_status),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    row.names = NULL
  )
  
  availability_table <- kable(availability_df, format = "markdown", align = c("l", "l", "c"), row.names = FALSE)
  report <- c(report, availability_table)
  report <- c(report, "")

  if (!is.null(rules_analysis$error)) {
    report <- c(report, paste("**Error:** ", rules_analysis$error))
  } else {
    report <- c(report, paste0("**Total Rules Generated:** ", format_number(rules_analysis$total_rules)))
  
  # Add summary overview table
  report <- c(report, "", "## Summary Overview")
  
  # Generate summary statistics  
  summary_stats <- generate_summary_stats(rules_analysis, previous_rules_analysis, version_dir, compare_with)
  
  summary_overview_df <- data.frame(
    "Metric" = c("Total Diseases", "Total Genes", "Total Rules"),
    "Previous" = c(
      format_number(summary_stats$total_diseases_previous),
      format_number(summary_stats$total_genes_previous), 
      format_number(summary_stats$total_rules_previous)
    ),
    "Current" = c(
      format_number(summary_stats$total_diseases_current),
      format_number(summary_stats$total_genes_current),
      format_number(summary_stats$total_rules_current)
    ),
    "Change" = c(
      if (summary_stats$total_diseases_current != summary_stats$total_diseases_previous) {
        paste0(if(summary_stats$total_diseases_current > summary_stats$total_diseases_previous) "+" else "",
               summary_stats$total_diseases_current - summary_stats$total_diseases_previous)
      } else "0",
      if (summary_stats$total_genes_current != summary_stats$total_genes_previous) {
        paste0(if(summary_stats$total_genes_current > summary_stats$total_genes_previous) "+" else "",
               summary_stats$total_genes_current - summary_stats$total_genes_previous)
      } else "0",
      if (summary_stats$total_rules_current != summary_stats$total_rules_previous) {
        paste0(if(summary_stats$total_rules_current > summary_stats$total_rules_previous) "+" else "",
               summary_stats$total_rules_current - summary_stats$total_rules_previous)
      } else "0"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  
  report <- c(report, "", knitr::kable(summary_overview_df, format = "markdown", align = c("l", "r", "r", "r")))
  
  # Add change summary if comparison is enabled  
  if (!is.null(compare_with)) {
    report <- c(report, "")
    if (summary_stats$diseases_with_changes > 0 || summary_stats$genes_with_changes > 0) {
      report <- c(report, paste0("**Changes Detected:** ", summary_stats$diseases_with_changes, " diseases and ", 
                                summary_stats$genes_with_changes, " genes have rule changes"))
    } else {
      report <- c(report, "**No Changes:** No diseases or genes have rule changes")
    }
  }
  
  # Generate TSV files if comparison is enabled
  tsv_files_info <- ""
  if (!is.null(compare_with) && !is.null(version_dir)) {
    tsv_info <- generate_detailed_tsv_files(version_dir, compare_with)
    if (!is.null(tsv_info)) {
      tsv_files_info <- paste0(" (", tsv_info$disease_count, " diseases, ", tsv_info$gene_count, " genes)")
    }
  }
  
  report <- c(report, "", "**Detailed Analysis Files:**")
  report <- c(report, paste0("- Disease-level rule changes: `analysis/rule_changes/disease_rule_changes.tsv`", tsv_files_info))
  report <- c(report, paste0("- Gene-level rule changes: `analysis/rule_changes/gene_rule_changes.tsv`", tsv_files_info))
    
    if (!is.null(metadata) && !is.null(metadata$processing_time_seconds)) {
    report <- c(report, paste0("**Processing Time:** ", round(metadata$processing_time_seconds, 1), " seconds"))
    
    # Add reference to detailed timing file
    timing_file <- file.path(version_dir, "step_timings.json")
    if (file.exists(timing_file)) {
      report <- c(report, "**Detailed Step Timing:** Available in `step_timings.json` for performance analysis")
    }
    
    rules_per_sec <- rules_analysis$total_rules / metadata$processing_time_seconds
      report <- c(report, paste0("**Generation Rate:** ", round(rules_per_sec, 0), " rules/second"))
    }
    report <- c(report, "")
    
    # Rule Types Table
    report <- c(report, "## Rule Types Analysis")
    report <- c(report, "*Breakdown of rules by variant consequence type and classification method*")
    report <- c(report, "")
    
    # Generate rule types comparison using modular function
    rule_types_comparison <- compare_rule_types(rules_analysis, previous_rules_analysis)
    
    rule_types_table <- kable(rule_types_comparison$table_df, format = "markdown", align = c("l", "r", "r", "r"), row.names = FALSE)
    report <- c(report, rule_types_table)
    report <- c(report, "")
    
    # Add analysis text if available
    if (length(rule_types_comparison$analysis_text) > 0) {
      report <- c(report, rule_types_comparison$analysis_text)
      report <- c(report, "")
    }
    
    # Inheritance Pattern
    report <- c(report, "## Inheritance Patterns")
    report <- c(report, "*Distribution of rules by inheritance pattern determining variant counting thresholds*")
    report <- c(report, "")
    
    # Generate inheritance patterns comparison using modular function
    inheritance_comparison <- compare_inheritance_patterns(rules_analysis, previous_rules_analysis, version_dir, compare_with)
    
    inheritance_table <- kable(inheritance_comparison$table_df, format = "markdown", align = c("l", "r", "r", "r"), row.names = FALSE)
    report <- c(report, inheritance_table)
    report <- c(report, "")
    
    # Add analysis text if available
    if (length(inheritance_comparison$analysis_text) > 0) {
      report <- c(report, inheritance_comparison$analysis_text)
    report <- c(report, "")
    }
    
  }

  # Disease-Gene Metadata Summary
  metadata_file <- list.files(file.path(version_dir, "outputs"),
                              pattern = ".*_disease_gene_metadata\\.tsv$",
                              full.names = TRUE)
  if (length(metadata_file) > 0) {
    metadata <- read.csv(metadata_file[1], sep = "\t", stringsAsFactors = FALSE)

    prev_metadata <- NULL
    if (!is.null(compare_with)) {
      current_dir_name <- basename(version_dir)
      if (grepl("^step_", current_dir_name)) {
        output_root_meta <- dirname(dirname(version_dir))
      } else {
        output_root_meta <- dirname(version_dir)
      }
      prev_version_dir_meta <- find_previous_version_path(output_root_meta, version_dir, compare_with)
      if (!is.null(prev_version_dir_meta) && dir.exists(prev_version_dir_meta)) {
        prev_metadata_file <- list.files(file.path(prev_version_dir_meta, "outputs"),
                                         pattern = ".*_disease_gene_metadata\\.tsv$",
                                         full.names = TRUE)
        if (length(prev_metadata_file) > 0) {
          prev_metadata <- read.csv(prev_metadata_file[1], sep = "\t", stringsAsFactors = FALSE)
        }
      }
    }

    cur_inh <- table(metadata$inheritance)
    cur_carrier <- sum(metadata$carrier == TRUE | metadata$carrier == "TRUE")

    all_patterns <- sort(unique(c(names(cur_inh),
                                  if (!is.null(prev_metadata)) names(table(prev_metadata$inheritance)))))
    metrics <- c("Total entries", all_patterns, "Carrier entries")

    cur_vals <- c(nrow(metadata),
                  sapply(all_patterns, function(p) as.integer(ifelse(p %in% names(cur_inh), cur_inh[p], 0))),
                  cur_carrier)

    if (!is.null(prev_metadata)) {
      prev_inh <- table(prev_metadata$inheritance)
      prev_carrier <- sum(prev_metadata$carrier == TRUE | prev_metadata$carrier == "TRUE")
      prev_vals <- c(nrow(prev_metadata),
                     sapply(all_patterns, function(p) as.integer(ifelse(p %in% names(prev_inh), prev_inh[p], 0))),
                     prev_carrier)
      changes <- cur_vals - prev_vals
    } else {
      prev_vals <- rep(NA, length(metrics))
      changes <- rep(NA, length(metrics))
    }

    meta_summary_df <- data.frame(
      Metric = metrics,
      Previous = prev_vals,
      Current = cur_vals,
      Change = changes,
      stringsAsFactors = FALSE
    )

    report <- c(report, "## Disease-Gene Metadata")
    report <- c(report, "*Summary of disease-gene metadata file (inheritance and carrier status per gene-disease pair)*")
    report <- c(report, "")
    report <- c(report, kable(meta_summary_df, format = "markdown", align = c("l", "r", "r", "r")))
    report <- c(report, "")
    report <- c(report, paste0("**File:** `outputs/", basename(metadata_file[1]), "`"))
    report <- c(report, "")
  }

  # MAIN PART 3: OUTPUT FILES SUMMARY
  report <- c(report, "# Part 3: Output Files Summary")
  report <- c(report, "")
  
  # Add stepwise version references if applicable
  if (!is.null(version_metadata) && !is.null(version_metadata$lineage) && !is.null(version_metadata$lineage$stepwise_sequence)) {
    if (length(version_metadata$lineage$stepwise_sequence) > 1 && version_metadata$version_type == "stepwise") {
      report <- c(report, "## Step-wise Development References")
      report <- c(report, "")
      report <- c(report, "This version is part of a step-wise development process. For detailed insights into specific changes, refer to previous steps:")
      report <- c(report, "")
      
      # Generate references to previous steps (updated for nested structure)
      for (i in 1:(length(version_metadata$lineage$stepwise_sequence) - 1)) {
        step_version <- version_metadata$lineage$stepwise_sequence[i]
        
        # Determine path based on whether it's a step or base version
        step_parts <- strsplit(step_version, "")[[1]]
        if (any(grepl("[A-Za-z]", step_parts))) {
          # Step version: nested within base version directory
          base_version <- gsub("[A-Za-z].*$", "", step_version)
          base_version_dir <- file.path(dirname(version_dir), paste0("version_", base_version))
          step_path <- file.path(base_version_dir, paste0("step_", step_version))
        } else {
          # Base version: direct version directory
          step_path <- file.path(dirname(version_dir), paste0("version_", step_version))
        }
        
        # Try to load metadata for this step to get the comment
        step_metadata_file <- file.path(step_path, "version_metadata.json")
        step_comment <- ""
        if (file.exists(step_metadata_file)) {
          tryCatch({
            step_metadata <- jsonlite::fromJSON(step_metadata_file)
            if (!is.null(step_metadata$comment) && nchar(step_metadata$comment) > 0) {
              step_comment <- paste0(" - ", step_metadata$comment)
            }
          }, error = function(e) {})
        }
        
        # Create relative paths for cleaner display
        base_output_dir <- dirname(dirname(version_dir))  # Go up to project root
        relative_step_path <- file.path("out_rule_generation", basename(dirname(step_path)), basename(step_path))
        
        report <- c(report, paste0("- **Version ", step_version, "**", step_comment))
        report <- c(report, paste0("  - Summary Report: `", relative_step_path, "/SUMMARY_REPORT.md`"))
        if (file.exists(file.path(step_path, "outputs"))) {
          report <- c(report, paste0("  - Rules Output: `", relative_step_path, "/outputs/`"))
        }
        report <- c(report, "")
      }
      
      report <- c(report, "---")
      report <- c(report, "")
    }
  }

  # List all output files with descriptions
  output_files <- list()

  # Rules file
  rules_files <- list.files(file.path(version_dir, "outputs"), pattern = ".*rules_file.*\\.tsv$", full.names = FALSE)
  if (length(rules_files) > 0) {
    output_files[["Rules File"]] <- list(
      path = paste0("outputs/", rules_files[1]),
      description = "Main rules file containing all generated variant classification rules"
    )
  }

  # JSON files
  json_files <- list.files(file.path(version_dir, "outputs"), pattern = ".*\\.json$", full.names = FALSE)
  for (json_file in json_files) {
    desc <- switch(
      gsub(".*list_of_analyzed_genes", "genes", json_file),
      "genes_science_pipeline_names.json" = "Gene list for science pipeline (disease names as keys)",
      "JSON output file"
    )
    output_files[[json_file]] <- list(
      path = paste0("outputs/", json_file),
      description = desc
    )
  }

  # Disease-gene metadata TSV
  metadata_tsv_files <- list.files(file.path(version_dir, "outputs"),
                                   pattern = ".*_disease_gene_metadata\\.tsv$",
                                   full.names = FALSE)
  if (length(metadata_tsv_files) > 0) {
    output_files[["Disease-Gene Metadata"]] <- list(
      path = paste0("outputs/", metadata_tsv_files[1]),
      description = "Disease-gene metadata (inheritance, carrier status)"
    )
  }

  # Analysis files
  if (!is.null(input_comparison)) {
    output_files[["Input Comparison"]] <- list(
      path = "analysis/input_comparison/",
      description = "Detailed comparison with previous version inputs"
    )
  }

  if (!is.null(predictions)) {
    output_files[["Predictions"]] <- list(
      path = "analysis/predictions/",
      description = "Predictions of expected changes based on input analysis"
    )
  }

  if (!is.null(validation)) {
    output_files[["Validation"]] <- list(
      path = "analysis/prediction_validation/",
      description = "Validation of predictions against actual results"
    )
  }

  # Config and metadata
  output_files[["Configuration"]] <- list(
    path = "config/",
    description = "Copy of configuration files used for this generation"
  )

  output_files[["Metadata"]] <- list(
    path = "metadata.json",
    description = "Generation metadata and summary statistics"
  )

  output_files[["Logs"]] <- list(
    path = "logs/",
    description = "Detailed generation logs and trace files"
  )

  output_files[["Deployment"]] <- list(
    path = "deployment/",
    description = "S3 deployment scripts (if generated)"
  )

  # Output the files table with true two-row format per entry
  # Create cleaner display names for the first column
  display_names <- sapply(names(output_files), function(name) {
    switch(name,
      "Rules File" = "Rules File",
      "list_of_analyzed_genes_science_pipeline_names.json" = "Gene List (Pipeline)",
      "Disease-Gene Metadata" = "Disease-Gene Metadata",
      "Input Comparison" = "Input Comparison",
      "Predictions" = "Predictions",
      "Validation" = "Validation", 
      "Configuration" = "Configuration",
      "Metadata" = "Metadata",
      "Logs" = "Logs",
      "Deployment" = "Deployment",
      name  # fallback to original name
    )
  })
  
  # Create pairs of rows for each file entry
  file_col <- character()
  desc_col <- character()
  
  for (i in seq_along(output_files)) {
    name <- display_names[i]
    file_info <- output_files[[i]]
    
    # First row: name and description
    file_col <- c(file_col, name)
    desc_col <- c(desc_col, file_info$description)
    
    # Second row: empty and path
    file_col <- c(file_col, "")
    desc_col <- c(desc_col, paste0("`", file_info$path, "`"))
  }
  
  output_files_df <- data.frame(
    "File/Directory" = file_col,
    "Description & Path" = desc_col,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  output_files_table <- kable(output_files_df, format = "markdown", align = c("l", "l"))
  report <- c(report, output_files_table)

  report <- c(report, "")

  # Footer
  # MAIN PART 4: RULES GENERATION LOGIC
  report <- c(report, "")
  report <- c(report, "---")
  report <- c(report, "")
  report <- c(report, "# Part 4: Rules Generation Logic")
  report <- c(report, "*Detailed explanation of how input data is transformed into classification rules*")
  report <- c(report, "")
  report <- c(report, "*This section provides in-depth technical details for understanding rule generation logic,*")
  report <- c(report, "*resolving discrepancies, and analyzing the decision framework behind observed changes.*")
  report <- c(report, "")
  
  # Include comprehensive logic explanation from markdown file
  part4_logic_file <- "bin/R/rules_generation_logic.md"
  if (file.exists(part4_logic_file)) {
    part4_logic <- readLines(part4_logic_file)
    report <- c(report, part4_logic)
  } else {
    report <- c(report, "*Part 4 logic file not found*")
  }
  
  report <- c(report, "")
  report <- c(report, "---")
  report <- c(report, "*Report generated by Rules Generation Framework*")

  # Write report
  writeLines(report, output_file)

  cat("Summary report generated:", output_file, "\n")
  cat("Report length:", length(report), "lines\n")

}

# Load and analyze data
analyze_rules_file <- function(version_dir) {
  rules_files <- list.files(file.path(version_dir, "outputs"), pattern = ".*rules_file.*\\.tsv$", full.names = TRUE)
  if (length(rules_files) == 0) return(list(error = "No rules file found"))
  
  rules_data <- read.table(rules_files[1], sep = "\t", header = TRUE, stringsAsFactors = FALSE, quote = "")
  
  # Analyze rule types
  rule_analysis <- list()
  
  # Count by rule type patterns
  rule_analysis$total_rules <- nrow(rules_data)
  
  # Analyze by rule pattern
  clinvar_p_lp <- sum(grepl("ClinVar_CLNSIG == Pathogenic.*STARS >= 1|ClinVar_CLNSIG == Likely_pathogenic.*STARS >= 1", rules_data$RULE))
  
  frameshift_stop <- sum(grepl("Consequence == frameshift_variant|Consequence == stop_gained", rules_data$RULE))
  
  missense_variants <- sum(grepl("Consequence == missense_variant", rules_data$RULE))
  
  splice_variants <- sum(grepl("splice_acceptor_variant|splice_donor_variant|splice_region_variant", rules_data$RULE))
  
  spliceai_rules <- sum(grepl("SpliceAI_pred", rules_data$RULE))
  
  specific_variants <- sum(grepl("HGVSc =~", rules_data$RULE))
  
  special_rules <- sum(grepl("Validation|HFE|CFTR|HBB", rules_data$RULE))
  
  # Count by inheritance pattern
  ar_rules <- sum(rules_data$cThresh == 2)
  dom_rules <- sum(rules_data$cThresh == 1)
  
  # Count by disease
  diseases <- unique(rules_data$Disease_report)
  disease_counts <- table(rules_data$Disease_report)
  
  rule_analysis$rule_types <- list(
    "ClinVar P/LP (STARS ≥ 1)" = clinvar_p_lp,
    "Frameshift/Stop Gained" = frameshift_stop,
    "Missense Variants" = missense_variants,
    "Splice Site Variants" = splice_variants,
    "SpliceAI Predictions" = spliceai_rules,
    "Specific Variants (HGVSc)" = specific_variants,
    "Special/Validation Rules" = special_rules
  )
  
  rule_analysis$inheritance <- list(
    "Autosomal Recessive (cThresh=2)" = ar_rules,
    "Dominant/Other (cThresh=1)" = dom_rules
  )
  
  rule_analysis$diseases <- list(
    "Total Diseases" = length(diseases),
    "Top 10 Diseases" = head(sort(disease_counts, decreasing = TRUE), 10)
  )
  
  # Extract genes from rules and count them
  # Genes are embedded in rules like "SYMBOL == GENE_NAME"
  gene_pattern <- "SYMBOL == ([A-Za-z0-9_-]+)"
  gene_matches <- regmatches(rules_data$RULE, regexpr(gene_pattern, rules_data$RULE))
  genes <- unique(gsub("SYMBOL == ", "", gene_matches))
  genes <- genes[genes != "character(0)" & !is.na(genes) & nchar(genes) > 0]
  
  rule_analysis$genes <- list(
    "Total Genes" = length(genes),
    "Top 10 Genes by Rule Count" = if(length(genes) > 0) {
      gene_counts <- table(gsub("SYMBOL == ", "", gene_matches))
      head(sort(gene_counts, decreasing = TRUE), 10)
    } else {
      NULL
    }
  )
  
  return(rule_analysis)
}

load_json_file <- function(filepath) {
  if (!file.exists(filepath)) return(NULL)
  tryCatch({
    fromJSON(filepath)
  }, error = function(e) {
    return(list(error = paste("Failed to load:", e$message)))
  })
}

load_missing_genes <- function(version_dir) {
  missing_genes_file <- file.path(version_dir, "analysis", "missing_genes.txt")
  if (!file.exists(missing_genes_file)) return(NULL)
  
  lines <- readLines(missing_genes_file)
  # Remove comment lines and empty lines
  genes <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  return(genes)
}

load_na_diseases <- function(version_dir) {
  na_diseases_file <- file.path(version_dir, "analysis", "na_diseases.txt")
  if (!file.exists(na_diseases_file)) return(NULL)
  
  lines <- readLines(na_diseases_file)
  # Remove comment lines and empty lines
  diseases <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  return(diseases)
}

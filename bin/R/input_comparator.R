# Input Comparator Module
# This module compares current inputs with previous versions to detect changes

# Source dependencies
if (!exists("logger")) {
  source(file.path(dirname(parent.frame(2)$ofile), "logger.R"))
}

#' Compare master gene lists between versions
#' @param current_gene_list Current gene list data frame
#' @param previous_gene_list Previous gene list data frame (can be NULL)
#' @param logger Logger instance
#' @return List containing comparison results
compare_gene_lists <- function(current_gene_list, previous_gene_list, logger) {
  log_info(logger, "Comparing gene lists...")
  
  if (is.null(previous_gene_list)) {
    log_info(logger, "No previous gene list available for comparison")
    return(list(
      added_genes = current_gene_list[, c("Disease", "Gene")],
      deleted_genes = NULL,
      modified_genes = NULL,
      unchanged_genes = NULL,
      total_added = nrow(current_gene_list),
      total_deleted = 0,
      total_modified = 0,
      total_unchanged = 0
    ))
  }
  
  # Create unique keys for comparison
  current_keys <- paste(current_gene_list[, "Disease"], current_gene_list[, "Gene"], sep = "_")
  previous_keys <- paste(previous_gene_list[, "Disease"], previous_gene_list[, "Gene"], sep = "_")
  
  # Find additions, deletions, and potential modifications
  added_keys <- setdiff(current_keys, previous_keys)
  deleted_keys <- setdiff(previous_keys, current_keys)
  common_keys <- intersect(current_keys, previous_keys)
  
  # Prepare results
  added_genes <- if (length(added_keys) > 0) {
    current_gene_list[current_keys %in% added_keys, c("Disease", "Gene")]
  } else {
    NULL
  }
  
  deleted_genes <- if (length(deleted_keys) > 0) {
    previous_gene_list[previous_keys %in% deleted_keys, c("Disease", "Gene")]
  } else {
    NULL
  }
  
  # Check for modifications in common genes
  modified_genes <- NULL
  if (length(common_keys) > 0) {
    modified_list <- list()
    for (key in common_keys) {
      current_row <- current_gene_list[current_keys == key, ]
      previous_row <- previous_gene_list[previous_keys == key, ]
      
      # Compare relevant columns
      comparison_cols <- c("Carrier", "Complex", "Variants.To.Find", "Inheritance")
      differences <- list()
      
      for (col in comparison_cols) {
        if (col %in% colnames(current_row) && col %in% colnames(previous_row)) {
          if (!identical(current_row[[col]], previous_row[[col]])) {
            differences[[col]] <- list(
              old = previous_row[[col]],
              new = current_row[[col]]
            )
          }
        }
      }
      
      if (length(differences) > 0) {
        modified_list[[key]] <- list(
          disease = current_row[["Disease"]],
          gene = current_row[["Gene"]],
          changes = differences
        )
      }
    }
    
    if (length(modified_list) > 0) {
      modified_genes <- modified_list
    }
  }
  
  unchanged_genes <- if (length(common_keys) > 0) {
    keys_modified <- if (!is.null(modified_genes)) names(modified_genes) else character(0)
    unchanged_keys <- setdiff(common_keys, keys_modified)
    if (length(unchanged_keys) > 0) {
      current_gene_list[current_keys %in% unchanged_keys, c("Disease", "Gene")]
    } else {
      NULL
    }
  } else {
    NULL
  }
  
  log_info(logger, paste("Gene list comparison results:"))
  log_info(logger, paste("  Added:", length(added_keys), "genes"))
  log_info(logger, paste("  Deleted:", length(deleted_keys), "genes"))
  log_info(logger, paste("  Modified:", length(modified_genes), "genes"))
  log_info(logger, paste("  Unchanged:", length(common_keys) - length(modified_genes), "genes"))
  
  return(list(
    added_genes = added_genes,
    deleted_genes = deleted_genes,
    modified_genes = modified_genes,
    unchanged_genes = unchanged_genes,
    total_added = length(added_keys),
    total_deleted = length(deleted_keys),
    total_modified = length(modified_genes),
    total_unchanged = length(common_keys) - length(modified_genes)
  ))
}

#' Compare variant lists between versions
#' @param current_variant_list Current variant list data frame
#' @param previous_variant_list Previous variant list data frame (can be NULL)
#' @param logger Logger instance
#' @return List containing comparison results
compare_variant_lists <- function(current_variant_list, previous_variant_list, logger) {
  log_info(logger, "Comparing variant lists...")
  
  if (is.null(previous_variant_list)) {
    log_info(logger, "No previous variant list available for comparison")
    return(list(
      added_variants = nrow(current_variant_list),
      deleted_variants = 0,
      modified_variants = 0,
      unchanged_variants = 0,
      total_changes = nrow(current_variant_list)
    ))
  }
  
  # Create unique keys for comparison (assuming variants have unique identifiers)
  # Use combination of gene and variant information
  current_keys <- paste(current_variant_list[, "Gene"], current_variant_list[, "Variant"], sep = "_")
  previous_keys <- paste(previous_variant_list[, "Gene"], previous_variant_list[, "Variant"], sep = "_")
  
  # Find additions and deletions
  added_keys <- setdiff(current_keys, previous_keys)
  deleted_keys <- setdiff(previous_keys, current_keys)
  common_keys <- intersect(current_keys, previous_keys)
  
  log_info(logger, paste("Variant list comparison results:"))
  log_info(logger, paste("  Added:", length(added_keys), "variants"))
  log_info(logger, paste("  Deleted:", length(deleted_keys), "variants"))
  log_info(logger, paste("  Unchanged:", length(common_keys), "variants"))
  
  return(list(
    added_variants = length(added_keys),
    deleted_variants = length(deleted_keys),
    modified_variants = 0,  # Not implemented for variants
    unchanged_variants = length(common_keys),
    total_changes = length(added_keys) + length(deleted_keys)
  ))
}

#' Compare configuration files between versions
#' @param current_config Current configuration object
#' @param previous_config Previous configuration object (can be NULL)
#' @param logger Logger instance
#' @return List containing comparison results
compare_configurations <- function(current_config, previous_config, logger) {
  log_info(logger, "Comparing configurations...")
  
  if (is.null(previous_config)) {
    log_info(logger, "No previous configuration available for comparison")
    return(list(
      settings_changes = 0,
      rules_changes = 0,
      special_cases_changes = 0,
      total_changes = 0
    ))
  }
  
  settings_changes <- 0
  rules_changes <- 0
  special_cases_changes <- 0
  
  # Compare settings
  if (!identical(current_config$settings, previous_config$settings)) {
    settings_changes <- 1
    log_info(logger, "Settings configuration has changed")
  }
  
  # Compare rules
  if (!identical(current_config$rules, previous_config$rules)) {
    rules_changes <- 1
    log_info(logger, "Rules configuration has changed")
  }
  
  # Compare special cases
  if (!identical(current_config$special_cases, previous_config$special_cases)) {
    special_cases_changes <- 1
    log_info(logger, "Special cases configuration has changed")
  }
  
  total_changes <- settings_changes + rules_changes + special_cases_changes
  
  log_info(logger, paste("Configuration comparison results:"))
  log_info(logger, paste("  Settings changes:", settings_changes))
  log_info(logger, paste("  Rules changes:", rules_changes))
  log_info(logger, paste("  Special cases changes:", special_cases_changes))
  log_info(logger, paste("  Total changes:", total_changes))
  
  return(list(
    settings_changes = settings_changes,
    rules_changes = rules_changes,
    special_cases_changes = special_cases_changes,
    total_changes = total_changes
  ))
}

# NOTE: load_previous_version function removed - all data loading now centralized in main pipeline
# Previous data is loaded in generate_rules_simplified.R and passed directly to compare_inputs

#' Main input comparison function
#' @param current_gene_list Current gene list data frame (already loaded and column-mapped)
#' @param current_variant_list Current variant list data frame (already loaded and column-mapped)
#' @param previous_gene_list Previous gene list data frame (already loaded and column-mapped, can be NULL)
#' @param previous_variant_list Previous variant list data frame (already loaded and column-mapped, can be NULL)
#' @param current_config Current configuration object
#' @param output_dir Output directory path (where versions are stored)
#' @param compare_with Previous version identifier
#' @param logger Logger instance
#' @return List containing comprehensive comparison results
compare_inputs <- function(current_gene_list, current_variant_list, previous_gene_list, previous_variant_list,
                          current_config, output_dir, compare_with, logger) {
  log_section(logger, "INPUT COMPARISON AND CHANGE ANALYSIS")
  
  log_info(logger, "Using pre-loaded and column-mapped data for both current and previous versions")
  
  # Compare gene lists using prepared data
  gene_comparison <- compare_gene_lists(
    current_gene_list, 
    previous_gene_list, 
    logger
  )
  
  # Compare variant lists using prepared data
  variant_comparison <- compare_variant_lists(
    current_variant_list, 
    previous_variant_list, 
    logger
  )
  
  # Compare configurations (for now, skip this as we don't have previous config loading in main pipeline)
  config_comparison <- list(
    settings_changes = 0,
    rules_changes = 0,
    special_cases_changes = 0,
    total_changes = 0
  )
  
  # Create comprehensive results
  results <- list(
    gene_comparison = gene_comparison,
    variant_comparison = variant_comparison,
    config_comparison = config_comparison,
    has_changes = (gene_comparison$total_added + gene_comparison$total_deleted + 
                   gene_comparison$total_modified + variant_comparison$total_changes + 
                   config_comparison$total_changes) > 0,
    comparison_timestamp = Sys.time(),
    compared_with = compare_with
  )
  
  # Save comparison results
  save_comparison_results(results, output_dir, logger)
  
  # Log summary
  log_info(logger, "Input comparison completed using prepared data")
  log_stats(logger, list(
    "Total gene changes" = gene_comparison$total_added + gene_comparison$total_deleted + gene_comparison$total_modified,
    "Total variant changes" = variant_comparison$total_changes,
    "Total config changes" = config_comparison$total_changes,
    "Has changes" = results$has_changes
  ))
  
  return(results)
}

#' Save comparison results to analysis directory
#' @param results Comparison results object
#' @param output_dir Output directory path
#' @param logger Logger instance
save_comparison_results <- function(results, output_dir, logger) {
  analysis_dir <- file.path(output_dir, "analysis", "input_comparison")
  dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Save as JSON for easy reading
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  results_file <- file.path(analysis_dir, paste0("input_comparison_", timestamp, ".json"))
  
  tryCatch({
    jsonlite::write_json(results, results_file, pretty = TRUE)
    log_info(logger, paste("Comparison results saved to:", results_file))
  }, error = function(e) {
    log_warning(logger, paste("Failed to save comparison results:", e$message))
  })
} 
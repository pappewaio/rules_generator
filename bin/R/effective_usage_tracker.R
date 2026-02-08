# Effective Usage Tracker Module
# This module tracks which variants from the supplemental list are actually used
# in rule generation, independent of raw input file changes

#' Track which variants are effectively used in rule generation
#' @param gene_list Current gene list data frame  
#' @param variant_list_data Current variant list data frame
#' @param logger Logger instance
#' @return List containing effective usage analysis
track_effective_variant_usage <- function(gene_list, variant_list_data, logger) {
  log_info(logger, "Analyzing effective variant usage...")
  
  # Find genes that use supplemental variant list
  supplemental_genes <- gene_list[gene_list[, "Variants.To.Find"] == "See supplemental variant list", "Gene"]
  
  # Find variants that would actually be used in rule generation
  used_variants <- variant_list_data[variant_list_data[, "Gene"] %in% supplemental_genes, ]
  
  # Track by gene
  usage_by_gene <- list()
  for (gene in supplemental_genes) {
    gene_variants <- variant_list_data[variant_list_data[, "Gene"] == gene, ]
    usage_by_gene[[gene]] <- list(
      disease_count = length(unique(gene_list[gene_list[, "Gene"] == gene, "Disease"])),
      variant_count = nrow(gene_variants),
      variants = if(nrow(gene_variants) > 0) gene_variants[, "Variant"] else character(0)
    )
  }
  
  log_info(logger, paste("Found", length(supplemental_genes), "genes using supplemental variant list"))
  log_info(logger, paste("These would use", nrow(used_variants), "variants from supplemental list"))
  
  return(list(
    total_supplemental_genes = length(supplemental_genes),
    supplemental_genes = supplemental_genes,
    total_used_variants = nrow(used_variants),
    used_variants = used_variants,
    usage_by_gene = usage_by_gene,
    analysis_timestamp = Sys.time()
  ))
}

#' Compare effective variant usage between versions
#' @param current_usage Current effective usage analysis
#' @param previous_usage Previous effective usage analysis (can be NULL)
#' @param logger Logger instance
#' @return List containing usage comparison results
compare_effective_usage <- function(current_usage, previous_usage, logger) {
  log_info(logger, "Comparing effective variant usage between versions...")
  
  if (is.null(previous_usage)) {
    log_info(logger, "No previous effective usage data available for comparison")
    return(list(
      current_supplemental_genes = current_usage$total_supplemental_genes,
      current_used_variants = current_usage$total_used_variants,
      previous_supplemental_genes = 0,
      previous_used_variants = 0,
      gene_changes = list(
        added_genes = current_usage$supplemental_genes,
        removed_genes = character(0),
        unchanged_genes = character(0)
      ),
      variant_changes = list(
        net_change = current_usage$total_used_variants,
        added_variants = current_usage$total_used_variants,
        removed_variants = 0
      )
    ))
  }
  
  # Compare supplemental genes
  current_genes <- current_usage$supplemental_genes
  previous_genes <- previous_usage$supplemental_genes
  
  added_genes <- setdiff(current_genes, previous_genes)
  removed_genes <- setdiff(previous_genes, current_genes)
  unchanged_genes <- intersect(current_genes, previous_genes)
  
  # Compare variant counts by tracking which variants would be used
  current_used_keys <- paste(current_usage$used_variants[, "Gene"], current_usage$used_variants[, "Variant"], sep = "_")
  previous_used_keys <- paste(previous_usage$used_variants[, "Gene"], previous_usage$used_variants[, "Variant"], sep = "_")
  
  added_variant_keys <- setdiff(current_used_keys, previous_used_keys)
  removed_variant_keys <- setdiff(previous_used_keys, current_used_keys)
  
  log_info(logger, paste("Effective usage comparison results:"))
  log_info(logger, paste("  Supplemental genes - Added:", length(added_genes), "Removed:", length(removed_genes)))
  log_info(logger, paste("  Effectively used variants - Added:", length(added_variant_keys), "Removed:", length(removed_variant_keys)))
  
  return(list(
    current_supplemental_genes = current_usage$total_supplemental_genes,
    current_used_variants = current_usage$total_used_variants,
    previous_supplemental_genes = previous_usage$total_supplemental_genes,
    previous_used_variants = previous_usage$total_used_variants,
    gene_changes = list(
      added_genes = added_genes,
      removed_genes = removed_genes,
      unchanged_genes = unchanged_genes
    ),
    variant_changes = list(
      net_change = current_usage$total_used_variants - previous_usage$total_used_variants,
      added_variants = length(added_variant_keys),
      removed_variants = length(removed_variant_keys)
    )
  ))
}

#' Load previous effective usage data
#' @param output_dir Output directory path
#' @param compare_with Previous version identifier
#' @param logger Logger instance
#' @return Previous effective usage data or NULL
load_previous_effective_usage <- function(output_dir, compare_with, logger) {
  previous_path <- file.path(output_dir, compare_with, "analysis", "effective_usage.json")
  
  if (!file.exists(previous_path)) {
    log_info(logger, paste("No previous effective usage data found at:", previous_path))
    return(NULL)
  }
  
  tryCatch({
    previous_data <- jsonlite::fromJSON(previous_path, simplifyDataFrame = TRUE)
    log_info(logger, paste("Loaded previous effective usage data from:", previous_path))
    return(previous_data)
  }, error = function(e) {
    log_warning(logger, paste("Failed to load previous effective usage data:", e$message))
    return(NULL)
  })
}

#' Save effective usage analysis
#' @param usage_data Effective usage analysis data
#' @param comparison_data Usage comparison data (can be NULL)
#' @param output_dir Output directory path
#' @param logger Logger instance
save_effective_usage <- function(usage_data, comparison_data, output_dir, logger) {
  analysis_dir <- file.path(output_dir, "analysis")
  dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Save usage analysis
  usage_file <- file.path(analysis_dir, "effective_usage.json")
  tryCatch({
    jsonlite::write_json(usage_data, usage_file, pretty = TRUE)
    log_info(logger, paste("Effective usage analysis saved to:", usage_file))
  }, error = function(e) {
    log_error(logger, paste("Failed to save effective usage analysis:", e$message))
  })
  
  # Save comparison if available
  if (!is.null(comparison_data)) {
    comparison_file <- file.path(analysis_dir, "effective_usage_comparison.json")
    tryCatch({
      jsonlite::write_json(comparison_data, comparison_file, pretty = TRUE)
      log_info(logger, paste("Effective usage comparison saved to:", comparison_file))
    }, error = function(e) {
      log_error(logger, paste("Failed to save effective usage comparison:", e$message))
    })
  }
} 
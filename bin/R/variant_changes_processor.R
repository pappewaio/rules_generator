#' Variant Changes Processor
#' 
#' This module processes variant changes data to generate specific variant rules
#' following the same patterns as the manual script logic.
#' 
#' @author Generated following manual script patterns

#' Parse variant name into genomic coordinates
#' 
#' Converts variant names like "chr16_2046238_G_A" into chromosome and position
#' following the same logic as the manual script.
#' 
#' @param variant_name String like "chr16_2046238_G_A"
#' @return List with chrom, pos, ref, alt components, or NULL if parsing fails
parse_variant_name <- function(variant_name) {
  
  # Handle missing or empty variant names
  if (is.na(variant_name) || variant_name == "" || is.null(variant_name)) {
    return(NULL)
  }
  
  # Split by underscore (following manual script pattern)
  tryCatch({
    parts <- strsplit(variant_name, "_")[[1]]
    
    # Need at least 4 parts: chr, pos, ref, alt
    if (length(parts) < 4) {
      return(NULL)
    }
    
    # Extract components
    chrom <- parts[1]  # e.g., "chr16"
    pos <- as.numeric(parts[2])  # e.g., 2046238
    ref <- parts[3]  # e.g., "G"
    alt <- parts[4]  # e.g., "A"
    
    # Validate that position is numeric
    if (is.na(pos)) {
      return(NULL)
    }
    
    return(list(
      chrom = chrom,
      pos = pos,
      ref = ref,
      alt = alt,
      original = variant_name
    ))
    
  }, error = function(e) {
    return(NULL)
  })
}

#' Generate specific variant rules from variant changes data
#' 
#' This function follows the same logic as the manual script for processing
#' variant changes and generating specific variant rules.
#' 
#' @param variant_changes_data Data from load_variant_changes_data()
#' @param gene_name Gene to process (e.g., "NTHL1")  
#' @param disease_name Disease to process (e.g., "NTHL1-deficiency_tumor_predisposition_syndrome")
#' @return Character vector of specific variant rules
process_variant_changes <- function(variant_changes_data, gene_name, disease_name) {
  
  # Return empty if no data
  if (is.null(variant_changes_data) || is.null(variant_changes_data$raw_data)) {
    return(character(0))
  }
  
  # Filter for this gene and disease (following manual script logic)
  variant_data <- variant_changes_data$raw_data
  
  # Filter by gene and disease
  matching_rows <- variant_data[
    variant_data$genes == gene_name & 
    variant_data$ReportScienceID == disease_name,
  ]
  
  if (nrow(matching_rows) == 0) {
    return(character(0))
  }
  
  # Process each variant to generate rules
  specific_rules <- character(0)
  
  for (i in 1:nrow(matching_rows)) {
    row <- matching_rows[i, ]
    variant_name <- row$VariantName
    
    # Parse the variant name
    parsed <- parse_variant_name(variant_name)
    
    if (!is.null(parsed)) {
      # Generate specific variant rule (following manual script pattern)
      # Format: CHROM == chr16 && POS == 2046238
      rule <- paste0("CHROM == ", parsed$chrom, " && POS == ", parsed$pos)
      specific_rules <- c(specific_rules, rule)
    }
  }
  
  # Remove duplicates (same variant might appear multiple times)
  specific_rules <- unique(specific_rules)
  
  return(specific_rules)
}

#' Test function to validate variant changes processing
#' 
#' This function can be called independently to test the processing
#' without running the entire framework.
#' 
#' @param config_dir Configuration directory to test
test_variant_changes_processing <- function(config_dir) {
  cat("=== Testing Variant Changes Processing ===\n")
  
  # Load config and data
  source("variant_changes_config_loader.R")
  config <- load_variant_changes_config(config_dir)
  data <- load_variant_changes_data(config)
  
  if (is.null(data)) {
    cat("No variant changes data available\n")
    return(NULL)
  }
  
  cat("Total variant changes rows:", data$row_count, "\n")
  
  # Test parsing a few variant names
  cat("\n--- Testing Variant Name Parsing ---\n")
  sample_variants <- head(data$raw_data$VariantName, 5)
  for (variant in sample_variants) {
    parsed <- parse_variant_name(variant)
    if (!is.null(parsed)) {
      cat("✅", variant, "->", parsed$chrom, "pos:", parsed$pos, "\n")
    } else {
      cat("❌", variant, "-> parsing failed\n")
    }
  }
  
  # Test processing for a specific gene/disease
  cat("\n--- Testing Rule Generation ---\n")
  sample_genes <- unique(data$raw_data$genes)[1:3]
  
  for (gene in sample_genes) {
    # Get diseases for this gene
    gene_rows <- data$raw_data[data$raw_data$genes == gene, ]
    diseases <- unique(gene_rows$ReportScienceID)
    
    for (disease in diseases[1]) {  # Test first disease only
      rules <- process_variant_changes(data, gene, disease)
      cat("Gene:", gene, "Disease:", disease, "Rules:", length(rules), "\n")
      if (length(rules) > 0) {
        cat("  Sample rule:", rules[1], "\n")
      }
    }
  }
  
  cat("=== Test Complete ===\n")
  return(data)
}

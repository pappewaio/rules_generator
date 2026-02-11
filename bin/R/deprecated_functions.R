# Deprecated Functions
#
# These functions were replaced by inlined logic in the main generate_rules()
# loop during the vectorization work (2026-02-11). They are kept here for
# reference but are not sourced or called anywhere.
#
# See docs/dead-code.md for details on why each function is dead.

# =====================================================================
# From rule_generator.R - replaced by inlined main loop (lines 930-1012)
# =====================================================================

#' Generate rules for a single gene (DEPRECATED)
#'
#' Dispatcher that routed to generate_ptv_only_rules, generate_clinvar_rules,
#' etc. based on Variants.To.Find. Logic is now inlined in generate_rules().
#'
#' @param gene_info Single-row data frame with gene information
#' @param cutoff_list Cutoff list for exclusion zones
#' @param variant_list_data Variant list data
#' @param config Configuration object
#' @param cID Current compound ID
#' @param cCond Compound condition (">=" typically)
#' @param cThresh Compound threshold (1 or 2 based on inheritance)
#' @param logger Logger instance
#' @return List of rule strings
generate_gene_rules <- function(gene_info, cutoff_list, variant_list_data, config, cID, cCond, cThresh, logger) {
  gene <- gene_info[["Gene"]]
  disease_name <- gene_info[["Disease"]]
  inheritance <- gene_info[["Inheritance"]]
  variants_to_find <- gene_info[["Variants.To.Find"]]
  
  # Create base gene rule
  gene_rule <- paste0("SYMBOL == ", gene, " ")
  
  # Create compound heterozygote rule (using passed inheritance values)
  inheritance_rule <- paste(cID, cCond, cThresh, sep = "\t")
  
  # Get rule templates from config
  frequency_rule <- config$rules$frequency_rules[1]
  frequency_rule <- gsub("\\{FORMAT_GQ_THRESHOLD\\}", config$settings$FORMAT_GQ_THRESHOLD, frequency_rule)
  
  # Generate rules based on variants to find
  if (variants_to_find == "PTV only") {
    strings <- generate_ptv_only_rules(gene_rule, disease_name, gene, cutoff_list, frequency_rule, inheritance_rule, config)
    
  } else if (variants_to_find == "Clinvar P and LP") {
    strings <- generate_clinvar_rules(gene_rule, disease_name, frequency_rule, inheritance_rule, config)
    
  } else if (variants_to_find == "See supplemental variant list") {
    strings <- generate_supplemental_rules(gene_rule, disease_name, gene, variant_list_data, frequency_rule, inheritance_rule, config$special_cases$clinvar_benign_genes, logger)
    
  } else if (tolower(variants_to_find) == "missense and nonsense") {
    strings <- generate_missense_nonsense_rules(gene_rule, disease_name, gene, cutoff_list, frequency_rule, inheritance_rule, config)
    
  } else if (variants_to_find == "Special") {
    strings <- generate_special_rules(gene_rule, disease_name, gene, cutoff_list, frequency_rule, cID, config)
    
  } else {
    log_warning(logger, paste("Unsupported Variants-to-find logic for gene", gene, "disease", disease_name, ":", variants_to_find))
    return(list())
  }
  
  # Note: homozygous rules will be handled in main loop if needed
  
  return(strings)
}

#' Generate PTV only rules (DEPRECATED - inlined in main loop)
#' @param gene_rule Base gene rule
#' @param disease_name Disease name
#' @param gene Gene symbol
#' @param cutoff_list Cutoff list
#' @param frequency_rule Frequency rule
#' @param inheritance_rule Inheritance rule
#' @param config Configuration object
#' @return Vector of rule strings
generate_ptv_only_rules <- function(gene_rule, disease_name, gene, cutoff_list, frequency_rule, inheritance_rule, config) {
  exclusion_zone_rule <- exclusion_rule_function(gene, cutoff_list)
  
  # Simple PTV rules
  ptv_rules <- c(
    " && Consequence == frameshift_variant",
    " && Consequence == stop_gained"
  )
  
  strings <- paste(disease_name, paste0(gene_rule, ptv_rules, exclusion_zone_rule, frequency_rule), inheritance_rule, sep = "\t")
  return(strings)
}

#' Generate ClinVar pathogenic/likely pathogenic rules (DEPRECATED - inlined in main loop)
#' @param gene_rule Base gene rule
#' @param disease_name Disease name
#' @param frequency_rule Frequency rule
#' @param inheritance_rule Inheritance rule
#' @param config Configuration object
#' @return Vector of rule strings
generate_clinvar_rules <- function(gene_rule, disease_name, frequency_rule, inheritance_rule, config) {
  clinvar_rules <- config$rules$clinvar_rules
  strings <- paste(disease_name, paste0(gene_rule, clinvar_rules, frequency_rule), inheritance_rule, sep = "\t")
  return(strings)
}

#' Generate supplemental variant list rules (DEPRECATED - inlined in main loop)
#' @param gene_rule Base gene rule
#' @param disease_name Disease name
#' @param gene Gene symbol
#' @param variant_list_data Variant list data
#' @param frequency_rule Frequency rule
#' @param inheritance_rule Inheritance rule
#' @param clinvar_benign_genes ClinVar benign exclusion genes from configuration
#' @param logger Logger instance
#' @return Vector of rule strings
generate_supplemental_rules <- function(gene_rule, disease_name, gene, variant_list_data, frequency_rule, inheritance_rule, clinvar_benign_genes, logger) {
  # Check if ClinVar benign should be excluded using configuration
  if (gene %in% clinvar_benign_genes) {
    clinvar_benign_rule <- " && ClinVar_CLNSIG != Benign && ClinVar_CLNSIG != Likely_benign && ClinVar_CLNSIG != Benign/Likely_benign && ClinVar_CLNSIG != Conflicting_interpretations_of_pathogenicity && ClinVar_CLNSIG != Uncertain_significance"
  } else {
    clinvar_benign_rule <- ""
  }
  
  # Find variants for this gene
  gene_variants <- variant_list_data[gsub(" ", "", variant_list_data$Gene) == gene, ]
  
  if (nrow(gene_variants) == 0) {
    log_warning(logger, paste("Did not find gene in supplemental list for", gene, "- completely skipping this gene. Should report"))
    return(list())
  }
  
  # Process variants
  specific_variant_rules <- process_supplemental_variants(gene_variants, logger)
  
  strings <- paste(disease_name, paste0(gene_rule, specific_variant_rules, frequency_rule, clinvar_benign_rule), inheritance_rule, sep = "\t")
  return(strings)
}

#' Generate missense and nonsense rules (DEPRECATED - inlined in main loop)
#' @param gene_rule Base gene rule
#' @param disease_name Disease name
#' @param gene Gene symbol
#' @param cutoff_list Cutoff list
#' @param frequency_rule Frequency rule
#' @param inheritance_rule Inheritance rule
#' @param config Configuration object
#' @return Vector of rule strings
generate_missense_nonsense_rules <- function(gene_rule, disease_name, gene, cutoff_list, frequency_rule, inheritance_rule, config) {
  exclusion_zone_rule <- exclusion_rule_function(gene, cutoff_list)
  spliceai_gene_rule <- paste0("SpliceAI_pred_SYMBOL == ", gene)
  
  # Generate all three rule categories
  strings_1 <- paste(disease_name, paste0(gene_rule, config$rules$non_splice_pos_rules, exclusion_zone_rule, frequency_rule), inheritance_rule, sep = "\t")
  strings_2 <- paste(disease_name, paste0(gene_rule, config$rules$non_splice_rules, frequency_rule), inheritance_rule, sep = "\t")
  strings_3 <- paste(disease_name, paste0(spliceai_gene_rule, config$rules$spliceai_rules, frequency_rule), inheritance_rule, sep = "\t")
  
  # Apply position exclusions from configuration
  position_exclusions <- config$special_cases$position_exclusions
  for (i in 1:nrow(position_exclusions)) {
    exclusion_gene <- position_exclusions[i, "gene"]
    rule_pattern <- position_exclusions[i, "rule_pattern"]
    exclusion_conditions <- position_exclusions[i, "exclusion_conditions"]
    
    if (gene == exclusion_gene) {
      # Find matching rules and apply exclusions
      if (grepl("SpliceAI", rule_pattern)) {
        matching_rules <- grep(rule_pattern, strings_3, fixed = TRUE)
        if (length(matching_rules) > 0) {
          strings_3[matching_rules] <- sub(paste0("format_GQ >= ", config$settings$FORMAT_GQ_THRESHOLD), 
                                           paste0("format_GQ >= ", config$settings$FORMAT_GQ_THRESHOLD, " ", exclusion_conditions), 
                                           strings_3[matching_rules])
        }
      } else {
        matching_rules <- grep(rule_pattern, strings_2, fixed = TRUE)
        if (length(matching_rules) > 0) {
          strings_2[matching_rules] <- sub(paste0("format_GQ >= ", config$settings$FORMAT_GQ_THRESHOLD), 
                                           paste0("format_GQ >= ", config$settings$FORMAT_GQ_THRESHOLD, " ", exclusion_conditions), 
                                           strings_2[matching_rules])
        }
      }
    }
  }
  
  return(c(strings_1, strings_2, strings_3))
}

# =====================================================================
# From generate_rules_utils.R - never called
# =====================================================================

#' Get script directory in a robust way (DEPRECATED - never called)
#'
#' generate_rules_simplified.R has its own inline version (lines 7-19).
#'
#' @return Path to the directory containing the script
get_script_dir <- function() {
  if (interactive()) {
    return(getwd())
  } else {
    # Try different methods to get script path
    script_path <- NULL
    
    # Method 1: try sys.frame (works when called from source)
    tryCatch({
      script_path <- sys.frame(1)$ofile
    }, error = function(e) {})
    
    # Method 2: try commandArgs (works when run with Rscript)
    if (is.null(script_path)) {
      tryCatch({
        args <- commandArgs(trailingOnly = FALSE)
        script_path <- sub("--file=", "", args[grep("--file=", args)])
      }, error = function(e) {})
    }
    
    # Method 3: fallback to current directory
    if (is.null(script_path) || length(script_path) == 0) {
      script_path <- "generate_rules.R"
    }
    
    return(dirname(script_path))
  }
}

# Rules Analysis Comparator
# 
# This module provides functions for comparing current and previous rules analysis results,
# generating detailed comparison tables and impact analysis.
#
# Functions:
# - compare_rule_types(): Compare rule type distributions between versions
# - compare_inheritance_patterns(): Compare inheritance pattern distributions with detailed analysis  
# - analyze_disease_level_changes(): Identify specific diseases with rule count changes

library(knitr)

#' Compare rule types between current and previous analysis
#' @param current_analysis Current rules analysis results
#' @param previous_analysis Previous rules analysis results (optional)
#' @return List containing dataframe and analysis text
compare_rule_types <- function(current_analysis, previous_analysis = NULL) {
  
  # Helper function for number formatting (assume this exists in parent scope)
  format_number <- function(x) {
    if (is.null(x) || is.na(x)) return("0")
    formatC(as.numeric(x), format = "d", big.mark = ",")
  }
  
  rule_type_names <- names(current_analysis$rule_types)
  current_counts <- unlist(current_analysis$rule_types)
  
  # Get previous counts if available
  previous_counts <- rep(0, length(rule_type_names))
  if (!is.null(previous_analysis) && !is.null(previous_analysis$rule_types)) {
    for (i in seq_along(rule_type_names)) {
      rule_name <- rule_type_names[i]
      if (rule_name %in% names(previous_analysis$rule_types)) {
        previous_counts[i] <- previous_analysis$rule_types[[rule_name]]
      }
    }
  }
  
  # Calculate changes
  changes <- current_counts - previous_counts
  
  # Add totals row
  total_previous <- sum(previous_counts)
  total_current <- sum(current_counts)
  total_change <- total_current - total_previous
  
  rule_types_df <- data.frame(
    "Rule Type" = c(rule_type_names, "**TOTAL**"),
    "Previous" = c(sapply(previous_counts, format_number), format_number(total_previous)),
    "Current" = c(sapply(current_counts, format_number), format_number(total_current)),
    "Change" = c(sapply(changes, function(x) {
      if (x == 0) "0"
      else if (x > 0) paste0("+", format_number(x))
      else format_number(x)
    }), if (total_change == 0) "0" else if (total_change > 0) paste0("+", format_number(total_change)) else format_number(total_change)),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    row.names = NULL
  )
  
  # Generate analysis text
  analysis_text <- character()
  if (total_change != 0 && !is.null(previous_analysis)) {
    analysis_text <- c(analysis_text, "**Rule Type Changes Analysis:**")
    
    # Find categories with changes
    changed_categories <- rule_type_names[changes != 0]
    if (length(changed_categories) > 0) {
      for (category in changed_categories) {
        change_val <- changes[rule_type_names == category]
        change_text <- if (change_val > 0) paste0("+", format_number(change_val)) else format_number(change_val)
        analysis_text <- c(analysis_text, paste0("- **", category, ":** ", change_text, " rules"))
      }
    } else {
      analysis_text <- c(analysis_text, "- No changes detected in individual rule types")
    }
  }
  
  return(list(
    table_df = rule_types_df,
    analysis_text = analysis_text
  ))
}

#' Compare inheritance patterns between current and previous analysis
#' @param current_analysis Current rules analysis results
#' @param previous_analysis Previous rules analysis results (optional)
#' @param version_dir Current version directory path
#' @param compare_with Previous version identifier
#' @return List containing dataframe and analysis text
compare_inheritance_patterns <- function(current_analysis, previous_analysis = NULL, version_dir = NULL, compare_with = NULL) {
  
  # Helper function for number formatting
  format_number <- function(x) {
    if (is.null(x) || is.na(x)) return("0")
    formatC(as.numeric(x), format = "d", big.mark = ",")
  }
  
  inheritance_names <- names(current_analysis$inheritance)
  current_inheritance_counts <- unlist(current_analysis$inheritance)
  
  # Get previous inheritance counts if available
  previous_inheritance_counts <- rep(0, length(inheritance_names))
  if (!is.null(previous_analysis) && !is.null(previous_analysis$inheritance)) {
    for (i in seq_along(inheritance_names)) {
      inheritance_name <- inheritance_names[i]
      if (inheritance_name %in% names(previous_analysis$inheritance)) {
        previous_inheritance_counts[i] <- previous_analysis$inheritance[[inheritance_name]]
      }
    }
  }
  
  # Calculate changes
  inheritance_changes <- current_inheritance_counts - previous_inheritance_counts
  
  # Add totals row
  inheritance_total_previous <- sum(previous_inheritance_counts)
  inheritance_total_current <- sum(current_inheritance_counts)
  inheritance_total_change <- inheritance_total_current - inheritance_total_previous
  
  inheritance_df <- data.frame(
    "Inheritance Type" = c(inheritance_names, "**TOTAL**"),
    "Previous" = c(sapply(previous_inheritance_counts, format_number), format_number(inheritance_total_previous)),
    "Current" = c(sapply(current_inheritance_counts, format_number), format_number(inheritance_total_current)),
    "Change" = c(sapply(inheritance_changes, function(x) {
      if (x == 0) "0"
      else if (x > 0) paste0("+", format_number(x))
      else format_number(x)
    }), if (inheritance_total_change == 0) "0" else if (inheritance_total_change > 0) paste0("+", format_number(inheritance_total_change)) else format_number(inheritance_total_change)),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    row.names = NULL
  )
  
  # Generate analysis text
  analysis_text <- character()
  if (inheritance_total_change != 0 && !is.null(previous_analysis)) {
    analysis_text <- c(analysis_text, "**Inheritance Pattern Changes Analysis:**")
    
    # Find inheritance patterns with changes
    changed_inheritance <- inheritance_names[inheritance_changes != 0]
    if (length(changed_inheritance) > 0) {
      for (pattern in changed_inheritance) {
        change_val <- inheritance_changes[inheritance_names == pattern]
        change_text <- if (change_val > 0) paste0("+", format_number(change_val)) else format_number(change_val)
        analysis_text <- c(analysis_text, paste0("- **", pattern, ":** ", change_text, " rules"))
      }
      
      # Add detailed analysis for significant changes
      if (any(abs(inheritance_changes) > 10)) {
        analysis_text <- c(analysis_text, "")
        analysis_text <- c(analysis_text, "**Detailed Impact Analysis:**")
        
        if (!is.null(compare_with)) {
          analysis_text <- c(analysis_text, paste0("- Changes detected between ", compare_with, " and ", basename(version_dir)))
          analysis_text <- c(analysis_text, "- This suggests code changes affecting rule generation logic")
          analysis_text <- c(analysis_text, "- Most likely causes: modified inheritance pattern assignments, rule filtering, or ID generation changes")
          
          # Generate TSV files for detailed analysis
          tsv_info <- generate_detailed_tsv_files(version_dir, compare_with)
          if (!is.null(tsv_info)) {
            analysis_text <- c(analysis_text, tsv_info$summary_text)
          }
        }
      }
    } else {
      analysis_text <- c(analysis_text, "- No changes detected in inheritance pattern distribution")
    }
  }
  
  return(list(
    table_df = inheritance_df,
    analysis_text = analysis_text
  ))
}

#' Analyze disease-level changes between versions
#' @param version_dir Current version directory path
#' @param compare_with Previous version identifier
#' @return Character vector with disease analysis text
analyze_disease_level_changes <- function(version_dir, compare_with) {
  
  analysis_text <- character()
  
  tryCatch({
    current_rules_file <- file.path(version_dir, "outputs")
    current_rules_files <- list.files(current_rules_file, pattern = ".*rules_file.*\\.tsv$", full.names = TRUE)
    previous_version_dir <- file.path(dirname(version_dir), compare_with)
    previous_rules_file <- file.path(previous_version_dir, "outputs")
    previous_rules_files <- list.files(previous_rules_file, pattern = ".*rules_file.*\\.tsv$", full.names = TRUE)
    
    if (length(current_rules_files) > 0 && length(previous_rules_files) > 0) {
      # Read and compare disease counts
      current_rules <- read.table(current_rules_files[1], sep = "\t", header = TRUE, stringsAsFactors = FALSE, quote = "")
      previous_rules <- read.table(previous_rules_files[1], sep = "\t", header = TRUE, stringsAsFactors = FALSE, quote = "")
      
      current_disease_counts <- table(current_rules$Disease_report)
      previous_disease_counts <- table(previous_rules$Disease_report)
      
      # Find diseases with different counts
      all_diseases <- unique(c(names(current_disease_counts), names(previous_disease_counts)))
      disease_diffs <- sapply(all_diseases, function(d) {
        curr <- if (d %in% names(current_disease_counts)) current_disease_counts[[d]] else 0
        prev <- if (d %in% names(previous_disease_counts)) previous_disease_counts[[d]] else 0
        curr - prev
      })
      
      changed_diseases <- names(disease_diffs)[disease_diffs != 0]
      if (length(changed_diseases) > 0) {
        analysis_text <- c(analysis_text, "")
        analysis_text <- c(analysis_text, "**Diseases with Rule Count Changes:**")
        
        # Sort by absolute change magnitude
        changed_diseases <- changed_diseases[order(abs(disease_diffs[changed_diseases]), decreasing = TRUE)]
        
        # Show top 10 diseases with changes
        top_changes <- head(changed_diseases, 10)
        for (disease in top_changes) {
          change_val <- disease_diffs[[disease]]
          change_text <- if (change_val > 0) paste0("+", change_val) else as.character(change_val)
          analysis_text <- c(analysis_text, paste0("- **", disease, ":** ", change_text, " rules"))
        }
        
        if (length(changed_diseases) > 10) {
          analysis_text <- c(analysis_text, paste0("- ... and ", length(changed_diseases) - 10, " other diseases with changes"))
        }
      }
    }
  }, error = function(e) {
    analysis_text <<- c(analysis_text, paste0("- Disease-level analysis failed: ", e$message))
  })
  
  return(analysis_text)
}# Generate detailed TSV files and return summary information
generate_detailed_tsv_files <- function(version_dir, compare_with) {
  tryCatch({
    # Read current and previous rules files
    current_outputs_dir <- file.path(version_dir, "outputs")
    
    if (!dir.exists(current_outputs_dir)) {
      return(NULL)
    }
    
    current_rules_files <- list.files(current_outputs_dir, pattern = "rules_file.*\\.tsv$", full.names = TRUE)
    
    if (length(current_rules_files) == 0) {
      return(NULL)
    }
    
    current_rules_file <- current_rules_files[1]
    
    previous_version_dir <- file.path(dirname(version_dir), compare_with)
    previous_outputs_dir <- file.path(previous_version_dir, "outputs")
    
    if (!dir.exists(previous_outputs_dir)) {
      return(NULL)
    }
    
    previous_rules_files <- list.files(previous_outputs_dir, pattern = "rules_file.*\\.tsv$", full.names = TRUE)
    
    if (length(previous_rules_files) == 0) {
      return(NULL)
    }
    
    previous_rules_file <- previous_rules_files[1]
    
    if (!file.exists(current_rules_file) || !file.exists(previous_rules_file)) {
      return(NULL)
    }
    
    # Read rules data
    current_rules <- read.table(current_rules_file, sep = "\t", header = TRUE, stringsAsFactors = FALSE, quote = "")
    previous_rules <- read.table(previous_rules_file, sep = "\t", header = TRUE, stringsAsFactors = FALSE, quote = "")
    
    # Analyze disease-level changes
    current_disease_counts <- table(current_rules$Disease_report)
    previous_disease_counts <- table(previous_rules$Disease_report)
    
    # Get all diseases
    all_diseases <- unique(c(names(current_disease_counts), names(previous_disease_counts)))
    
    # Create disease comparison data
    disease_changes <- data.frame(
      Disease = all_diseases,
      Previous_Rules = sapply(all_diseases, function(d) ifelse(d %in% names(previous_disease_counts), previous_disease_counts[d], 0)),
      Current_Rules = sapply(all_diseases, function(d) ifelse(d %in% names(current_disease_counts), current_disease_counts[d], 0)),
      stringsAsFactors = FALSE
    )
    disease_changes$Change <- disease_changes$Current_Rules - disease_changes$Previous_Rules
    disease_changes <- disease_changes[disease_changes$Change != 0, ]
    disease_changes <- disease_changes[order(disease_changes$Change), ]
    
    # Analyze gene-level changes (extract from RULE column)
    extract_genes <- function(rules_df) {
      gene_pattern <- "SYMBOL == ([A-Za-z0-9_.-]+)"
      genes <- regmatches(rules_df$RULE, regexpr(gene_pattern, rules_df$RULE))
      genes <- gsub("SYMBOL == ", "", genes)
      genes[genes == ""] <- "UNKNOWN"
      return(genes)
    }
    
    current_genes <- extract_genes(current_rules)
    previous_genes <- extract_genes(previous_rules)
    
    current_gene_counts <- table(current_genes)
    previous_gene_counts <- table(previous_genes)
    
    all_genes <- unique(c(names(current_gene_counts), names(previous_gene_counts)))
    
    gene_changes <- data.frame(
      Gene = all_genes,
      Previous_Rules = sapply(all_genes, function(g) ifelse(g %in% names(previous_gene_counts), previous_gene_counts[g], 0)),
      Current_Rules = sapply(all_genes, function(g) ifelse(g %in% names(current_gene_counts), current_gene_counts[g], 0)),
      stringsAsFactors = FALSE
    )
    gene_changes$Change <- gene_changes$Current_Rules - gene_changes$Previous_Rules
    gene_changes <- gene_changes[gene_changes$Change != 0, ]
    gene_changes <- gene_changes[order(gene_changes$Change), ]
    
    # Create output directory
    analysis_dir <- file.path(version_dir, "analysis", "rule_changes")
    dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
    
    # Write TSV files
    disease_file <- file.path(analysis_dir, "disease_rule_changes.tsv")
    gene_file <- file.path(analysis_dir, "gene_rule_changes.tsv")
    
    write.table(disease_changes, disease_file, sep = "\t", row.names = FALSE, quote = FALSE)
    write.table(gene_changes, gene_file, sep = "\t", row.names = FALSE, quote = FALSE)
    
    # Generate summary text
    summary_text <- c(
      "",
      paste0("**Summary:** ", nrow(disease_changes), " diseases and ", nrow(gene_changes), " genes show rule count changes"),
      paste0("- Detailed disease changes: `analysis/rule_changes/", basename(disease_file), "`"),
      paste0("- Detailed gene changes: `analysis/rule_changes/", basename(gene_file), "`")
    )
    
    return(list(
      summary_text = summary_text,
      disease_count = nrow(disease_changes),
      gene_count = nrow(gene_changes),
      total_current_diseases = length(current_disease_counts),
      total_previous_diseases = length(previous_disease_counts),
      total_current_genes = length(current_gene_counts),
      total_previous_genes = length(previous_gene_counts)
    ))
    
  }, error = function(e) {
    return(NULL)
  })
}

# Generate summary statistics for the overview table
generate_summary_stats <- function(current_analysis, previous_analysis, version_dir, compare_with) {
  stats <- list(
    total_diseases_current = 0,
    total_diseases_previous = 0,
    total_genes_current = 0,
    total_genes_previous = 0,
    total_rules_current = 0,
    total_rules_previous = 0,
    diseases_with_changes = 0,
    genes_with_changes = 0
  )
  
  tryCatch({
    # Get current totals from rules analysis structure
    if (!is.null(current_analysis)) {
      # Check different possible data structure formats
      if (!is.null(current_analysis$diseases)) {
        if (is.list(current_analysis$diseases) && !is.null(current_analysis$diseases$`Total Diseases`)) {
          stats$total_diseases_current = current_analysis$diseases$`Total Diseases`
        }
      }
      if (!is.null(current_analysis$genes)) {
        if (is.list(current_analysis$genes) && !is.null(current_analysis$genes$`Total Genes`)) {
          stats$total_genes_current = current_analysis$genes$`Total Genes`
        }
      }
      if (!is.null(current_analysis$total_rules)) {
        stats$total_rules_current = current_analysis$total_rules
      }
    }
    
    # Get previous totals
    if (!is.null(previous_analysis)) {
      if (!is.null(previous_analysis$diseases)) {
        if (is.list(previous_analysis$diseases) && !is.null(previous_analysis$diseases$`Total Diseases`)) {
          stats$total_diseases_previous = previous_analysis$diseases$`Total Diseases`
        }
      }
      if (!is.null(previous_analysis$genes)) {
        if (is.list(previous_analysis$genes) && !is.null(previous_analysis$genes$`Total Genes`)) {
          stats$total_genes_previous = previous_analysis$genes$`Total Genes`
        }
      }
      if (!is.null(previous_analysis$total_rules)) {
        stats$total_rules_previous = previous_analysis$total_rules
      }
    }
    
    # Get change counts from TSV generation
    if (!is.null(compare_with) && !is.null(version_dir)) {
      tsv_info <- generate_detailed_tsv_files(version_dir, compare_with)
      if (!is.null(tsv_info)) {
        stats$diseases_with_changes = tsv_info$disease_count
        stats$genes_with_changes = tsv_info$gene_count
        # Update totals from TSV analysis if not already set
        if (stats$total_diseases_current == 0) {
          stats$total_diseases_current = tsv_info$total_current_diseases
        }
        if (stats$total_diseases_previous == 0) {
          stats$total_diseases_previous = tsv_info$total_previous_diseases
        }
        if (stats$total_genes_current == 0) {
          stats$total_genes_current = tsv_info$total_current_genes
        }
        if (stats$total_genes_previous == 0) {
          stats$total_genes_previous = tsv_info$total_previous_genes
        }
      }
    }
    
  }, error = function(e) {
    # Return default stats on error
  })
  
  return(stats)
}

# Comprehensive Rule Change Analysis with Detailed Inference
# This function performs detailed rule-by-rule comparison and inference

#' Find the correct path for a previous version using output root directory
#' @param output_root Output root directory (e.g., "out_rule_generation")
#' @param current_version_dir Current version directory path
#' @param compare_with Previous version identifier (e.g., "version_44B")
#' @return Full path to previous version directory or NULL if not found
find_previous_version_path <- function(output_root, current_version_dir, compare_with) {
  if (is.null(compare_with)) return(NULL)
  
  # Remove "version_" prefix if present
  version_id <- gsub("^version_", "", compare_with)
  
  # Determine if current directory is a step directory
  current_dir_name <- basename(current_version_dir)
  is_current_step <- grepl("^step_", current_dir_name)
  
  # Parse version to check if it's step-wise
  if (grepl("^([0-9]+)([A-Za-z]+)$", version_id)) {
    # Previous is step-wise version (e.g., "44B")
    base_version <- gsub("[A-Za-z].*$", "", version_id)
    step_dir <- file.path(output_root, paste0("version_", base_version), paste0("step_", version_id))
    
    if (dir.exists(step_dir)) {
      return(step_dir)
    }
  } else {
    # Previous is standard version (e.g., "43")
    standard_dir <- file.path(output_root, paste0("version_", version_id))
    
    if (dir.exists(standard_dir)) {
      return(standard_dir)
    }
  }
  
  return(NULL)
}

#' Generate comprehensive rule change analysis with detailed inference
#' @param version_dir Current version directory path
#' @param compare_with Previous version identifier (e.g., "version_43")
#' @param input_comparison Input comparison results for inference context
#' @param prepared_data Current prepared data (gene_list, variant_list)
#' @param previous_prepared_data Previous prepared data for detailed inference
#' @return List containing detailed analysis results and summary statistics
generate_comprehensive_rule_analysis <- function(version_dir, compare_with, input_comparison = NULL, prepared_data = NULL, previous_prepared_data = NULL) {
  
  # Find current and previous rules files
  current_outputs_dir <- file.path(version_dir, "outputs")
  if (!dir.exists(current_outputs_dir)) {
    return(NULL)
  }
  
  current_rules_files <- list.files(current_outputs_dir, pattern = "rules_file.*\\.tsv$", full.names = TRUE)
  if (length(current_rules_files) == 0) {
    return(NULL)
  }
  
  current_rules_file <- current_rules_files[1]
  
  # Handle nested structure for previous version path
  # Determine output root directory from current version directory
  current_dir_name <- basename(version_dir)
  if (grepl("^step_", current_dir_name)) {
    # Current is step-wise, output root is two levels up
    output_root <- dirname(dirname(version_dir))
  } else {
    # Current is standard version, output root is one level up
    output_root <- dirname(version_dir)
  }
  
  previous_version_dir <- find_previous_version_path(output_root, version_dir, compare_with)
  if (is.null(previous_version_dir)) {
    return(NULL)
  }
  
  previous_outputs_dir <- file.path(previous_version_dir, "outputs")
  
  if (!dir.exists(previous_outputs_dir)) {
    return(NULL)
  }
  
  previous_rules_files <- list.files(previous_outputs_dir, pattern = "rules_file.*\\.tsv$", full.names = TRUE)
  if (length(previous_rules_files) == 0) {
    return(NULL)
  }
  
  previous_rules_file <- previous_rules_files[1]
  
  if (!file.exists(current_rules_file) || !file.exists(previous_rules_file)) {
    return(NULL)
  }
  
  # Read rules data
  current_rules <- read.table(current_rules_file, sep = "\t", header = TRUE, stringsAsFactors = FALSE, quote = "")
  previous_rules <- read.table(previous_rules_file, sep = "\t", header = TRUE, stringsAsFactors = FALSE, quote = "")
  
  # Create unique identifiers for rules (Disease + RULE content)
  current_rules$rule_id <- paste(current_rules$Disease_report, current_rules$RULE, sep = "|||")
  previous_rules$rule_id <- paste(previous_rules$Disease_report, previous_rules$RULE, sep = "|||")
  
  # Find added, removed, and modified rules
  current_ids <- current_rules$rule_id
  previous_ids <- previous_rules$rule_id
  
  added_ids <- setdiff(current_ids, previous_ids)
  removed_ids <- setdiff(previous_ids, current_ids)
  unchanged_ids <- intersect(current_ids, previous_ids)
  
  # Create detailed change analysis
  detailed_changes <- list()
  
  # Process added rules (limit to reasonable number for performance)
  max_rules_to_process <- 500  # Process up to 500 rules for meaningful analysis
  added_limit <- min(max_rules_to_process, length(added_ids))
  
  for (i in 1:added_limit) {
    rule_id <- added_ids[i]
    rule_row <- current_rules[current_rules$rule_id == rule_id, ][1, ]
    
    inference <- infer_rule_change_reason(rule_row, "ADDED", input_comparison, prepared_data, previous_prepared_data)
    
    detailed_changes[[length(detailed_changes) + 1]] <- list(
      Change_Type = "ADDED",
      Disease = as.character(rule_row$Disease_report),
      Gene = as.character(extract_gene_from_rule(rule_row$RULE)),
      Rule_Content = as.character(rule_row$RULE),
      cID = as.character(rule_row$cID),
      cCond = as.character(rule_row$cCond),
      cThresh = as.character(rule_row$cThresh),
      Reason = as.character(inference$reason),
      Detail = as.character(inference$detail),
      Confidence = as.character(inference$confidence),
      Rule_Type = as.character(classify_rule_type(rule_row$RULE))
    )
  }
  
  # Process removed rules (limit to same number for balanced analysis)
  removed_limit <- min(max_rules_to_process, length(removed_ids))
  for (i in 1:removed_limit) {
    rule_id <- removed_ids[i]
    rule_row <- previous_rules[previous_rules$rule_id == rule_id, ][1, ]
    inference <- infer_rule_change_reason(rule_row, "REMOVED", input_comparison, prepared_data, previous_prepared_data)
    
    detailed_changes[[length(detailed_changes) + 1]] <- list(
      Change_Type = "REMOVED",
      Disease = as.character(rule_row$Disease_report),
      Gene = as.character(extract_gene_from_rule(rule_row$RULE)),
      Rule_Content = as.character(rule_row$RULE),
      cID = as.character(rule_row$cID),
      cCond = as.character(rule_row$cCond),
      cThresh = as.character(rule_row$cThresh),
      Reason = as.character(inference$reason),
      Detail = as.character(inference$detail),
      Confidence = as.character(inference$confidence),
      Rule_Type = as.character(classify_rule_type(rule_row$RULE))
    )
  }
  
  # Convert to data frame for TSV output
  if (length(detailed_changes) > 0) {
    # Ensure all values are properly converted to characters
    changes_df <- do.call(rbind, lapply(detailed_changes, function(x) {
      data.frame(
        Change_Type = as.character(x$Change_Type),
        Disease = as.character(x$Disease),
        Gene = as.character(x$Gene),
        Rule_Content = as.character(x$Rule_Content),
        cID = as.character(x$cID),
        cCond = as.character(x$cCond),
        cThresh = as.character(x$cThresh),
        Reason = as.character(x$Reason),
        Detail = as.character(x$Detail),
        Confidence = as.character(x$Confidence),
        Rule_Type = as.character(x$Rule_Type),
        stringsAsFactors = FALSE
      )
    }))
    
    # Save detailed TSV file
    output_dir <- file.path(version_dir, "analysis", "rule_changes")
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    detailed_file <- file.path(output_dir, "detailed_rule_changes.tsv")
    
    write.table(changes_df, detailed_file, sep = "\t", row.names = FALSE, quote = FALSE)
    
    # Generate summary statistics
    summary_stats <- generate_change_summary_statistics(changes_df)
    
    return(list(
      detailed_changes = changes_df,
      summary_stats = summary_stats,
      total_changes = nrow(changes_df),
      added_count = sum(changes_df$Change_Type == "ADDED"),
      removed_count = sum(changes_df$Change_Type == "REMOVED"),
      detailed_file = detailed_file
    ))
  }
  
  return(NULL)
}

#' Extract gene symbol from rule content
#' @param rule_content The RULE column content
#' @return Gene symbol or "Unknown"
extract_gene_from_rule <- function(rule_content) {
  # Look for SYMBOL == GENE pattern
  gene_match <- regmatches(rule_content, regexpr("SYMBOL == [A-Za-z0-9_-]+", rule_content))
  if (length(gene_match) > 0) {
    return(sub("SYMBOL == ", "", gene_match))
  }
  
  # Look for SpliceAI_pred_GENE pattern  
  spliceai_match <- regmatches(rule_content, regexpr("SpliceAI_pred_[A-Za-z0-9_-]+", rule_content))
  if (length(spliceai_match) > 0) {
    return(sub("SpliceAI_pred_", "", spliceai_match))
  }
  
  return("Unknown")
}

#' Classify rule type based on content patterns
#' @param rule_content The RULE column content
#' @return Rule type classification
classify_rule_type <- function(rule_content) {
  if (grepl("ClinVar_CLNSIG == Pathogenic.*STARS >= 1|ClinVar_CLNSIG == Likely_pathogenic.*STARS >= 1", rule_content)) {
    return("ClinVar P/LP (STARS ≥ 1)")
  } else if (grepl("Consequence == frameshift_variant|Consequence == stop_gained", rule_content)) {
    return("Frameshift/Stop Gained")
  } else if (grepl("Consequence == missense_variant", rule_content)) {
    return("Missense Variants")
  } else if (grepl("splice_acceptor_variant|splice_donor_variant|splice_region_variant", rule_content)) {
    return("Splice Site Variants")
  } else if (grepl("SpliceAI_pred_", rule_content)) {
    return("SpliceAI Predictions")
  } else if (grepl("HGVSc =~|HGVSc ==", rule_content)) {
    return("Specific Variants (HGVSc)")
  } else if (grepl("Validation", rule_content)) {
    return("Special/Validation Rules")
  } else {
    return("Other")
  }
}

#' Infer the reason for a rule change using available context
#' @param rule_row Single rule row from data frame
#' @param change_type "ADDED" or "REMOVED"
#' @param input_comparison Input comparison results
#' @param prepared_data Current prepared data
#' @param previous_prepared_data Previous prepared data
#' @return List with reason, detail, and confidence
infer_rule_change_reason <- function(rule_row, change_type, input_comparison = NULL, prepared_data = NULL, previous_prepared_data = NULL) {
  
  # Ensure rule content is character
  rule_content <- as.character(rule_row$RULE)
  gene <- extract_gene_from_rule(rule_content)
  disease <- as.character(rule_row$Disease_report)
  rule_type <- classify_rule_type(rule_content)
  
  # Default values
  reason <- "Unknown_change"
  detail <- "Cause could not be determined"
  confidence <- "LOW"
  
  # High-confidence inferences
  if (!is.null(input_comparison)) {
    
    # Gene-level changes
    if (!is.null(input_comparison$gene_comparison)) {
      added_genes <- if (!is.null(input_comparison$gene_comparison$added_genes) && 
                         is.character(input_comparison$gene_comparison$added_genes) &&
                         nchar(input_comparison$gene_comparison$added_genes) > 0) {
        unlist(strsplit(as.character(input_comparison$gene_comparison$added_genes), ","))
      } else character(0)
      
      removed_genes <- if (!is.null(input_comparison$gene_comparison$deleted_genes) && 
                           is.character(input_comparison$gene_comparison$deleted_genes) &&
                           nchar(input_comparison$gene_comparison$deleted_genes) > 0) {
        unlist(strsplit(as.character(input_comparison$gene_comparison$deleted_genes), ","))
      } else character(0)
      
      if (gene %in% added_genes && change_type == "ADDED") {
        reason <- "Gene_added_to_master_list"
        detail <- paste0("New gene added to master gene list: ", gene)
        confidence <- "HIGH"
        return(list(reason = reason, detail = detail, confidence = confidence))
      }
      
      if (gene %in% removed_genes && change_type == "REMOVED") {
        reason <- "Gene_removed_from_master_list"
        detail <- paste0("Gene removed from master gene list: ", gene)
        confidence <- "HIGH"
        return(list(reason = reason, detail = detail, confidence = confidence))
      }
    }
  }
  
  # Inheritance pattern analysis (requires both prepared data sets)
  if (!is.null(prepared_data) && !is.null(previous_prepared_data)) {
    current_inheritance <- get_gene_inheritance_info(gene, disease, prepared_data$gene_list)
    previous_inheritance <- get_gene_inheritance_info(gene, disease, previous_prepared_data$gene_list)
    
    if (!is.null(current_inheritance) && !is.null(previous_inheritance)) {
      if (current_inheritance$inheritance != previous_inheritance$inheritance) {
        reason <- "Inheritance_pattern_changed"
        detail <- paste0(gene, ": ", previous_inheritance$inheritance, " → ", current_inheritance$inheritance,
                        " (cThresh: ", previous_inheritance$cthresh, " → ", current_inheritance$cthresh, ")")
        confidence <- "HIGH"
        return(list(reason = reason, detail = detail, confidence = confidence))
      }
      
      if (current_inheritance$variants_to_find != previous_inheritance$variants_to_find) {
        reason <- "Strategy_change"
        detail <- paste0(gene, ": '", previous_inheritance$variants_to_find, "' → '", current_inheritance$variants_to_find, "'")
        confidence <- "MEDIUM"
        return(list(reason = reason, detail = detail, confidence = confidence))
      }
    }
  }
  
  # Rule type specific analysis
  if (grepl("Validation", disease)) {
    reason <- "Special_validation_rule"
    detail <- "Proficiency training or validation rule change"
    confidence <- "HIGH"
    return(list(reason = reason, detail = detail, confidence = confidence))
  }
  
  # Configuration-driven changes (medium confidence)
  if (grepl("STARS", rule_row$RULE)) {
    reason <- "ClinVar_threshold_change"
    detail <- "ClinVar STARS threshold or significance criteria may have changed"
    confidence <- "MEDIUM"
    return(list(reason = reason, detail = detail, confidence = confidence))
  }
  
  if (grepl("gnomADe_AF|QUAL|format_DP|format_GQ", rule_row$RULE)) {
    reason <- "Quality_filter_change"
    detail <- "Quality filter thresholds may have changed"
    confidence <- "MEDIUM"
    return(list(reason = reason, detail = detail, confidence = confidence))
  }
  
  # Pattern-based inference (low-medium confidence)
  if (rule_type == "Specific Variants (HGVSc)") {
    reason <- "Supplemental_variant_change"
    detail <- "Specific variant in supplemental list may have been added/removed"
    confidence <- "MEDIUM"
    return(list(reason = reason, detail = detail, confidence = confidence))
  }
  
  # Fallback with contextual hints
  reason <- "Complex_multi_factor_change"
  potential_causes <- c()
  if (change_type == "ADDED") potential_causes <- c(potential_causes, "New_rule_generation")
  if (change_type == "REMOVED") potential_causes <- c(potential_causes, "Rule_elimination")
  potential_causes <- c(potential_causes, paste0("Affects_", rule_type))
  
  detail <- paste0("Potential causes: ", paste(potential_causes, collapse = " + "))
  confidence <- "LOW"
  
  return(list(reason = reason, detail = detail, confidence = confidence))
}

#' Get gene inheritance information from gene list
#' @param gene Gene symbol
#' @param disease Disease name
#' @param gene_list Gene list data frame
#' @return List with inheritance info or NULL
get_gene_inheritance_info <- function(gene, disease, gene_list) {
  if (is.null(gene_list) || !("Gene" %in% names(gene_list))) {
    return(NULL)
  }
  
  # Find matching rows
  matching_rows <- gene_list[gene_list$Gene == gene, ]
  if (nrow(matching_rows) == 0) {
    return(NULL)
  }
  
  # Use first match (could be refined to match disease too)
  row <- matching_rows[1, ]
  
  inheritance <- if ("Inheritance" %in% names(row)) row$Inheritance else "Unknown"
  variants_to_find <- if ("Variants.To.Find" %in% names(row)) row$Variants.To.Find else "Unknown"
  carrier <- if ("Carrier" %in% names(row)) row$Carrier else FALSE
  
  # Calculate expected cThresh
  cthresh <- if (inheritance %in% c("AR", "XLR") && !carrier) 2 else 1
  
  return(list(
    inheritance = inheritance,
    variants_to_find = variants_to_find,
    carrier = carrier,
    cthresh = cthresh
  ))
}

#' Generate summary statistics from detailed changes
#' @param changes_df Data frame of detailed changes
#' @return List of summary statistics for report
generate_change_summary_statistics <- function(changes_df) {
  
  # By change type
  by_change_type <- table(changes_df$Change_Type)
  
  # By reason
  by_reason <- table(changes_df$Reason)
  
  # By confidence
  by_confidence <- table(changes_df$Confidence)
  
  # By rule type
  by_rule_type <- table(changes_df$Rule_Type)
  
  # By gene (top affected genes)
  by_gene <- table(changes_df$Gene)
  top_genes <- head(sort(by_gene, decreasing = TRUE), 10)
  
  # By disease (top affected diseases)
  by_disease <- table(changes_df$Disease)
  top_diseases <- head(sort(by_disease, decreasing = TRUE), 10)
  
  return(list(
    by_change_type = by_change_type,
    by_reason = by_reason,
    by_confidence = by_confidence,
    by_rule_type = by_rule_type,
    top_genes = top_genes,
    top_diseases = top_diseases,
    total_changes = nrow(changes_df)
  ))
}
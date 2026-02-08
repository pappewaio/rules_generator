# Predictor Module
# This module predicts rule changes based on input analysis

# Source dependencies
if (!exists("logger")) {
  source(file.path(dirname(parent.frame(2)$ofile), "logger.R"))
}

#' Predict rule changes based on gene list changes
#' @param gene_comparison Gene comparison results from input_comparator
#' @param config Configuration object
#' @param logger Logger instance
#' @return List containing gene-based predictions
predict_gene_changes <- function(gene_comparison, config, logger) {
  log_info(logger, "Predicting rule changes based on gene modifications...")
  
  predictions <- list(
    added_rules = 0,
    deleted_rules = 0,
    modified_rules = 0,
    confidence_score = 0.0
  )
  
  # Predict rules for added genes
  if (gene_comparison$total_added > 0) {
    # Each added gene typically generates multiple rules
    # Base estimate: 2-8 rules per gene depending on complexity
    rules_per_gene <- 4  # Average estimate
    predictions$added_rules <- gene_comparison$total_added * rules_per_gene
    log_info(logger, paste("Predicted", predictions$added_rules, "new rules from", gene_comparison$total_added, "added genes"))
  }
  
  # Predict rules for deleted genes
  if (gene_comparison$total_deleted > 0) {
    # Each deleted gene typically removes multiple rules
    rules_per_gene <- 4  # Average estimate
    predictions$deleted_rules <- gene_comparison$total_deleted * rules_per_gene
    log_info(logger, paste("Predicted", predictions$deleted_rules, "deleted rules from", gene_comparison$total_deleted, "deleted genes"))
  }
  
  # Predict rules for modified genes
  if (gene_comparison$total_modified > 0) {
    # Modified genes may change rule content but not necessarily count
    # Estimate 50% chance each modified gene affects rules
    modification_probability <- 0.5
    predictions$modified_rules <- ceiling(gene_comparison$total_modified * modification_probability)
    log_info(logger, paste("Predicted", predictions$modified_rules, "modified rules from", gene_comparison$total_modified, "modified genes"))
  }
  
  # Calculate confidence score based on completeness of information
  confidence_factors <- c(
    ifelse(gene_comparison$total_added > 0, 0.8, 1.0),  # High confidence for additions
    ifelse(gene_comparison$total_deleted > 0, 0.9, 1.0),  # Very high confidence for deletions
    ifelse(gene_comparison$total_modified > 0, 0.6, 1.0)   # Medium confidence for modifications
  )
  
  predictions$confidence_score <- mean(confidence_factors)
  
  return(predictions)
}

#' Predict rule changes based on variant list changes
#' @param variant_comparison Variant comparison results from input_comparator
#' @param logger Logger instance
#' @return List containing variant-based predictions
predict_variant_changes <- function(variant_comparison, logger) {
  log_info(logger, "Predicting rule changes based on variant modifications...")
  
  predictions <- list(
    affected_rules = 0,
    confidence_score = 0.0
  )
  
  # Variant changes typically affect specific rules for supplemental variants
  if (variant_comparison$total_changes > 0) {
    # Each variant change may affect 1-2 rules on average
    rules_per_variant <- 1.5
    predictions$affected_rules <- ceiling(variant_comparison$total_changes * rules_per_variant)
    log_info(logger, paste("Predicted", predictions$affected_rules, "affected rules from", variant_comparison$total_changes, "variant changes"))
  }
  
  # Confidence is high for variant changes as they're more predictable
  predictions$confidence_score <- 0.85
  
  return(predictions)
}

#' Predict rule changes based on configuration changes
#' @param config_comparison Configuration comparison results from input_comparator
#' @param logger Logger instance
#' @return List containing configuration-based predictions
predict_config_changes <- function(config_comparison, logger) {
  log_info(logger, "Predicting rule changes based on configuration modifications...")
  
  predictions <- list(
    global_rule_changes = 0,
    confidence_score = 0.0
  )
  
  # Configuration changes can have wide-reaching effects
  if (config_comparison$total_changes > 0) {
    # Settings changes affect all rules
    if (config_comparison$settings_changes > 0) {
      predictions$global_rule_changes <- predictions$global_rule_changes + 1
      log_info(logger, "Settings changes detected - may affect all rules")
    }
    
    # Rule template changes affect rules using those templates
    if (config_comparison$rules_changes > 0) {
      predictions$global_rule_changes <- predictions$global_rule_changes + 1
      log_info(logger, "Rule template changes detected - may affect multiple rules")
    }
    
    # Special cases changes affect specific subsets
    if (config_comparison$special_cases_changes > 0) {
      predictions$global_rule_changes <- predictions$global_rule_changes + 1
      log_info(logger, "Special cases changes detected - may affect specific rules")
    }
  }
  
  # Confidence varies based on type of config change
  if (config_comparison$total_changes > 0) {
    predictions$confidence_score <- 0.7  # Medium confidence due to complexity
  } else {
    predictions$confidence_score <- 1.0  # High confidence for no changes
  }
  
  return(predictions)
}

#' Estimate the scope and impact of predicted changes
#' @param gene_predictions Gene-based predictions
#' @param variant_predictions Variant-based predictions
#' @param config_predictions Configuration-based predictions
#' @param logger Logger instance
#' @return List containing scope and impact estimates
estimate_change_scope <- function(gene_predictions, variant_predictions, config_predictions, logger) {
  log_info(logger, "Estimating scope and impact of predicted changes...")
  
  # Calculate total predicted changes
  total_added <- gene_predictions$added_rules
  total_deleted <- gene_predictions$deleted_rules
  total_modified <- gene_predictions$modified_rules + variant_predictions$affected_rules
  
  # Adjust for global configuration changes
  if (config_predictions$global_rule_changes > 0) {
    # Global changes may affect a large percentage of existing rules
    estimated_existing_rules <- 50000  # Rough estimate based on typical rule count
    global_impact_rate <- 0.1  # Assume 10% of rules affected by global changes
    total_modified <- total_modified + ceiling(estimated_existing_rules * global_impact_rate)
  }
  
  # Calculate net change
  net_change <- total_added - total_deleted
  
  # Classify impact level
  impact_level <- "minimal"
  if (abs(net_change) > 1000 || total_modified > 5000) {
    impact_level <- "major"
  } else if (abs(net_change) > 100 || total_modified > 1000) {
    impact_level <- "moderate"
  } else if (abs(net_change) > 10 || total_modified > 100) {
    impact_level <- "minor"
  }
  
  scope <- list(
    total_added = total_added,
    total_deleted = total_deleted,
    total_modified = total_modified,
    net_change = net_change,
    impact_level = impact_level,
    estimated_processing_time = estimate_processing_time(total_added, total_deleted, total_modified)
  )
  
  log_info(logger, paste("Change scope estimate:"))
  log_info(logger, paste("  Rules to add:", total_added))
  log_info(logger, paste("  Rules to delete:", total_deleted))
  log_info(logger, paste("  Rules to modify:", total_modified))
  log_info(logger, paste("  Net change:", net_change))
  log_info(logger, paste("  Impact level:", impact_level))
  
  return(scope)
}

#' Estimate processing time based on predicted changes
#' @param added Added rules count
#' @param deleted Deleted rules count
#' @param modified Modified rules count
#' @return Estimated processing time in seconds
estimate_processing_time <- function(added, deleted, modified) {
  # Base processing time
  base_time <- 10  # seconds
  
  # Time per rule operation (rough estimates)
  time_per_add <- 0.01
  time_per_delete <- 0.005
  time_per_modify <- 0.015
  
  total_time <- base_time + 
    (added * time_per_add) + 
    (deleted * time_per_delete) + 
    (modified * time_per_modify)
  
  return(ceiling(total_time))
}

#' Calculate overall confidence score
#' @param gene_predictions Gene-based predictions
#' @param variant_predictions Variant-based predictions
#' @param config_predictions Configuration-based predictions
#' @param comparison_results Input comparison results
#' @return Overall confidence score (0-1)
calculate_overall_confidence <- function(gene_predictions, variant_predictions, config_predictions, comparison_results) {
  # Weight the confidence scores based on the magnitude of changes
  weights <- c(
    gene_weight = (gene_predictions$added_rules + gene_predictions$deleted_rules + gene_predictions$modified_rules) / 100,
    variant_weight = variant_predictions$affected_rules / 50,
    config_weight = config_predictions$global_rule_changes * 10
  )
  
  # Normalize weights
  total_weight <- sum(weights)
  if (total_weight == 0) {
    return(1.0)  # No changes = high confidence
  }
  
  weights <- weights / total_weight
  
  # Calculate weighted confidence
  overall_confidence <- 
    (gene_predictions$confidence_score * weights[1]) +
    (variant_predictions$confidence_score * weights[2]) +
    (config_predictions$confidence_score * weights[3])
  
  # Adjust for data completeness
  if (is.null(comparison_results$compared_with)) {
    overall_confidence <- overall_confidence * 0.8  # Lower confidence without comparison
  }
  
  return(min(overall_confidence, 1.0))
}

#' Main predictive analysis function
#' @param comparison_results Results from input comparison
#' @param config Configuration object
#' @param output_dir Output directory path
#' @param logger Logger instance
#' @return List containing comprehensive prediction results
predict_changes <- function(comparison_results, config, output_dir, logger) {
  log_section(logger, "PREDICTIVE ANALYSIS")
  
  if (is.null(comparison_results)) {
    log_warning(logger, "No comparison results available for prediction")
    return(NULL)
  }
  
  # Generate predictions based on different change types
  gene_predictions <- predict_gene_changes(
    comparison_results$gene_comparison, 
    config, 
    logger
  )
  
  variant_predictions <- predict_variant_changes(
    comparison_results$variant_comparison, 
    logger
  )
  
  config_predictions <- predict_config_changes(
    comparison_results$config_comparison, 
    logger
  )
  
  # Estimate scope and impact
  scope_estimate <- estimate_change_scope(
    gene_predictions, 
    variant_predictions, 
    config_predictions, 
    logger
  )
  
  # Calculate overall confidence
  overall_confidence <- calculate_overall_confidence(
    gene_predictions, 
    variant_predictions, 
    config_predictions, 
    comparison_results
  )
  
  # Create comprehensive prediction results
  predictions <- list(
    gene_predictions = gene_predictions,
    variant_predictions = variant_predictions,
    config_predictions = config_predictions,
    scope_estimate = scope_estimate,
    overall_confidence = overall_confidence,
    prediction_timestamp = Sys.time(),
    based_on_comparison = comparison_results$compared_with
  )
  
  # Save prediction results
  save_prediction_results(predictions, output_dir, logger)
  
  # Log summary
  log_info(logger, "Predictive analysis completed")
  log_stats(logger, list(
    "Predicted added rules" = scope_estimate$total_added,
    "Predicted deleted rules" = scope_estimate$total_deleted,
    "Predicted modified rules" = scope_estimate$total_modified,
    "Net change" = scope_estimate$net_change,
    "Impact level" = scope_estimate$impact_level,
    "Overall confidence" = paste0(round(overall_confidence * 100, 1), "%"),
    "Estimated processing time" = paste0(scope_estimate$estimated_processing_time, " seconds")
  ))
  
  return(predictions)
}

#' Save prediction results to analysis directory
#' @param predictions Prediction results object
#' @param output_dir Output directory path
#' @param logger Logger instance
save_prediction_results <- function(predictions, output_dir, logger) {
  analysis_dir <- file.path(output_dir, "analysis", "predictions")
  dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Save as JSON for easy reading
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  predictions_file <- file.path(analysis_dir, paste0("predictions_", timestamp, ".json"))
  
  tryCatch({
    jsonlite::write_json(predictions, predictions_file, pretty = TRUE)
    log_info(logger, paste("Prediction results saved to:", predictions_file))
  }, error = function(e) {
    log_warning(logger, paste("Failed to save prediction results:", e$message))
  })
} 
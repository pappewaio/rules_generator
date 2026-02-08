# Prediction Validator Module
# This module validates predictions against actual results

# Source dependencies
if (!exists("logger")) {
  source(file.path(dirname(parent.frame(2)$ofile), "logger.R"))
}

#' Analyze actual rules changes by comparing current output with previous version
#' @param current_rules_file Path to current rules file
#' @param previous_rules_file Path to previous rules file (can be NULL)
#' @param logger Logger instance
#' @return List containing actual changes analysis
analyze_actual_changes <- function(current_rules_file, previous_rules_file, logger) {
  log_info(logger, "Analyzing actual rule changes...")
  
  # Read current rules
  if (!file.exists(current_rules_file)) {
    log_warning(logger, paste("Current rules file not found:", current_rules_file))
    return(NULL)
  }
  
  current_rules <- read.delim(current_rules_file, stringsAsFactors = FALSE)
  log_info(logger, paste("Current rules count:", nrow(current_rules)))
  
  # Read previous rules if available
  if (is.null(previous_rules_file) || !file.exists(previous_rules_file)) {
    log_info(logger, "No previous rules file available for comparison")
    return(list(
      total_current = nrow(current_rules),
      total_previous = 0,
      added_rules = nrow(current_rules),
      deleted_rules = 0,
      modified_rules = 0,
      unchanged_rules = 0,
      net_change = nrow(current_rules)
    ))
  }
  
  previous_rules <- read.delim(previous_rules_file, stringsAsFactors = FALSE)
  log_info(logger, paste("Previous rules count:", nrow(previous_rules)))
  
  # Create unique keys for comparison
  current_keys <- paste(current_rules$Disease_report, current_rules$RULE, sep = "_")
  previous_keys <- paste(previous_rules$Disease_report, previous_rules$RULE, sep = "_")
  
  # Find changes
  added_keys <- setdiff(current_keys, previous_keys)
  deleted_keys <- setdiff(previous_keys, current_keys)
  common_keys <- intersect(current_keys, previous_keys)
  
  # For rules that exist in both versions, check for modifications
  modified_count <- 0
  if (length(common_keys) > 0) {
    for (key in common_keys) {
      current_row <- current_rules[current_keys == key, ]
      previous_row <- previous_rules[previous_keys == key, ]
      
      # Compare rule content (excluding Disease_report and RULE columns)
      comparison_cols <- setdiff(colnames(current_row), c("Disease_report", "RULE"))
      
      for (col in comparison_cols) {
        if (col %in% colnames(previous_row)) {
          if (!identical(current_row[[col]], previous_row[[col]])) {
            modified_count <- modified_count + 1
            break  # Count each rule only once even if multiple columns changed
          }
        }
      }
    }
  }
  
  results <- list(
    total_current = nrow(current_rules),
    total_previous = nrow(previous_rules),
    added_rules = length(added_keys),
    deleted_rules = length(deleted_keys),
    modified_rules = modified_count,
    unchanged_rules = length(common_keys) - modified_count,
    net_change = nrow(current_rules) - nrow(previous_rules)
  )
  
  log_info(logger, paste("Actual changes analysis:"))
  log_info(logger, paste("  Added rules:", results$added_rules))
  log_info(logger, paste("  Deleted rules:", results$deleted_rules))
  log_info(logger, paste("  Modified rules:", results$modified_rules))
  log_info(logger, paste("  Unchanged rules:", results$unchanged_rules))
  log_info(logger, paste("  Net change:", results$net_change))
  
  return(results)
}

#' Compare predictions with actual results
#' @param predictions Prediction results from predictor
#' @param actual_changes Actual changes analysis
#' @param logger Logger instance
#' @return List containing comparison results
compare_predictions_with_actual <- function(predictions, actual_changes, logger) {
  log_info(logger, "Comparing predictions with actual results...")
  
  if (is.null(predictions) || is.null(actual_changes)) {
    log_warning(logger, "Missing predictions or actual changes data")
    return(NULL)
  }
  
  # Extract predicted values
  predicted_added <- predictions$scope_estimate$total_added
  predicted_deleted <- predictions$scope_estimate$total_deleted
  predicted_modified <- predictions$scope_estimate$total_modified
  predicted_net <- predictions$scope_estimate$net_change
  
  # Extract actual values
  actual_added <- actual_changes$added_rules
  actual_deleted <- actual_changes$deleted_rules
  actual_modified <- actual_changes$modified_rules
  actual_net <- actual_changes$net_change
  
  # Calculate accuracy metrics
  accuracy_added <- calculate_accuracy(predicted_added, actual_added)
  accuracy_deleted <- calculate_accuracy(predicted_deleted, actual_deleted)
  accuracy_modified <- calculate_accuracy(predicted_modified, actual_modified)
  accuracy_net <- calculate_accuracy(predicted_net, actual_net)
  
  # Calculate overall accuracy
  overall_accuracy <- mean(c(accuracy_added, accuracy_deleted, accuracy_modified, accuracy_net))
  
  comparison <- list(
    predicted_added = predicted_added,
    actual_added = actual_added,
    accuracy_added = accuracy_added,
    
    predicted_deleted = predicted_deleted,
    actual_deleted = actual_deleted,
    accuracy_deleted = accuracy_deleted,
    
    predicted_modified = predicted_modified,
    actual_modified = actual_modified,
    accuracy_modified = accuracy_modified,
    
    predicted_net = predicted_net,
    actual_net = actual_net,
    accuracy_net = accuracy_net,
    
    overall_accuracy = overall_accuracy,
    prediction_confidence = predictions$overall_confidence
  )
  
  log_info(logger, paste("Prediction accuracy results:"))
  log_info(logger, paste("  Added rules accuracy:", paste0(round(accuracy_added * 100, 1), "%")))
  log_info(logger, paste("  Deleted rules accuracy:", paste0(round(accuracy_deleted * 100, 1), "%")))
  log_info(logger, paste("  Modified rules accuracy:", paste0(round(accuracy_modified * 100, 1), "%")))
  log_info(logger, paste("  Net change accuracy:", paste0(round(accuracy_net * 100, 1), "%")))
  log_info(logger, paste("  Overall accuracy:", paste0(round(overall_accuracy * 100, 1), "%")))
  
  return(comparison)
}

#' Calculate accuracy score between predicted and actual values
#' @param predicted Predicted value
#' @param actual Actual value
#' @return Accuracy score (0-1)
calculate_accuracy <- function(predicted, actual) {
  if (predicted == 0 && actual == 0) {
    return(1.0)  # Perfect prediction for no changes
  }
  
  if (predicted == 0 || actual == 0) {
    # One is zero, other is not - calculate based on the non-zero value
    non_zero <- max(predicted, actual)
    return(max(0, 1 - abs(predicted - actual) / non_zero))
  }
  
  # Both are non-zero - calculate relative accuracy
  relative_error <- abs(predicted - actual) / max(predicted, actual)
  return(max(0, 1 - relative_error))
}

#' Generate accuracy classification and recommendations
#' @param comparison Comparison results
#' @param logger Logger instance
#' @return List containing classification and recommendations
generate_accuracy_report <- function(comparison, logger) {
  log_info(logger, "Generating accuracy report...")
  
  overall_accuracy <- comparison$overall_accuracy
  
  # Classify accuracy level
  if (overall_accuracy >= 0.9) {
    accuracy_level <- "excellent"
    recommendation <- "Prediction model is performing very well"
  } else if (overall_accuracy >= 0.75) {
    accuracy_level <- "good"
    recommendation <- "Prediction model is performing adequately"
  } else if (overall_accuracy >= 0.5) {
    accuracy_level <- "fair"
    recommendation <- "Prediction model needs improvement"
  } else {
    accuracy_level <- "poor"
    recommendation <- "Prediction model requires significant adjustment"
  }
  
  # Identify specific areas for improvement
  improvements <- list()
  
  if (comparison$accuracy_added < 0.7) {
    improvements <- append(improvements, "Improve prediction of added rules")
  }
  if (comparison$accuracy_deleted < 0.7) {
    improvements <- append(improvements, "Improve prediction of deleted rules")
  }
  if (comparison$accuracy_modified < 0.7) {
    improvements <- append(improvements, "Improve prediction of modified rules")
  }
  if (comparison$accuracy_net < 0.7) {
    improvements <- append(improvements, "Improve net change prediction")
  }
  
  # Compare confidence with actual accuracy
  confidence_vs_accuracy <- comparison$prediction_confidence - overall_accuracy
  confidence_assessment <- if (abs(confidence_vs_accuracy) < 0.1) {
    "well-calibrated"
  } else if (confidence_vs_accuracy > 0.1) {
    "overconfident"
  } else {
    "underconfident"
  }
  
  report <- list(
    accuracy_level = accuracy_level,
    overall_accuracy = overall_accuracy,
    recommendation = recommendation,
    improvements_needed = improvements,
    confidence_assessment = confidence_assessment,
    confidence_vs_accuracy = confidence_vs_accuracy
  )
  
  log_info(logger, paste("Accuracy classification:", accuracy_level))
  log_info(logger, paste("Recommendation:", recommendation))
  log_info(logger, paste("Confidence assessment:", confidence_assessment))
  
  return(report)
}

#' Find previous rules file based on comparison version
#' @param output_dir Output directory path (where versions are stored)
#' @param compare_with Previous version identifier
#' @param logger Logger instance
#' @return Path to previous rules file or NULL if not found
find_previous_rules_file <- function(output_dir, compare_with, logger) {
  if (is.null(compare_with)) {
    return(NULL)
  }
  
  # Use the same robust path resolution logic as other functions
  # Remove "version_" prefix if present
  version_id <- gsub("^version_", "", compare_with)
  
  # Parse version to check if it's step-wise
  if (grepl("^([0-9]+)([A-Za-z]+)$", version_id)) {
    # Previous is step-wise version (e.g., "44A")
    base_version <- gsub("[A-Za-z].*$", "", version_id)
    library_path <- file.path(output_dir, paste0("version_", base_version), paste0("step_", version_id), "outputs")
  } else {
    # Previous is standard version (e.g., "43")
    library_path <- file.path(output_dir, paste0("version_", version_id), "outputs")
  }
  
  if (!dir.exists(library_path)) {
    log_warning(logger, paste("Previous version outputs directory not found:", library_path))
    return(NULL)
  }
  
  # Look for rules files
  rules_files <- list.files(library_path, pattern = ".*rules_file.*\\.tsv$", full.names = TRUE)
  
  if (length(rules_files) == 0) {
    log_warning(logger, paste("No previous rules file found in:", library_path))
    return(NULL)
  }
  
  # Return the first (and typically only) rules file
  return(rules_files[1])
}

#' Main prediction validation function
#' @param predictions Prediction results from predictor
#' @param current_rules_file Path to current rules file
#' @param output_dir Output directory path (where versions are stored)
#' @param compare_with Previous version identifier
#' @param logger Logger instance
#' @return List containing validation results
validate_predictions <- function(predictions, current_rules_file, output_dir, compare_with, logger) {
  log_section(logger, "PREDICTION VALIDATION")
  
  if (is.null(predictions)) {
    log_warning(logger, "No predictions available for validation")
    return(NULL)
  }
  
  # Find previous rules file
  previous_rules_file <- find_previous_rules_file(output_dir, compare_with, logger)
  
  # Analyze actual changes
  actual_changes <- analyze_actual_changes(current_rules_file, previous_rules_file, logger)
  
  if (is.null(actual_changes)) {
    log_warning(logger, "Could not analyze actual changes")
    return(NULL)
  }
  
  # Compare predictions with actual results
  comparison <- compare_predictions_with_actual(predictions, actual_changes, logger)
  
  if (is.null(comparison)) {
    log_warning(logger, "Could not compare predictions with actual results")
    return(NULL)
  }
  
  # Generate accuracy report
  accuracy_report <- generate_accuracy_report(comparison, logger)
  
  # Create comprehensive validation results
  validation_results <- list(
    actual_changes = actual_changes,
    comparison = comparison,
    accuracy_report = accuracy_report,
    validation_timestamp = Sys.time(),
    rules_file_analyzed = current_rules_file,
    compared_with = compare_with
  )
  
  # Save validation results
  save_validation_results(validation_results, output_dir, logger)
  
  # Log summary
  log_info(logger, "Prediction validation completed")
  log_stats(logger, list(
    "Overall accuracy" = paste0(round(comparison$overall_accuracy * 100, 1), "%"),
    "Accuracy level" = accuracy_report$accuracy_level,
    "Confidence assessment" = accuracy_report$confidence_assessment,
    "Improvements needed" = length(accuracy_report$improvements_needed)
  ))
  
  return(validation_results)
}

#' Save validation results to analysis directory
#' @param validation_results Validation results object
#' @param output_dir Output directory path
#' @param logger Logger instance
save_validation_results <- function(validation_results, output_dir, logger) {
  analysis_dir <- file.path(output_dir, "analysis", "prediction_validation")
  dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
  
  # Save as JSON for easy reading
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  validation_file <- file.path(analysis_dir, paste0("validation_", timestamp, ".json"))
  
  tryCatch({
    jsonlite::write_json(validation_results, validation_file, pretty = TRUE)
    log_info(logger, paste("Validation results saved to:", validation_file))
  }, error = function(e) {
    log_warning(logger, paste("Failed to save validation results:", e$message))
  })
} 
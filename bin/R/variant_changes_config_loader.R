#' Variant Changes Configuration Loader
#' 
#' This module provides functions to load and validate variant changes configuration
#' following the same patterns as the existing framework configuration loading.
#' 
#' @author Generated following existing framework patterns

#' Load variant changes configuration from a config directory
#' 
#' This function follows the same pattern as load_simple_config() and uses
#' the same Excel loading approach as load_excel_files().
#' 
#' @param config_dir Configuration directory path (same as used by load_simple_config)
#' @return List containing variant changes configuration, or NULL if disabled/not found
load_variant_changes_config <- function(config_dir) {
  
  # Initialize result structure
  result <- list(
    enabled = FALSE,
    config_file_found = FALSE,
    excel_file_found = FALSE,
    config_dir = config_dir
  )
  
  # Check for variant changes config file (following same pattern as settings.conf)
  variant_changes_file <- file.path(config_dir, "variant_changes.conf")
  
  if (!file.exists(variant_changes_file)) {
    # No config file found - return disabled state (this is normal)
    return(result)
  }
  
  result$config_file_found <- TRUE
  
  # Read config file (following same pattern as load_simple_config)
  tryCatch({
    config_lines <- readLines(variant_changes_file)
    
    # Parse config lines (same pattern as settings parsing)
    for (line in config_lines) {
      line <- trimws(line)
      
      # Skip comments and empty lines (same pattern as column_mappings.conf)
      if (line == "" || grepl("^#", line)) {
        next
      }
      
      # Parse KEY=VALUE pairs (same pattern as settings.conf)
      if (grepl("=", line)) {
        parts <- strsplit(line, "=", fixed = TRUE)[[1]]
        if (length(parts) >= 2) {
          key <- trimws(parts[1])
          value <- trimws(parts[2])
          
          if (key == "ENABLE_VARIANT_CHANGES") {
            result$enabled <- tolower(value) == "true"
          } else if (key == "VARIANT_CHANGES_FILE") {
            result$excel_file <- value
          } else if (key == "VARIANT_CHANGES_SHEET") {
            result$sheet_number <- as.numeric(value)
          }
        }
      }
    }
    
    # Set defaults if not specified
    if (is.null(result$sheet_number)) {
      result$sheet_number <- 1
    }
    
  }, error = function(e) {
    result$config_error <- e$message
    result$enabled <- FALSE
    return(result)
  })
  
  # If not enabled, return early
  if (!result$enabled) {
    return(result)
  }
  
  # Check if Excel file exists (following same pattern as load_excel_files)
  if (!is.null(result$excel_file)) {
    # Handle relative paths (same way as master_gene_list and variant_list)
    excel_path <- result$excel_file
    if (!file.exists(excel_path)) {
      # Try relative to config directory
      excel_path <- file.path(config_dir, result$excel_file)
    }
    
    result$excel_file_found <- file.exists(excel_path)
    result$excel_path <- excel_path
  }
  
  return(result)
}

#' Load variant changes Excel data
#' 
#' This function follows the same pattern as load_excel_files() using openxlsx.
#' Only loads data if config indicates it should be enabled.
#' 
#' @param variant_changes_config Configuration from load_variant_changes_config()
#' @return List containing loaded data, or NULL if not enabled/available
load_variant_changes_data <- function(variant_changes_config) {
  
  # Return NULL if not enabled or no file found
  if (!variant_changes_config$enabled || !variant_changes_config$excel_file_found) {
    return(NULL)
  }
  
  # Load Excel file (following exact same pattern as load_excel_files)
  tryCatch({
    variant_changes_raw <- openxlsx::read.xlsx(
      variant_changes_config$excel_path, 
      sheet = variant_changes_config$sheet_number, 
      colNames = TRUE, 
      startRow = 1
    )
    
    result <- list(
      raw_data = variant_changes_raw,
      row_count = nrow(variant_changes_raw),
      column_names = names(variant_changes_raw),
      excel_path = variant_changes_config$excel_path,
      sheet_number = variant_changes_config$sheet_number
    )
    
    return(result)
    
  }, error = function(e) {
    # Return error information instead of stopping (same pattern as load_excel_files)
    return(list(
      error = e$message,
      excel_path = variant_changes_config$excel_path
    ))
  })
}

#' Test function to validate variant changes config loading
#' 
#' This function can be called independently to test the config loading
#' without running the entire framework.
#' 
#' @param config_dir Configuration directory to test
test_variant_changes_config <- function(config_dir) {
  cat("=== Testing Variant Changes Config Loading ===\n")
  cat("Config directory:", config_dir, "\n")
  
  # Test config loading
  config <- load_variant_changes_config(config_dir)
  
  cat("Config file found:", config$config_file_found, "\n")
  cat("Enabled:", config$enabled, "\n")
  
  if (config$config_file_found) {
    cat("Excel file specified:", ifelse(is.null(config$excel_file), "No", config$excel_file), "\n")
    cat("Excel file found:", config$excel_file_found, "\n")
    cat("Sheet number:", ifelse(is.null(config$sheet_number), "Not specified", config$sheet_number), "\n")
  }
  
  if (!is.null(config$config_error)) {
    cat("Config error:", config$config_error, "\n")
  }
  
  # Test data loading if enabled
  if (config$enabled && config$excel_file_found) {
    cat("\n--- Testing Excel Data Loading ---\n")
    data <- load_variant_changes_data(config)
    
    if (!is.null(data$error)) {
      cat("Excel loading error:", data$error, "\n")
    } else {
      cat("Rows loaded:", data$row_count, "\n")
      cat("Columns:", paste(data$column_names, collapse = ", "), "\n")
    }
  }
  
  cat("=== Test Complete ===\n")
  return(config)
}

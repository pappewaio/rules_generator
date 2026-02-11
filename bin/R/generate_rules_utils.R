# Rules Generation Utilities
# Common utility functions for the rules generation workflow

#' Null-coalescing operator (returns right side if left side is NULL)
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Create version directory structure with nested step-wise support
#' @param output_dir Base output directory
#' @param version Version identifier (e.g., "85", "85A", "85B")
#' @return Path to version directory (either base or step directory)
create_version_directories <- function(output_dir, version) {
  # Parse version to determine if it's step-wise
  version_parts <- parse_version_string(version)
  base_version <- version_parts$base
  suffix <- version_parts$suffix
  
  # Base version directory (always create this first)
  base_version_dir <- file.path(output_dir, paste0("version_", base_version))
  
  # Determine actual working directory
  if (nchar(suffix) > 0) {
    # Step-wise version: create nested structure
    version_dir <- file.path(base_version_dir, paste0("step_", version))
  } else {
    # Standard version: use base directory
    version_dir <- base_version_dir
  }
  
  # Create the essential directories we actually use
  directories <- c(
    "logs",
    "analysis", 
    "outputs",
    "deployment",
    "inputs"  # Add inputs directory for input file archiving
  )
  
  for (dir in directories) {
    dir.create(file.path(version_dir, dir), recursive = TRUE, showWarnings = FALSE)
  }
  
  return(version_dir)
}

#' Copy input files to version directory for future comparison
#' @param version_dir Version directory path
#' @param gene_list_path Path to gene list file
#' @param variant_list_path Path to variant list file
#' @param variantcall_database_path Path to variantCall database file (optional)
#' @param logger Logger instance
copy_input_files <- function(version_dir, gene_list_path, variant_list_path, variantcall_database_path = NULL, logger) {
  inputs_dir <- file.path(version_dir, "inputs")
  
  tryCatch({
    # Copy gene list file
    if (file.exists(gene_list_path)) {
      gene_filename <- basename(gene_list_path)
      dest_gene_path <- file.path(inputs_dir, gene_filename)
      file.copy(gene_list_path, dest_gene_path, overwrite = TRUE)
      log_info(logger, paste("✅ Copied gene list to:", dest_gene_path))
    } else {
      log_warning(logger, paste("Gene list file not found:", gene_list_path))
    }
    
    # Copy variant list file
    if (file.exists(variant_list_path)) {
      variant_filename <- basename(variant_list_path)
      dest_variant_path <- file.path(inputs_dir, variant_filename)
      file.copy(variant_list_path, dest_variant_path, overwrite = TRUE)
      log_info(logger, paste("✅ Copied variant list to:", dest_variant_path))
    } else {
      log_warning(logger, paste("Variant list file not found:", variant_list_path))
    }
    
    # Copy variantCall database file (if provided)
    if (!is.null(variantcall_database_path) && file.exists(variantcall_database_path)) {
      variantcall_filename <- basename(variantcall_database_path)
      dest_variantcall_path <- file.path(inputs_dir, variantcall_filename)
      file.copy(variantcall_database_path, dest_variantcall_path, overwrite = TRUE)
      log_info(logger, paste("✅ Copied variantCall database to:", dest_variantcall_path))
    } else if (!is.null(variantcall_database_path)) {
      log_warning(logger, paste("VariantCall database file not found:", variantcall_database_path))
    }
    
    # Copy current config directory for historical reproducibility
    config_dest_dir <- file.path(inputs_dir, "config")
    if (!dir.exists(config_dest_dir)) {
      # Use same logic as load_simple_config to find the actual config used
      source_input_config_dir <- NULL
      
      # Extract version info from version_dir path like "out_rule_generation/version_44/step_44A"
      version_path_parts <- unlist(strsplit(version_dir, "/"))
      if (length(version_path_parts) >= 2) {
        version_id <- version_path_parts[length(version_path_parts)]  # e.g., "step_44A" or "version_44"
        base_version <- version_path_parts[length(version_path_parts) - 1]  # e.g., "version_44"
        
        if (grepl("^step_", version_id)) {
          # This is a step directory: generate_rules_input/version_44/step_44A/config
          source_input_config_dir <- file.path("generate_rules_input", base_version, version_id, "config")
        } else if (grepl("^version_", version_id)) {
          # This is a base version directory: generate_rules_input/version_44/config
          source_input_config_dir <- file.path("generate_rules_input", version_id, "config")
        }
      }
      
      # Config must come from the version-specific input directory - no fallback
      config_source_dir <- NULL
      
      if (!is.null(source_input_config_dir) && dir.exists(source_input_config_dir)) {
        config_source_dir <- source_input_config_dir
        log_info(logger, paste("Using step-specific config from:", source_input_config_dir))
      } else {
        stop(paste("No config directory found at:", source_input_config_dir,
                    "\nEach version must have its own config in generate_rules_input/version_XX/[step_XXx/]config/"))
      }
      
      if (dir.exists(config_source_dir)) {
        # Use system cp command for reliable recursive copying
        system_copy_cmd <- paste("cp -r", shQuote(config_source_dir), shQuote(inputs_dir))
        system_result <- system(system_copy_cmd)
        if (system_result == 0) {
          log_info(logger, paste("✅ Copied config to:", config_dest_dir))
        } else {
          log_warning(logger, "Failed to copy config directory")
        }
      } else {
        log_warning(logger, paste("Config directory not found:", config_source_dir))
      }
    } else {
      log_info(logger, "Config already exists in inputs directory")
    }
    
  }, error = function(e) {
    log_error(logger, paste("Failed to copy input files:", e$message))
  })
}

#' Simple configuration loader (replaces complex config system)
#' @param config_dir Configuration directory path
#' @return Simple configuration list
load_simple_config <- function(config_dir, version_dir = NULL) {
  # Determine which config directory to use
  input_config_dir <- NULL
  source_input_config_dir <- NULL
  
  if (!is.null(version_dir)) {
    # Check output directory structure (after copying)
    input_config_dir <- file.path(version_dir, "inputs", "config")
    
    # Also check source input directory structure (before copying)
    # Extract version from path like "out_rule_generation/version_44/step_44A"
    version_path_parts <- unlist(strsplit(version_dir, "/"))
    if (length(version_path_parts) >= 2) {
      version_id <- version_path_parts[length(version_path_parts)]  # e.g., "step_44A" or "version_44"
      base_version <- version_path_parts[length(version_path_parts) - 1]  # e.g., "version_44"
      
      if (grepl("^step_", version_id)) {
        # This is a step directory: generate_rules_input/version_44/step_44A/config
        source_input_config_dir <- file.path("generate_rules_input", base_version, version_id, "config")
      } else if (grepl("^version_", version_id)) {
        # This is a base version directory: generate_rules_input/version_44/config
        source_input_config_dir <- file.path("generate_rules_input", version_id, "config")
      }
    }
  }
  
  # Use only input-specific config - no fallback to default
  if (!is.null(input_config_dir) && dir.exists(input_config_dir)) {
    cat("Using input-specific config from:", input_config_dir, "\n")
    active_config_dir <- input_config_dir
  } else if (!is.null(source_input_config_dir) && dir.exists(source_input_config_dir)) {
    cat("Using source input config from:", source_input_config_dir, "\n")
    active_config_dir <- source_input_config_dir
  } else {
    stop(paste("Input-specific config directory not found. Checked:", 
               "\n  - Output config:", input_config_dir,
               "\n  - Source config:", source_input_config_dir,
               "\nThe system no longer uses default config. Please ensure input-specific config exists."))
  }
  
  # Load settings from settings.conf
  settings_file <- file.path(active_config_dir, "settings.conf")
  settings <- list(
    FORMAT_GQ_THRESHOLD = 16,  # default
    OUTPUT_PREFIX = "rules_file_from_carrier_list",
    FREQUENCY_RULE_SPECIAL = "&& QUAL >= 22.4 && format_DP >= 8 && format_GQ >= {FORMAT_GQ_THRESHOLD}"  # default
  )
  
  if (file.exists(settings_file)) {
    settings_lines <- readLines(settings_file)
    for (line in settings_lines) {
      if (grepl("^FORMAT_GQ_THRESHOLD=", line)) {
        settings$FORMAT_GQ_THRESHOLD <- as.numeric(sub("FORMAT_GQ_THRESHOLD=", "", line))
      }
      if (grepl("^OUTPUT_PREFIX=", line)) {
        settings$OUTPUT_PREFIX <- sub("OUTPUT_PREFIX=", "", line)
      }
      if (grepl("^FREQUENCY_RULE_SPECIAL=", line)) {
        settings$FREQUENCY_RULE_SPECIAL <- sub("FREQUENCY_RULE_SPECIAL=", "", line)
      }
    }
  }
  
  # Load column mappings from column_mappings.conf
  column_mappings_file <- file.path(active_config_dir, "column_mappings.conf")
  columns <- list()
  
  if (file.exists(column_mappings_file)) {
    mapping_lines <- readLines(column_mappings_file)
    for (line in mapping_lines) {
      # Skip comments and empty lines
      if (!grepl("^#", line) && nchar(trimws(line)) > 0) {
        if (grepl("=", line)) {
          parts <- strsplit(line, "=")[[1]]
          if (length(parts) == 2) {
            logical_name <- trimws(parts[1])
            actual_name <- trimws(parts[2])
            # Skip columns marked as not available
            if (actual_name != "NOT_AVAILABLE") {
              columns[[logical_name]] <- actual_name
            }
          }
        }
      }
    }
  }
  
  config <- list(
    settings = settings,
    columns = columns,
    config_source = active_config_dir
  )
  
  # Replace placeholders in settings (for FREQUENCY_RULE_SPECIAL)
  if (!is.null(settings$FREQUENCY_RULE_SPECIAL)) {
    replacements <- list(FORMAT_GQ_THRESHOLD = settings$FORMAT_GQ_THRESHOLD)
    config$settings$FREQUENCY_RULE_SPECIAL <- gsub("\\{FORMAT_GQ_THRESHOLD\\}", replacements$FORMAT_GQ_THRESHOLD, settings$FREQUENCY_RULE_SPECIAL)
  }
  
  # Load rules templates from the active config directory
  rules_dir <- file.path(active_config_dir, "rules")
  if (dir.exists(rules_dir)) {
    config$rules <- load_rules_templates(rules_dir)
  } else {
    config$rules <- list()
  }
  
  # Load special cases from the active config directory
  special_cases_dir <- file.path(active_config_dir, "special_cases")
  if (dir.exists(special_cases_dir)) {
    config$special_cases <- load_special_cases(special_cases_dir)
  } else {
    config$special_cases <- list()
  }
  
  # Note: Variant changes system removed - now using database-driven approach
  
  return(config)
}

#' Load rules templates (using existing config reader logic)
#' @param rules_dir Rules directory path
#' @return Rules templates list
load_rules_templates <- function(rules_dir) {
  # Use the existing config reader logic but simplified
  # Always use the main config reader regardless of input directory structure
  config_reader_path <- file.path("bin", "R", "config_reader.R")
  if (file.exists(config_reader_path)) {
    source(config_reader_path)
    tryCatch({
      # Load all rule files and structure them properly
      rules <- list()
      
      # Load frequency rules
      frequency_file <- file.path(rules_dir, "frequency_rules.txt")
      if (file.exists(frequency_file)) {
        rules$frequency_rules <- read_rule_templates(frequency_file)
      }
      
      # Load clinvar rules
      clinvar_file <- file.path(rules_dir, "clinvar_rules.txt")
      if (file.exists(clinvar_file)) {
        rules$clinvar_rules <- read_rule_templates(clinvar_file)
      }
      
      # Load non-splice position rules
      non_splice_pos_file <- file.path(rules_dir, "non_splice_pos_rules.txt")
      if (file.exists(non_splice_pos_file)) {
        rules$non_splice_pos_rules <- read_rule_templates(non_splice_pos_file)
      }
      
      # Load non-splice rules
      non_splice_file <- file.path(rules_dir, "non_splice_rules.txt")
      if (file.exists(non_splice_file)) {
        rules$non_splice_rules <- read_rule_templates(non_splice_file)
      }
      
      # Load spliceai rules
      spliceai_file <- file.path(rules_dir, "spliceai_rules.txt")
      if (file.exists(spliceai_file)) {
        rules$spliceai_rules <- read_rule_templates(spliceai_file)
      }
      
      return(rules)
    }, error = function(e) {
      warning(paste("Failed to load rules templates:", e$message))
      return(list())
    })
  } else {
    warning("Config reader not found, returning empty rules")
    return(list())
  }
}

#' Load special cases (using existing config reader logic)  
#' @param special_cases_dir Special cases directory path
#' @return Special cases list
load_special_cases <- function(special_cases_dir) {
  # Use the existing config reader logic but simplified
  # Always use the main config reader regardless of input directory structure
  config_reader_path <- file.path("bin", "R", "config_reader.R")
  if (file.exists(config_reader_path)) {
    source(config_reader_path)
    tryCatch({
      special_cases <- list()
      
      # Load gene exclusions
      gene_exclusions_file <- file.path(special_cases_dir, "gene_exclusions.txt")
      if (file.exists(gene_exclusions_file)) {
        special_cases$gene_exclusions <- read_gene_exclusions(gene_exclusions_file)
      }
      
      # Load position exclusions  
      position_exclusions_file <- file.path(special_cases_dir, "position_exclusions.txt")
      if (file.exists(position_exclusions_file)) {
        special_cases$position_exclusions <- read_position_exclusions(position_exclusions_file)
      }
      
      # Load ClinVar benign genes
      clinvar_file <- file.path(special_cases_dir, "clinvar_benign_exclusions.txt")
      if (file.exists(clinvar_file)) {
        special_cases$clinvar_benign_genes <- read_clinvar_benign_genes(clinvar_file)
      }
      
      # Load special disease rules
      special_disease_file <- file.path(special_cases_dir, "special_disease_rules.txt")
      if (file.exists(special_disease_file)) {
        special_cases$special_disease_rules <- read_special_disease_rules(special_disease_file)
      }
      
      # Load validation rules
      validation_file <- file.path(special_cases_dir, "validation_rules.txt")
      if (file.exists(validation_file)) {
        special_cases$validation_rules <- read_validation_rules(validation_file)
      }
      
      return(special_cases)
    }, error = function(e) {
      warning(paste("Failed to load special cases:", e$message))
      return(list())
    })
  } else {
    warning("Config reader not found, returning empty special cases")
    return(list())
  }
}

#' Validate required input files exist
#' @param master_gene_list Path to master gene list
#' @param variant_list Path to variant list
#' @param variantcall_database Path to variantCall database file
#' @return TRUE if valid, stops execution if not
validate_input_files <- function(master_gene_list, variant_list, variantcall_database = NULL) {
  if (!file.exists(master_gene_list)) {
    stop("Master gene list file does not exist: ", master_gene_list)
  }
  
  if (!file.exists(variant_list)) {
    stop("Variant list file does not exist: ", variant_list)
  }
  
  if (!is.null(variantcall_database) && !file.exists(variantcall_database)) {
    stop("VariantCall database file does not exist: ", variantcall_database)
  }
  
  return(TRUE)
}

#' Generate deployment script (simplified)
#' @param version_dir Version directory path
#' @param rules_version Rules version number
generate_deployment_script <- function(version_dir, rules_version) {
  deployment_script_path <- file.path(version_dir, "deployment", "deploy_to_s3.sh")
  deployment_script_content <- sprintf('#!/bin/bash

# S3 Deployment Script for Rules Version %s
# Generated automatically by Rules Generation Framework

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
S3_SCRIPT="$FRAMEWORK_DIR/deployment/upload_to_s3.sh"

echo "Deploying Rules Version %s to S3..."
echo "Output Directory: $(dirname "$SCRIPT_DIR")"

if [[ ! -f "$S3_SCRIPT" ]]; then
    echo "Error: S3 deployment script not found: $S3_SCRIPT"
    exit 1
fi

# Pass all arguments to the main S3 script, but set the output directory and rules version
"$S3_SCRIPT" --output-dir "$(dirname "$SCRIPT_DIR")" --rules-version %s "$@"
', rules_version, rules_version, rules_version)
  
  writeLines(deployment_script_content, deployment_script_path)
  Sys.chmod(deployment_script_path, mode = "755")
  
  return(deployment_script_path)
}

#' Create version metadata file with lineage tracking
#' @param version_dir Version directory path
#' @param config Configuration object with version info
#' @param logger Logger instance
create_version_metadata <- function(version_dir, config, logger) {
  tryCatch({
    # Parse version to extract base and suffix
    version_parts <- parse_version_string(config$rules_version)
    
    # Determine version lineage
    previous_version <- extract_compare_version(config$compare_with)
    lineage_info <- determine_version_lineage(config$rules_version, previous_version, config$output_dir)
    
    # Create metadata
    metadata <- list(
      version = config$rules_version,
      version_type = ifelse(nchar(version_parts$suffix) > 0, "stepwise", "standard"),
      base_version = version_parts$base,
      suffix = version_parts$suffix,
      comment = config$version_comment %||% "",
      created_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
      created_by = Sys.info()[["user"]],
      lineage = lineage_info,
      previous_version = previous_version,
      input_files = list(
        master_gene_list = basename(config$master_gene_list),
        variant_list = basename(config$variant_list),
        variantcall_database = if (!is.null(config$variantcall_database)) basename(config$variantcall_database) else NULL
      )
    )
    
    # Write metadata JSON
    metadata_file <- file.path(version_dir, "version_metadata.json")
    writeLines(jsonlite::toJSON(metadata, pretty = TRUE, auto_unbox = TRUE), metadata_file)
    
    log_info(logger, paste("✅ Version metadata created:", metadata_file))
    
    # Log lineage information
    if (length(lineage_info$stepwise_sequence) > 0) {
      log_info(logger, paste("📋 Version lineage:", paste(lineage_info$stepwise_sequence, collapse = " → ")))
    }
    if (nchar(metadata$comment) > 0) {
      log_info(logger, paste("💬 Version comment:", metadata$comment))
    }
    
  }, error = function(e) {
    log_error(logger, paste("Failed to create version metadata:", e$message))
  })
}

#' Parse version string into base number and suffix
#' @param version_string Version string (e.g., "45A", "76")
#' @return List with base and suffix components
parse_version_string <- function(version_string) {
  if (grepl("^([0-9]+)([A-Za-z]*)$", version_string)) {
    matches <- regmatches(version_string, regexec("^([0-9]+)([A-Za-z]*)$", version_string))[[1]]
    return(list(base = matches[2], suffix = matches[3]))
  } else {
    return(list(base = version_string, suffix = ""))
  }
}

#' Extract version number from compare_with string
#' @param compare_with Compare with string (e.g., "version_75", "75A")
#' @return Version string or NULL
extract_compare_version <- function(compare_with) {
  if (is.null(compare_with)) return(NULL)
  
  # Remove "version_" prefix if present
  if (grepl("^version_", compare_with)) {
    return(gsub("^version_", "", compare_with))
  }
  return(compare_with)
}

#' Determine version lineage and stepwise sequence (updated for nested structure)
#' @param current_version Current version string
#' @param previous_version Previous version string (if any)
#' @param output_dir Output directory to scan for versions
#' @return List with lineage information
determine_version_lineage <- function(current_version, previous_version, output_dir) {
  current_parts <- parse_version_string(current_version)
  base_num <- current_parts$base
  stepwise_sequence <- c()
  
  # Check if base version directory exists
  base_version_dir <- file.path(output_dir, paste0("version_", base_num))
  if (!dir.exists(base_version_dir)) {
    return(list(
      is_stepwise = nchar(current_parts$suffix) > 0,
      base_version = base_num,
      stepwise_sequence = stepwise_sequence,
      total_steps = 0
    ))
  }
  
  # If this is a stepwise version (has suffix), find all step directories in base
  if (nchar(current_parts$suffix) > 0) {
    # Find all step directories within the base version
    step_dirs <- list.dirs(base_version_dir, recursive = FALSE, full.names = FALSE)
    step_pattern <- paste0("^step_", base_num, "([A-Za-z]*)$")
    matching_steps <- step_dirs[grepl(step_pattern, step_dirs)]
    
    # Extract and sort suffixes
    suffixes <- c()
    for (step_dir in matching_steps) {
      matches <- regmatches(step_dir, regexec(step_pattern, step_dir))[[1]]
      if (length(matches) >= 2) {
        suffix <- matches[2]
        suffixes <- c(suffixes, suffix)
      }
    }
    
    # Check if base version has content (not just a container for steps)
    if (file.exists(file.path(base_version_dir, "version_metadata.json"))) {
      suffixes <- c("", suffixes)  # Add empty suffix for base version
    }
    
    # Sort suffixes (empty string first, then alphabetically)
    suffixes <- sort(unique(suffixes))
    
    # Build stepwise sequence up to current version
    current_suffix <- current_parts$suffix
    for (suffix in suffixes) {
      if (suffix == current_suffix) break
      version_name <- ifelse(nchar(suffix) == 0, base_num, paste0(base_num, suffix))
      stepwise_sequence <- c(stepwise_sequence, version_name)
    }
    stepwise_sequence <- c(stepwise_sequence, current_version)
  }
  
  return(list(
    is_stepwise = nchar(current_parts$suffix) > 0,
    base_version = base_num,
    stepwise_sequence = stepwise_sequence,
    total_steps = length(stepwise_sequence)
  ))
} 
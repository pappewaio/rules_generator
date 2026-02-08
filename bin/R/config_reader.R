# Configuration Reader Module
# Functions to read and parse configuration files using base R only

#' Read main settings from config file
#' @param config_file Path to settings.conf file
#' @return Named list of configuration settings
read_settings <- function(config_file) {
  if (!file.exists(config_file)) {
    stop(paste("Configuration file not found:", config_file))
  }
  
  lines <- readLines(config_file)
  # Remove comments and empty lines
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  
  config <- list()
  for (line in lines) {
    if (grepl("=", line)) {
      parts <- strsplit(line, "=", fixed = TRUE)[[1]]
      if (length(parts) == 2) {
        key <- trimws(parts[1])
        value <- trimws(parts[2])
        
        # Convert specific values to appropriate types
        if (value %in% c("true", "TRUE")) {
          value <- TRUE
        } else if (value %in% c("false", "FALSE")) {
          value <- FALSE
        } else if (grepl("^[0-9]+$", value)) {
          value <- as.numeric(value)
        }
        
        config[[key]] <- value
      }
    }
  }
  
  return(config)
}

#' Read column mappings from config file
#' @param mapping_file Path to column_mappings.conf file
#' @return Named list of column mappings (logical_name -> actual_column_name)
read_column_mappings <- function(mapping_file) {
  if (!file.exists(mapping_file)) {
    stop(paste("Column mapping file not found:", mapping_file))
  }
  
  lines <- readLines(mapping_file)
  # Remove comments and empty lines
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  
  mappings <- list()
  for (line in lines) {
    if (grepl("=", line)) {
      parts <- strsplit(line, "=", fixed = TRUE)[[1]]
      if (length(parts) == 2) {
        logical_name <- trimws(parts[1])
        actual_column <- trimws(parts[2])
        mappings[[logical_name]] <- actual_column
      }
    }
  }
  
  return(mappings)
}

#' Get actual column name from logical name using mappings
#' @param logical_name Logical column name (e.g., "GENE_NAME")
#' @param mappings Column mappings list
#' @return Actual column name from the data
get_column_name <- function(logical_name, mappings, allow_missing = FALSE) {
  if (logical_name %in% names(mappings)) {
    return(mappings[[logical_name]])
  } else {
    if (allow_missing) {
      return(NULL)
    } else {
      stop(paste("Column mapping not found for:", logical_name))
    }
  }
}

#' Safely get column data using mappings
#' @param data Data frame
#' @param logical_name Logical column name
#' @param mappings Column mappings list
#' @return Column data
get_column_data <- function(data, logical_name, mappings) {
  actual_column <- get_column_name(logical_name, mappings)
  
  if (!(actual_column %in% names(data))) {
    stop(paste("Column not found in data:", actual_column, "for logical name:", logical_name))
  }
  
  return(data[, actual_column])
}

#' Set column data using mappings
#' @param data Data frame
#' @param logical_name Logical column name
#' @param mappings Column mappings list
#' @param values Values to set
#' @return Modified data frame
set_column_data <- function(data, logical_name, mappings, values) {
  actual_column <- get_column_name(logical_name, mappings)
  data[, actual_column] <- values
  return(data)
}

#' Read rule templates from file
#' @param rule_file Path to rule template file
#' @return Character vector of rule templates
read_rule_templates <- function(rule_file) {
  if (!file.exists(rule_file)) {
    stop(paste("Rule file not found:", rule_file))
  }
  
  lines <- readLines(rule_file)
  # Remove comments and empty lines
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  # Remove only leading whitespace to preserve trailing spaces for proper concatenation
  lines <- sub("^\\s+", "", lines)
  
  return(lines)
}

#' Read gene exclusions from file
#' @param exclusion_file Path to gene exclusions file
#' @return Named list with exclusion rules for each gene
read_gene_exclusions <- function(exclusion_file) {
  if (!file.exists(exclusion_file)) {
    stop(paste("Gene exclusions file not found:", exclusion_file))
  }
  
  lines <- readLines(exclusion_file)
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  
  exclusions <- list()
  for (line in lines) {
    if (grepl(",", line)) {
      parts <- strsplit(line, ",", fixed = TRUE)[[1]]
      if (length(parts) == 2) {
        gene <- trimws(parts[1])
        rule <- trimws(parts[2])
        exclusions[[gene]] <- rule
      }
    }
  }
  
  return(exclusions)
}

#' Read position exclusions from file
#' @param position_file Path to position exclusions file
#' @return Data frame with gene, rule_pattern, and exclusion_conditions
read_position_exclusions <- function(position_file) {
  if (!file.exists(position_file)) {
    stop(paste("Position exclusions file not found:", position_file))
  }
  
  lines <- readLines(position_file)
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  
  result <- data.frame(
    gene = character(0),
    rule_pattern = character(0),
    exclusion_conditions = character(0),
    stringsAsFactors = FALSE
  )
  
  for (line in lines) {
    parts <- strsplit(line, ",", fixed = TRUE)[[1]]
    if (length(parts) == 3) {
      result <- rbind(result, data.frame(
        gene = trimws(parts[1]),
        rule_pattern = trimws(parts[2]),
        exclusion_conditions = trimws(parts[3]),
        stringsAsFactors = FALSE
      ))
    }
  }
  
  return(result)
}

#' Read ClinVar benign exclusion genes
#' @param benign_file Path to ClinVar benign exclusions file
#' @return Character vector of gene names
read_clinvar_benign_genes <- function(benign_file) {
  if (!file.exists(benign_file)) {
    stop(paste("ClinVar benign exclusions file not found:", benign_file))
  }
  
  lines <- readLines(benign_file)
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  genes <- trimws(lines)
  
  return(genes)
}

#' Replace placeholders in rule templates
#' @param rules Character vector of rule templates
#' @param replacements Named list of placeholder replacements
#' @return Character vector of rules with placeholders replaced
replace_placeholders <- function(rules, replacements) {
  result <- rules
  
  for (placeholder in names(replacements)) {
    pattern <- paste0("\\{", placeholder, "\\}")
    replacement <- replacements[[placeholder]]
    result <- gsub(pattern, replacement, result)
  }
  
  return(result)
}

#' Load all configuration files
#' @param config_dir Path to configuration directory
#' @return Named list containing all configuration data
load_configuration <- function(config_dir) {
  config <- list()
  
  # Read main settings
  settings_file <- file.path(config_dir, "settings.conf")
  config$settings <- read_settings(settings_file)
  
  # Load rule templates
  rules_config <- list()
  
  # Load frequency rules
  frequency_rules_file <- file.path(config_dir, "rules", "frequency_rules.txt")
  if (file.exists(frequency_rules_file)) {
    lines <- readLines(frequency_rules_file)
    lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
    rules_config$frequency_rules <- sub("^\\s+", "", lines)
  }
  
  # Load non-splice position rules
  non_splice_pos_file <- file.path(config_dir, "rules", "non_splice_pos_rules.txt")
  if (file.exists(non_splice_pos_file)) {
    lines <- readLines(non_splice_pos_file)
    lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
    rules_config$non_splice_pos_rules <- sub("^\\s+", "", lines)
  }
  
  # Load non-splice rules
  non_splice_file <- file.path(config_dir, "rules", "non_splice_rules.txt")
  if (file.exists(non_splice_file)) {
    lines <- readLines(non_splice_file)
    lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
    rules_config$non_splice_rules <- sub("^\\s+", "", lines)
  }
  
  # Load ClinVar rules
  clinvar_file <- file.path(config_dir, "rules", "clinvar_rules.txt")
  if (file.exists(clinvar_file)) {
    lines <- readLines(clinvar_file)
    lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
    rules_config$clinvar_rules <- sub("^\\s+", "", lines)
  }
  
  # Load SpliceAI rules
  spliceai_file <- file.path(config_dir, "rules", "spliceai_rules.txt")
  if (file.exists(spliceai_file)) {
    lines <- readLines(spliceai_file)
    lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
    rules_config$spliceai_rules <- sub("^\\s+", "", lines)
  }
  
  # Read special cases
  special_dir <- file.path(config_dir, "special_cases")
  config$special_cases <- list(
    gene_exclusions = read_gene_exclusions(file.path(special_dir, "gene_exclusions.txt")),
    position_exclusions = read_position_exclusions(file.path(special_dir, "position_exclusions.txt")),
    clinvar_benign_genes = read_clinvar_benign_genes(file.path(special_dir, "clinvar_benign_exclusions.txt")),
    validation_rules = read_validation_rules(file.path(special_dir, "validation_rules.txt")),
    special_disease_rules = read_special_disease_rules(file.path(special_dir, "special_disease_rules.txt"))
  )
  
  # Read column mappings
  column_mappings_file <- file.path(config_dir, "column_mappings.conf")
  config$column_mappings <- read_column_mappings(column_mappings_file)
  
  # Replace placeholders in rule templates
  replacements <- list(
    FORMAT_GQ_THRESHOLD = config$settings$FORMAT_GQ_THRESHOLD
  )
  
  # Assign rules_config to config$rules
  config$rules <- rules_config
  
  for (rule_type in names(rules_config)) {
    config$rules[[rule_type]] <- replace_placeholders(rules_config[[rule_type]], replacements)
  }
  
  # Also replace placeholders in settings (for FREQUENCY_RULE_SPECIAL)
  if (!is.null(config$settings$FREQUENCY_RULE_SPECIAL)) {
    config$settings$FREQUENCY_RULE_SPECIAL <- replace_placeholders(config$settings$FREQUENCY_RULE_SPECIAL, replacements)
  }
  
  return(config)
} 

#' Read validation rules from file
#' @param validation_file Path to validation rules file
#' @return Data frame with validation rules
read_validation_rules <- function(validation_file) {
  if (!file.exists(validation_file)) {
    stop(paste("Validation rules file not found:", validation_file))
  }
  
  lines <- readLines(validation_file)
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  
  result <- data.frame(
    disease = character(0),
    gene = character(0),
    chr = character(0),
    pos = numeric(0),
    ref = character(0),
    alt = character(0),
    cid = numeric(0),
    stringsAsFactors = FALSE
  )
  
  for (line in lines) {
    parts <- strsplit(line, ",", fixed = TRUE)[[1]]
    if (length(parts) == 7) {
      result <- rbind(result, data.frame(
        disease = trimws(parts[1]),
        gene = trimws(parts[2]),
        chr = trimws(parts[3]),
        pos = as.numeric(trimws(parts[4])),
        ref = trimws(parts[5]),
        alt = trimws(parts[6]),
        cid = as.numeric(trimws(parts[7])),
        stringsAsFactors = FALSE
      ))
    }
  }
  
  return(result)
}

#' Read special disease rules from file
#' @param special_file Path to special disease rules file
#' @return Data frame with special disease rules
read_special_disease_rules <- function(special_file) {
  if (!file.exists(special_file)) {
    stop(paste("Special disease rules file not found:", special_file))
  }
  
  lines <- readLines(special_file)
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  
  result <- data.frame(
    gene = character(0),
    disease = character(0),
    rule_type = character(0),
    hgvs_variant = character(0),
    stringsAsFactors = FALSE
  )
  
  for (line in lines) {
    parts <- strsplit(line, ",", fixed = TRUE)[[1]]
    if (length(parts) == 4) {
      result <- rbind(result, data.frame(
        gene = trimws(parts[1]),
        disease = trimws(parts[2]),
        rule_type = trimws(parts[3]),
        hgvs_variant = trimws(parts[4]),
        stringsAsFactors = FALSE
      ))
    }
  }
  
  return(result)
} 
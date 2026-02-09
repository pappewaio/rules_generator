# Rule Generator Module
# This module implements the core rule generation logic preserving all features from the original script

# Source dependencies
if (!exists("logger")) {
  source(file.path(dirname(parent.frame(2)$ofile), "logger.R"))
}

#' Load and process Excel files
#' @param master_gene_list Path to master gene list Excel file
#' @param variant_list Path to variant list Excel file
#' @param column_mappings Column mappings configuration
#' @param logger Logger instance
#' @return List containing processed gene_list and variant_list
#' Filter out entries with missing essential information for rule generation
#' @param gene_list Raw gene list data frame
#' @param output_dir Output directory for filtered entries file
#' @param logger Logger instance
#' @return List with cleaned_data and filtering_stats
filter_incomplete_entries <- function(gene_list, output_dir, logger) {
  log_info(logger, "Filtering out entries with missing essential information...")
  
  # Define essential fields for rule generation
  essential_fields <- c("Gene", "Disease", "Inheritance", "Variants.To.Find")
  
  # Initialize filtering tracking
  filtered_entries <- data.frame()
  exclusion_reasons <- character()
  
  # Vectorized approach: check all fields at once for all rows
  # Create boolean matrix for missing values across all essential fields
  missing_matrix <- matrix(FALSE, nrow = nrow(gene_list), ncol = length(essential_fields))
  colnames(missing_matrix) <- essential_fields
  
  # Check each essential field vectorized
  for (field in essential_fields) {
    if (field %in% colnames(gene_list)) {
      field_values <- gene_list[[field]]
      # Vectorized check for missing, empty, or whitespace-only values
      missing_matrix[, field] <- is.na(field_values) | field_values == "" | trimws(field_values) == ""
    } else {
      # If column doesn't exist, mark all rows as missing for this field
      missing_matrix[, field] <- TRUE
    }
  }
  
  # Find rows with any missing essential fields
  rows_with_missing <- which(rowSums(missing_matrix) > 0)
  
  # Process only the rows that have missing fields
  if (length(rows_with_missing) > 0) {
    for (i in rows_with_missing) {
      # Get missing fields for this row
      missing_fields_for_row <- essential_fields[missing_matrix[i, ]]
      
      # Add "(column not found)" suffix for fields where column doesn't exist
      missing_fields_formatted <- ifelse(
        missing_fields_for_row %in% colnames(gene_list),
        missing_fields_for_row,
        paste0(missing_fields_for_row, " (column not found)")
      )
      
      exclusion_reason <- paste("Missing essential field(s):", paste(missing_fields_formatted, collapse = ", "))
      
      # Create filtered entry record
      filtered_entry <- data.frame(
        Row_Number = i,
        Gene = ifelse("Gene" %in% colnames(gene_list), as.character(gene_list[i, "Gene"]), "N/A"),
        Disease = ifelse("Disease" %in% colnames(gene_list), as.character(gene_list[i, "Disease"]), "N/A"),
        Inheritance = ifelse("Inheritance" %in% colnames(gene_list), as.character(gene_list[i, "Inheritance"]), "N/A"),
        Variants_To_Find = ifelse("Variants.To.Find" %in% colnames(gene_list), as.character(gene_list[i, "Variants.To.Find"]), "N/A"),
        Exclusion_Reason = exclusion_reason,
        stringsAsFactors = FALSE
      )
      
      # Replace NA values with "[MISSING]" for better readability
      filtered_entry[is.na(filtered_entry)] <- "[MISSING]"
      filtered_entry[filtered_entry == ""] <- "[EMPTY]"
      
      filtered_entries <- rbind(filtered_entries, filtered_entry)
    }
  }
  
  # Create clean dataset (exclude incomplete entries)
  if (nrow(filtered_entries) > 0) {
    incomplete_rows <- filtered_entries$Row_Number
    cleaned_gene_list <- gene_list[-incomplete_rows, ]
    log_info(logger, paste("Filtered out", nrow(filtered_entries), "incomplete entries"))
    log_info(logger, paste("Retained", nrow(cleaned_gene_list), "complete entries for rule generation"))
  } else {
    cleaned_gene_list <- gene_list
    log_info(logger, "No incomplete entries found - all entries have essential information")
  }
  
  # Save filtered entries to output file
  if (nrow(filtered_entries) > 0) {
    filtered_file <- file.path(output_dir, "filtered_incomplete_entries.tsv")
    write.table(filtered_entries, filtered_file, sep = "\t", row.names = FALSE, quote = FALSE)
    log_info(logger, paste("Filtered entries saved to:", filtered_file))
  }
  
  # Create filtering statistics
  filtering_stats <- list(
    total_entries = nrow(gene_list),
    complete_entries = nrow(cleaned_gene_list),
    filtered_entries = nrow(filtered_entries),
    filtering_details = filtered_entries
  )
  
  return(list(
    cleaned_data = cleaned_gene_list,
    filtering_stats = filtering_stats
  ))
}

load_excel_files <- function(master_gene_list, variant_list, column_mappings, logger) {
  log_info(logger, "Loading Excel files")
  
  # Track file existence for accurate reporting
  master_gene_list_exists <- file.exists(master_gene_list)
  variant_list_exists <- file.exists(variant_list)
  
  if (!master_gene_list_exists) {
    log_error(logger, paste("Master gene list file not found:", master_gene_list))
  }
  if (!variant_list_exists) {
    log_error(logger, paste("Variant list file not found:", variant_list))
  }
  
  # Helper function to safely get mapped column data
  safe_get_column <- function(data, logical_name, mappings, default_value = NA, required = FALSE) {
    if (logical_name %in% names(mappings)) {
      actual_column <- mappings[[logical_name]]
      if (actual_column %in% names(data)) {
        return(data[, actual_column])
      } else {
        # Column mapping exists but actual column not found in data
        if (required) {
          log_error(logger, paste("CRITICAL ERROR: Required column not found in data!"))
          log_error(logger, paste("  Logical name:", logical_name))
          log_error(logger, paste("  Expected column name:", actual_column))
          log_error(logger, paste("  Available columns:", paste(names(data), collapse = ", ")))
          stop(paste("Required column not found:", actual_column, "for logical name:", logical_name))
        } else {
          log_warning(logger, paste("Optional column not found:", actual_column, "for logical name:", logical_name, "- using default"))
        }
      }
    } else {
      # No column mapping found
      if (required) {
        log_error(logger, paste("CRITICAL ERROR: No column mapping found for required logical name:", logical_name))
        log_error(logger, paste("  Available mappings:", paste(names(mappings), collapse = ", ")))
        stop(paste("No column mapping found for required logical name:", logical_name))
      } else {
        log_warning(logger, paste("No column mapping found for optional logical name:", logical_name, "- using default"))
      }
    }
    return(rep(default_value, nrow(data)))
  }
  
  # Load master gene list (only if file exists)
  if (master_gene_list_exists) {
    gene_list_raw <- openxlsx::read.xlsx(master_gene_list, sheet = 1, colNames = TRUE, startRow = 1)
    log_info(logger, paste("Loaded", nrow(gene_list_raw), "rows from master gene list"))
  } else {
    gene_list_raw <- data.frame()  # Empty data frame if file doesn't exist
    log_warning(logger, "Using empty gene list due to missing file")
  }
  
  # Load variant list (only if file exists)
  if (variant_list_exists) {
    variant_list_raw <- openxlsx::read.xlsx(variant_list, sheet = 3, colNames = TRUE)
    log_info(logger, paste("Loaded", nrow(variant_list_raw), "rows from variant list"))
  } else {
    variant_list_raw <- data.frame()  # Empty data frame if file doesn't exist
    log_warning(logger, "Using empty variant list due to missing file")
  }
  
  # === CENTRALIZED COLUMN MAPPING - ONE PLACE ONLY ===
  # Create standardized gene list with consistent column names
  gene_list <- data.frame(
    Disease = safe_get_column(gene_list_raw, "DISEASE_NAME", column_mappings, "Unknown", required = TRUE),
    Gene = safe_get_column(gene_list_raw, "GENE_NAME", column_mappings, "Unknown", required = TRUE),
    Carrier = safe_get_column(gene_list_raw, "CARRIER_STATUS", column_mappings, FALSE, required = TRUE),
    Complex = safe_get_column(gene_list_raw, "COMPLEX_STATUS", column_mappings, FALSE, required = TRUE),
    Variants.To.Find = safe_get_column(gene_list_raw, "VARIANTS_TO_FIND", column_mappings, "Unknown", required = TRUE),
    Report.Comms.Name = safe_get_column(gene_list_raw, "COMMS_NAME", column_mappings, "Unknown", required = TRUE),
    Inheritance = safe_get_column(gene_list_raw, "INHERITANCE", column_mappings, "Unknown", required = TRUE),
    Terminal.Cutoff.Missense = safe_get_column(gene_list_raw, "TERMINAL_CUTOFF_MISSENSE", column_mappings, NA, required = TRUE),
    Terminal.Cutoff.Frameshift = safe_get_column(gene_list_raw, "TERMINAL_CUTOFF_FRAMESHIFT", column_mappings, NA, required = TRUE),
    Chromosome = safe_get_column(gene_list_raw, "CHROMOSOME", column_mappings, "Unknown", required = FALSE),
    stringsAsFactors = FALSE
  )
  
  # Standardize "See supplemental variant list" entries
  gene_list[gene_list$Variants.To.Find %in% c("see supplemental variant sheet", "see supplemental variant list"), "Variants.To.Find"] <- "See supplemental variant list"
  
  # Check for duplicate lines (same Disease+Gene+Variants.To.Find+Inheritance = true duplicate)
  duplicate_check <- duplicated(apply(gene_list[, c("Disease", "Gene", "Variants.To.Find", "Inheritance")], 1, paste, collapse = "_"))
  if (any(duplicate_check)) {
    log_error(logger, "True duplicate rows found (same Disease+Gene+Variants.To.Find+Inheritance):")
    print(gene_list[duplicate_check, c("Disease", "Gene", "Variants.To.Find", "Inheritance")])
    stop("double lines!")
  }
  
  # Create standardized variant list with consistent column names
  # First filter by omit column
  if ("VARIANT_OMIT" %in% names(column_mappings)) {
    omit_col <- column_mappings[["VARIANT_OMIT"]]
    if (omit_col %in% names(variant_list_raw)) {
      if (!all(unique(variant_list_raw[, omit_col]) %in% c("YES", "NO"))) {
        stop("Problem with omit status")
      }
      variant_list_raw <- variant_list_raw[!variant_list_raw[, omit_col] %in% "YES", ]
    }
  }
  
  variant_list_data <- data.frame(
    Gene = safe_get_column(variant_list_raw, "VARIANT_GENE", column_mappings, "Unknown", required = TRUE),
    Variant = safe_get_column(variant_list_raw, "VARIANT_NUCLEOTIDE", column_mappings, "Unknown", required = TRUE),
    Disease = safe_get_column(variant_list_raw, "VARIANT_DISEASE", column_mappings, "Unknown", required = FALSE),
    Position = safe_get_column(variant_list_raw, "VARIANT_POSITION", column_mappings, NA, required = FALSE),
    Ref = safe_get_column(variant_list_raw, "VARIANT_REF", column_mappings, "Unknown", required = FALSE),
    Alt = safe_get_column(variant_list_raw, "VARIANT_ALT", column_mappings, "Unknown", required = FALSE),
    Consequence = safe_get_column(variant_list_raw, "VARIANT_CONSEQUENCE", column_mappings, "Unknown", required = FALSE),
    stringsAsFactors = FALSE
  )
  
  # Create cutoff list with standardized column names (only if terminal cutoff data exists)
  cutoff_list <- data.frame(
    Gene = gene_list$Gene,
    Terminal.Cutoff.Missense = gene_list$Terminal.Cutoff.Missense,
    Terminal.Cutoff.Frameshift = gene_list$Terminal.Cutoff.Frameshift,
    stringsAsFactors = FALSE
  )
  
  # Remove duplicates and NAs from cutoff list
  cutoff_list <- cutoff_list[!duplicated(cutoff_list$Gene), ]
  cutoff_list <- cutoff_list[!is.na(cutoff_list$Gene) & cutoff_list$Gene != "Unknown", ]
  if (nrow(cutoff_list) > 0) {
    rownames(cutoff_list) <- cutoff_list$Gene
  }
  
  log_info(logger, paste("Processed", nrow(gene_list), "gene entries"))
  log_info(logger, paste("Processed", nrow(variant_list_data), "variant entries"))
  log_info(logger, paste("Created cutoff list with", nrow(cutoff_list), "genes"))
  
  return(list(
    gene_list = gene_list,
    variant_list = variant_list_data,
    cutoff_list = cutoff_list,
    # File existence tracking for accurate reporting
    file_info = list(
      master_gene_list_path = master_gene_list,
      master_gene_list_exists = master_gene_list_exists,
      variant_list_path = variant_list,
      variant_list_exists = variant_list_exists
    )
  ))
}



#' Generate exclusion zone rule for a gene
#' @param gene Gene symbol
#' @param cutoff_list Cutoff list
#' @return String with exclusion rule or empty string
exclusion_rule_function <- function(gene, cutoff_list) {
  exclusion_zone_rule <- ""
  if (gene %in% rownames(cutoff_list)) {
    exclusion_zone_rule <- paste0(" && POS ", cutoff_list[gene, "Terminal.Cutoff.Missense"], " ")
  }
  return(exclusion_zone_rule)
}

#' Generate rules for a single gene
#' @param gene_info Single row from gene list
#' @param cutoff_list Terminal cutoff list
#' @param variant_list_data Variant list data
#' @param config Configuration object
#' @param cID Current compound ID (passed by reference)
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

#' Process variant changes after main rule generation
#' @param config Configuration object containing variant changes data
#' @param cID_lookup Lookup table for existing cID assignments
#' @param output_file Output file connection
#' @param logger Logger instance
#' @return List with total_rules_added and updated_cID_lookup
#' Parse variant name from variantCall database format
#' 
#' Converts variant names like "chr11_17397055_C_T" into genomic coordinates
#' 
#' @param variant_name String like "chr11_17397055_C_T"
#' @return List with chrom, pos, ref, alt components, or NULL if parsing fails
parse_variant_name_from_variantcall <- function(variant_name) {
  # Handle missing or empty variant names
  if (is.na(variant_name) || variant_name == "" || is.null(variant_name)) {
    return(NULL)
  }
  
  # Split by underscore (format: chr11_17397055_C_T)
  tryCatch({
    parts <- strsplit(variant_name, "_")[[1]]
    
    # Need at least 4 parts: chr, pos, ref, alt
    if (length(parts) < 4) {
      return(NULL)
    }
    
    # Extract components
    chrom <- parts[1]  # e.g., "chr11"
    pos <- as.numeric(parts[2])  # e.g., 17397055
    ref <- parts[3]  # e.g., "C"
    alt <- parts[4]  # e.g., "T"
    
    # Handle complex variants where alt might have multiple parts
    if (length(parts) > 4) {
      alt <- paste(parts[4:length(parts)], collapse = "_")
    }
    
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

#' Process variantCall database and generate rules for approved variants
#' 
#' This function processes the variantCall database to generate specific variant rules
#' for all variants with "Approved" status, replacing the old config-based approach.
#' 
#' @param variantcall_data Data frame containing variantCall database
#' @param cID_lookup Lookup table for existing cID assignments
#' @param output_file Output file connection
#' @param config Configuration object
#' @param logger Logger instance
#' @return List with total_rules_added and updated_cID_lookup
process_variantcall_database <- function(variantcall_data, cID_lookup, output_file, config, logger) {
  if (is.null(variantcall_data) || nrow(variantcall_data) == 0) {
    log_info(logger, "VariantCall database processing skipped (no data)")
    return(list(total_rules_added = 0, updated_cID_lookup = cID_lookup))
  }
  
  log_info(logger, "Processing variantCall database for approved variants...")
  
  # Filter for approved variants only (R converts spaces to dots in column names)
  approved_variants <- variantcall_data[variantcall_data$Approval.Status == "approved", ]
  
  if (nrow(approved_variants) == 0) {
    log_info(logger, "No approved variants found in variantCall database")
    return(list(total_rules_added = 0, updated_cID_lookup = cID_lookup))
  }
  
  log_info(logger, paste("Found", nrow(approved_variants), "approved variants out of", nrow(variantcall_data), "total variants"))
  
  variantcall_count <- 0
  
  for (i in 1:nrow(approved_variants)) {
    variant_row <- approved_variants[i, ]
    
    # Extract variant information using actual variantCall database column names (R converts spaces to dots)
    gene <- variant_row$Gene.Name
    disease_name <- variant_row$Report.Science.ID
    variant_name <- variant_row$Variant.Name  # e.g., chr11_17397055_C_T
    
    # Parse the variant name to extract genomic coordinates
    parsed_variant <- parse_variant_name_from_variantcall(variant_name)
    
    # Skip if essential information is missing or parsing failed
    # Gene is beneficial but not required - we can still create position-only rules
    if (is.na(disease_name) || is.null(parsed_variant)) {
      next
    }
    
    chrom <- parsed_variant$chrom
    pos <- parsed_variant$pos
    ref <- parsed_variant$ref
    alt <- parsed_variant$alt
    
    # Look up existing cID for this gene/disease combination (use "unknown_gene" if gene is missing)
    gene_for_lookup <- if (!is.na(gene) && gene != "") gene else "unknown_gene"
    lookup_key <- paste(disease_name, gene_for_lookup, sep="_")
    if (lookup_key %in% names(cID_lookup)) {
      # Use existing cID for this gene/disease combination
      gene_cID <- cID_lookup[[lookup_key]]$cID
      cCond <- cID_lookup[[lookup_key]]$cCond
      cThresh <- cID_lookup[[lookup_key]]$cThresh
    } else {
      # Create new cID if gene/disease combination not found
      existing_cIDs <- sapply(cID_lookup, function(x) x$cID)
      gene_cID <- max(existing_cIDs) + 1
      cCond <- ">="
      cThresh <- 1
      cID_lookup[[lookup_key]] <- list(cID=gene_cID, cCond=cCond, cThresh=cThresh)
    }
    
    # Create rule with gene condition (if available) plus genomic position
    if (!is.na(gene) && gene != "") {
      # Include gene condition for better downstream performance
      gene_rule <- paste0("SYMBOL == ", gene)
      position_rule <- paste0(" && CHROM == ", chrom, " && POS == ", pos)
    } else {
      # Position-only rule if gene is missing
      gene_rule <- ""
      position_rule <- paste0("CHROM == ", chrom, " && POS == ", pos)
    }
    
    if (!is.na(ref)) {
      position_rule <- paste0(position_rule, " && REF == ", ref)
    }
    if (!is.na(alt)) {
      position_rule <- paste0(position_rule, " && ALT == ", alt)
    }
    
    # Use special frequency rule for approved variants (from config)
    frequency_rule <- config$settings$FREQUENCY_RULE_SPECIAL
    frequency_rule <- gsub("\\{FORMAT_GQ_THRESHOLD\\}", config$settings$FORMAT_GQ_THRESHOLD, frequency_rule)
    
    rule_string <- paste0(gene_rule, position_rule, frequency_rule)
    inheritance_rule <- paste(gene_cID, cCond, cThresh, sep="\t")
    
    full_rule <- paste(disease_name, rule_string, inheritance_rule, sep="\t")
    traced_writeLines(full_rule, output_file)
    variantcall_count <- variantcall_count + 1
    
    # Log with gene info if available, otherwise just position
    gene_info <- if (!is.na(gene) && gene != "") paste("(", gene, ")") else ""
    log_info(logger, paste("Added approved variant rule for", chrom, ":", pos, gene_info, "in", disease_name, "with cID", gene_cID))
  }
  
  log_info(logger, paste("Added", variantcall_count, "approved variant rules from variantCall database"))
  
  return(list(
    total_rules_added = variantcall_count,
    updated_cID_lookup = cID_lookup
  ))
}

#' Generate PTV only rules
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

#' Generate ClinVar pathogenic/likely pathogenic rules
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

#' Generate supplemental variant list rules
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

#' Process supplemental variants to create rules
#' @param gene_variants Variants for a specific gene
#' @param logger Logger instance
#' @return Vector of specific variant rules
process_supplemental_variants <- function(gene_variants, logger) {
  # Characterize types - genomic notation for in-gene SNVs, c.dot for others
  hgvs_clean <- gsub(" ", "", gene_variants$Variant)
  hgvs_cdot <- sub("^.+:", "", hgvs_clean)
  
  in_gene_snv <- grep("^c\\.[0-9]+[ACTG]>[ACTG]", hgvs_cdot, invert = FALSE)
  non_in_gene_snv <- grep("^c\\.[0-9]+[ACTG]>[ACTG]", hgvs_cdot, invert = TRUE)
  
  specific_variant_rules <- character()
  
  # Process in-gene single nucleotide substitutions
  if (length(in_gene_snv) > 0) {
      chr <- paste0("chr", sub("^NC_[0]+", "", sub("\\.[0-9]+$", "", sub(":.+$", "", gene_variants[in_gene_snv, "Position"]))))
  pos <- sub("[ACGT].+$", "", sub("^.+:g.", "", gene_variants[in_gene_snv, "Position"]))
    c_dot <- hgvs_cdot[in_gene_snv]
    
    if (any(is.na(chr) | is.na(pos) | chr %in% "chr23")) {
      specific_variant_rules <- c(specific_variant_rules, paste0(" && HGVSc =~ ", c_dot, " "))
    } else {
      specific_variant_rules <- c(specific_variant_rules, paste0(" && HGVSc =~ ", c_dot, " && CHROM == ", chr, " && POS == ", pos))
    }
  }
  
  # Process non-in-gene variants
  if (length(non_in_gene_snv) > 0) {
    c_dot <- hgvs_cdot[non_in_gene_snv]
    c_dot <- sub("del[ACTG0-9]+", "del", c_dot)
    specific_variant_rules <- c(specific_variant_rules, paste0(" && HGVSc =~ ", c_dot))
    
    # Omit problematic variants
    omit_indices <- c(
      grep("splice", specific_variant_rules),
      grep("\\[", specific_variant_rules)
    )
    
    if (length(omit_indices) > 0) {
      specific_variant_rules <- specific_variant_rules[-omit_indices]
      log_info(logger, paste("Omitted", length(omit_indices), "specific variants because of unclear instructions"))
    }
  }
  
  return(specific_variant_rules)
}

#' Generate missense and nonsense rules (full rule set)
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

#' Generate special rules for HBB, HFE, CFTR
#' @param gene_rule Base gene rule
#' @param disease_name Disease name
#' @param gene Gene symbol
#' @param cutoff_list Cutoff list
#' @param frequency_rule Frequency rule
#' @param cID Current compound ID
#' @param config Configuration object
#' @return Vector of rule strings
generate_special_rules <- function(gene_rule, disease_name, gene, cutoff_list, frequency_rule, cID, config) {
  special_rules <- config$special_cases$special_disease_rules
  gene_disease_rules <- special_rules[special_rules$gene == gene & special_rules$disease == disease_name, ]
  
  if (nrow(gene_disease_rules) == 0) {
    stop(paste("Special Variants-to-find not defined for gene", gene, "disease", disease_name))
  }
  
  exclusion_zone_rule <- exclusion_rule_function(gene, cutoff_list)
  inheritance_rule_special <- paste(cID, ">=", "1", sep = "\t")
  frequency_rule_special <- config$settings$FREQUENCY_RULE_SPECIAL
  frequency_rule_special <- gsub("\\{FORMAT_GQ_THRESHOLD\\}", config$settings$FORMAT_GQ_THRESHOLD, frequency_rule_special)
  
  strings <- character()
  
  # Handle EXCLUDE rules
  exclude_rules <- gene_disease_rules[gene_disease_rules$rule_type == "EXCLUDE", ]
  if (nrow(exclude_rules) > 0) {
    exclude_variants <- paste0(" && HGVSc != ", exclude_rules$hgvs_variant, " ")
    exclude_rule <- paste(exclude_variants, collapse = "")
    
    strings_1 <- paste(disease_name, paste0(gene_rule, config$rules$non_splice_pos_rules, exclude_rule, exclusion_zone_rule, frequency_rule), inheritance_rule_special, sep = "\t")
    strings_2 <- paste(disease_name, paste0(gene_rule, config$rules$non_splice_rules, exclude_rule, frequency_rule), inheritance_rule_special, sep = "\t")
    strings <- c(strings, strings_1, strings_2)
  }
  
  # Handle INCLUDE rules
  include_rules <- gene_disease_rules[gene_disease_rules$rule_type == "INCLUDE", ]
  if (nrow(include_rules) > 0) {
    if (nrow(include_rules) == 1 && gene == "HBB" && disease_name == "Sickle_cell_disease") {
      # Special case for sickle cell - only include this variant
      include_rule <- paste0(" && HGVSc == ", include_rules$hgvs_variant, " ")
      strings_1 <- paste(disease_name, paste0(gene_rule, include_rule, frequency_rule_special), inheritance_rule_special, sep = "\t")
      strings <- c(strings, strings_1)
    } else {
      # General case - add standard rules plus specific variants
      strings_1 <- paste(disease_name, paste0(gene_rule, config$rules$non_splice_pos_rules, exclusion_zone_rule, frequency_rule), inheritance_rule_special, sep = "\t")
      strings_2 <- paste(disease_name, paste0(gene_rule, config$rules$non_splice_rules, frequency_rule), inheritance_rule_special, sep = "\t")
      
      include_variants <- paste0(" && HGVSc == ", include_rules$hgvs_variant, " ")
      strings_3 <- paste(disease_name, paste0(gene_rule, include_variants, frequency_rule_special), inheritance_rule_special, sep = "\t")
      
      strings <- c(strings, strings_1, strings_2, strings_3)
    }
  }
  
  return(strings)
}

#' Add homozygous rules for AR/XLR genes
#' @param strings Original rule strings
#' @param cID Current compound ID
#' @return Vector of homozygous rule strings
add_homozygous_rules <- function(strings, cID) {
  # Add format_GT == 1/1 condition
  homozygous_strings <- sub("(\t[^\t]*)\t(\\d)", "\\1 && format_GT == 1/1\t\\2", strings)
  
  # Change cThresh to 1
  homozygous_strings <- sub("\t2$", "\t1", homozygous_strings)
  
  # Bump up cID by one
  homozygous_strings <- sub(paste0("\t", cID, "\t"), paste0("\t", cID + 1, "\t"), homozygous_strings)
  
  return(homozygous_strings)
}

#' Generate validation rules for Jennifer's proficiency training
#' @param config Configuration object
#' @return Vector of validation rule strings
generate_validation_rules <- function(config) {
  validation_data <- config$special_cases$validation_rules
  
  validation_strings <- character()
  
  for (i in 1:nrow(validation_data)) {
    rule <- paste0("SYMBOL == ", validation_data[i, "gene"], 
                   " && CHROM == ", validation_data[i, "chr"], 
                   " && POS == ", validation_data[i, "pos"], 
                   " && REF == ", validation_data[i, "ref"], 
                   " && ALT == ", validation_data[i, "alt"])
    
    inheritance_rule <- paste(validation_data[i, "cid"], ">=", "1", sep = "\t")
    validation_string <- paste(validation_data[i, "disease"], rule, inheritance_rule, sep = "\t")
    validation_strings <- c(validation_strings, validation_string)
  }
  
  return(validation_strings)
}

#' Generate gene list JSON
#' @param gene_list Processed gene list
#' @param output_dir Output directory
#' @param logger Logger instance
#' @return List of gene list JSON (science pipeline names only)
generate_gene_list_json <- function(gene_list, output_dir, logger) {
  log_info(logger, "Generating gene list JSON file")
  
  gene_list_json_science_pipeline_names <- list()
  
  for (disease_name in unique(gene_list$Disease)) {
    gene_list_here <- gene_list[gene_list$Disease == disease_name, ]
    
    # Prepare gene list for export
    gene_list_for_export <- gene_list_here$Gene
    ptv_only_genes <- gene_list_here$Variants.To.Find == "PTV only"
    gene_list_for_export[ptv_only_genes] <- paste0(gene_list_for_export[ptv_only_genes], "†")
    
    # Create JSON entry with science pipeline (disease) name
    gene_string <- paste(sort(gene_list_for_export), collapse = ", ")
    gene_list_json_science_pipeline_names[[disease_name]] <- gene_string
  }
  
  # Write JSON file using traced operations (only science pipeline names)
  traced_write_json(gene_list_json_science_pipeline_names, file.path(output_dir, "outputs", "list_of_analyzed_genes_science_pipeline_names.json"), pretty = TRUE)
  
  log_info(logger, "Generated gene list JSON file successfully")
  
  return(list(
    gene_list_json_science_pipeline_names = gene_list_json_science_pipeline_names
  ))
}

#' Main rule generation function  
#' @param master_gene_list Pre-loaded gene list data frame (not file path)
#' @param variant_list Pre-loaded variant list data frame (not file path)
#' @param cutoff_list Pre-loaded cutoff list data frame (not file path)
#' @param config Configuration object
#' @param logger Logger instance
#' @return List containing generated rules and metadata
generate_rules <- function(master_gene_list, variant_list, cutoff_list, config, logger) {
  log_section(logger, "RULE GENERATION")
  
  # Use pre-loaded data objects (no redundant file loading)
  gene_list <- master_gene_list
  variant_list_data <- variant_list
  
  log_info(logger, "✅ Using pre-loaded data objects - no redundant file loading")
  
  # Process cutoff list (clean up and validate) - using standardized column names
  # Note: cutoff_list now has standardized columns: Gene, Terminal.Cutoff.Missense, Terminal.Cutoff.Frameshift
  
  # Remove empty entries
  cutoff_list[cutoff_list$Terminal.Cutoff.Missense %in% "", "Terminal.Cutoff.Missense"] <- NA
  cutoff_list <- cutoff_list[!is.na(cutoff_list$Terminal.Cutoff.Missense), ]
  
  # Fix HTML entities
  cutoff_list$Terminal.Cutoff.Missense <- sub("^&gt;", ">", cutoff_list$Terminal.Cutoff.Missense)
  cutoff_list$Terminal.Cutoff.Missense <- sub("^&lt;", "<", cutoff_list$Terminal.Cutoff.Missense)
  
  # Validate numeric values
  numeric_check <- is.na(as.numeric(sub("^[\\<\\>]", "", cutoff_list$Terminal.Cutoff.Missense)))
  if (any(numeric_check)) {
    log_warning(logger, "Non-numeric terminal cutoff values found:")
    print(cutoff_list[numeric_check, ])
  }
  
  log_info(logger, paste("Terminal cutoff list created with", nrow(cutoff_list), "genes"))
  
  # Prepare output
  date_stamp <- format(Sys.time(), "%Y-%m-%d")
  output_filename <- file.path(config$output_dir, "outputs", paste0(date_stamp, "_rules_file_from_carrier_list_nr_", config$rules_version, ".tsv"))
  
  # Open output file using traced operation
  output_file <- traced_file(output_filename, "w")
  traced_writeLines("Disease_report\tRULE\tcID\tcCond\tcThresh", output_file)
  
  # Generate rules for each disease (following manual script cID assignment strategy)
  cID <- 0  # Initialize to 0 like manual script
  total_rules <- 0
  
  # Initialize step-by-step tracing system
  trace <- init_step_trace(config$output_dir, logger)
  
  # Log initial setup
  log_step(trace, "Initialization", "Starting rules generation process", 0, 0, 
           paste("Processing", nrow(gene_list), "genes across", length(unique(gene_list$Disease)), "diseases"))
  
  for (disease_name in unique(gene_list$Disease)) {
    gene_list_here <- gene_list[gene_list$Disease == disease_name, ]
    log_info(logger, paste("Processing disease:", disease_name, "with", nrow(gene_list_here), "genes"))
    
    # Log disease processing start
    log_step(trace, "Disease Processing", paste("Starting processing for disease:", disease_name), 0, 
             details = paste("Disease has", nrow(gene_list_here), "genes to process"))
    
    for (j in 1:nrow(gene_list_here)) {
      gene_info <- gene_list_here[j, , drop = FALSE]
      
      # Skip genes with NA values
      if (is.na(gene_info[["Gene"]])) {
        log_warning(logger, paste("Skipping gene with NA value in disease:", disease_name))
        next
      }
      
      # Increment cID for each gene-disease pair (matching manual script)
      cID <- cID + 1
      
      # Calculate inheritance values before generating rules (single calculation)
      inheritance <- gene_info[["Inheritance"]]
      cCond <- ">="
      if (inheritance %in% c("AR") & !gene_info[["Carrier"]]) {
        cThresh <- 2
      } else {
        cThresh <- 1
      }
      
      # Create lookup key for this gene/disease combination
      lookup_key <- paste(gene_info[["Disease"]], gene_info[["Gene"]], sep="_")
      if (!exists("cID_lookup")) {
        cID_lookup <- list()
      }
      cID_lookup[[lookup_key]] <- list(cID=cID, cCond=cCond, cThresh=cThresh)
      
      # Generate rules for this gene (passing inheritance values)
      gene_rules <- generate_gene_rules(gene_info, cutoff_list, variant_list_data, config, cID, cCond, cThresh, logger)
      
      if (length(gene_rules) > 0) {
        traced_writeLines(gene_rules, output_file)
        total_rules <- total_rules + length(gene_rules)
        log_gene_processing(trace, gene_info[["Gene"]], disease_name, gene_info[["Variants.To.Find"]], length(gene_rules))
        
        # Add homozygous rules for AR/XLR non-carrier genes (matching manual script)
        inheritance <- gene_info[["Inheritance"]]
        if (inheritance %in% c("AR") & !gene_info[["Carrier"]] & gene_info[["Variants.To.Find"]] != "Special") {
          original_cID <- cID  # Save the cID used in the original rules
          cID <- cID + 1       # Increment for homozygous rules
          homozygous_strings <- add_homozygous_rules(gene_rules, original_cID)  # Pass original cID to get cID+1 in homozygous rules
          traced_writeLines(homozygous_strings, output_file)
          total_rules <- total_rules + length(homozygous_strings)
        }
      }
    }
  }
  
  # Process variantCall database for approved variants (replaces old variant changes system)
  if (!is.null(config$prepared_data) && !is.null(config$prepared_data$variantcall_database)) {
    variantcall_results <- process_variantcall_database(config$prepared_data$variantcall_database, cID_lookup, output_file, config, logger)
    total_rules <- total_rules + variantcall_results$total_rules_added
    cID_lookup <- variantcall_results$updated_cID_lookup
  }
  
  # Add validation rules
  validation_rules <- generate_validation_rules(config)
  traced_writeLines(validation_rules, output_file)
  total_rules <- total_rules + length(validation_rules)
  log_step(trace, "Validation Rules", "Added validation rules", length(validation_rules), total_rules)
  
  close(output_file)
  
  # Post-processing: Fix spacing issues in the output file
  fix_rule_spacing(output_filename, logger)
  
  # Generate JSON files
  json_data <- generate_gene_list_json(gene_list, config$output_dir, logger)
  
  # Quality control checks
  qc_results <- perform_quality_control(gene_list, output_filename, logger)
  
  log_info(logger, paste("Rule generation completed. Generated", total_rules, "rules"))
  log_info(logger, paste("Output file:", output_filename))
  
  finalize_trace(trace, total_rules, logger)
  
  return(list(
    output_file = output_filename,
    total_rules = total_rules,
    gene_list_json = json_data,
    qc_results = qc_results
  ))
}

#' Initialize step-by-step tracing system
#' @param output_dir Output directory for trace reports
#' @param logger Logger instance
#' @return List containing trace tracking variables
init_step_trace <- function(output_dir, logger) {
  trace_dir <- file.path(output_dir, "analysis", "step_trace")
  dir.create(trace_dir, recursive = TRUE, showWarnings = FALSE)
  
  trace_file <- file.path(trace_dir, paste0("step_trace_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".md"))
  trace_tsv_file <- file.path(trace_dir, paste0("step_trace_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".tsv"))
  
  # Initialize trace tracking
  trace <- list(
    file = trace_file,
    tsv_file = trace_tsv_file,
    step_counter = 0,
    total_rules = 0,
    gene_counter = 0,
    disease_rules = list(),
    processing_steps = list(),
    start_time = Sys.time()
  )
  
  # Write markdown header
  writeLines(c(
    "# Rules Generation Step-by-Step Trace Report",
    "",
    paste("**Generation Time:** ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    paste("**Framework Version:** Rules Generation Framework v1.0"),
    "",
    "## Executive Summary",
    "",
    "This report traces every step of the rules generation process, showing:",
    "- Gene processing and rule template application",
    "- Rule counts at each step",
    "- Disease-specific changes",
    "- Total rule progression",
    "",
    "---",
    "",
    "## Step-by-Step Process",
    ""
  ), trace_file)
  
  # Write TSV header
  writeLines(c(
    paste("step_number", "step_type", "timestamp", "gene", "disease", "variant_type", 
          "rules_added", "rules_total", "description", sep = "\t")
  ), trace_tsv_file)
  
  log_info(logger, paste("Step trace initialized:", trace_file))
  log_info(logger, paste("Step trace TSV log:", trace_tsv_file))
  return(trace)
}

#' Log a step in the trace
#' @param trace Trace object
#' @param step_name Name of the step
#' @param description Description of what happened
#' @param rules_added Number of rules added in this step
#' @param rules_total New total number of rules
#' @param details Additional details (optional)
log_step <- function(trace, step_name, description, rules_added = 0, rules_total = NA, details = NULL) {
  trace$step_counter <- trace$step_counter + 1
  
  if (!is.na(rules_total)) {
    trace$total_rules <- rules_total
  } else {
    trace$total_rules <- trace$total_rules + rules_added
  }
  
  step_info <- list(
    step = trace$step_counter,
    name = step_name,
    description = description,
    rules_added = rules_added,
    rules_total = trace$total_rules,
    timestamp = Sys.time(),
    details = details
  )
  
  trace$processing_steps[[trace$step_counter]] <- step_info
  
  # Write to markdown file (for human readability)
  lines <- c(
    paste("### Step", trace$step_counter, ":", step_name),
    "",
    paste("**Description:** ", description),
    paste("**Rules Added:** ", rules_added),
    paste("**Total Rules:** ", trace$total_rules),
    paste("**Time:** ", format(Sys.time(), "%H:%M:%S")),
    ""
  )
  
  if (!is.null(details)) {
    lines <- c(lines, "**Details:**", paste("- ", details), "")
  }
  
  lines <- c(lines, "---", "")
  
  writeLines(lines, trace$file, sep = "\n")
  # Removed console output: cat(lines, sep = "\n")
  
  # Write to TSV file (for structured data)
  timestamp_str <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  tsv_line <- paste(trace$step_counter, step_name, timestamp_str, "", "", "", 
                    rules_added, trace$total_rules, gsub("\t", " ", description), sep = "\t")
  cat(tsv_line, "\n", file = trace$tsv_file, append = TRUE)
}

#' Log gene processing
#' @param trace Trace object
#' @param gene Gene name
#' @param disease Disease name
#' @param variant_type Type of variant processing
#' @param rules_generated Number of rules generated for this gene
log_gene_processing <- function(trace, gene, disease, variant_type, rules_generated) {
  trace$gene_counter <- trace$gene_counter + 1
  
  # Track disease-specific rules
  if (!disease %in% names(trace$disease_rules)) {
    trace$disease_rules[[disease]] <- list(genes = 0, rules = 0)
  }
  
  trace$disease_rules[[disease]]$genes <- trace$disease_rules[[disease]]$genes + 1
  trace$disease_rules[[disease]]$rules <- trace$disease_rules[[disease]]$rules + rules_generated
  
  details <- paste("Gene:", gene, "| Disease:", disease, "| Type:", variant_type, "| Rules:", rules_generated)
  
  log_step(trace, 
           "Gene Processing", 
           paste("Processed gene", gene, "for", disease, "using", variant_type, "logic"),
           rules_generated,
           details = details)
  
  # Write detailed TSV entry for gene processing
  timestamp_str <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  tsv_line <- paste(trace$step_counter, "Gene Processing", timestamp_str, gene, disease, variant_type,
                    rules_generated, trace$total_rules, 
                    gsub("\t", " ", paste("Processed gene", gene, "for", disease)), sep = "\t")
  cat(tsv_line, "\n", file = trace$tsv_file, append = TRUE)
}

#' Finalize trace report
#' @param trace Trace object
#' @param final_rule_count Final total number of rules
#' @param logger Logger instance
finalize_trace <- function(trace, final_rule_count, logger) {
  end_time <- Sys.time()
  duration <- as.numeric(difftime(end_time, trace$start_time, units = "secs"))
  
  # Write summary to markdown file
  summary_lines <- c(
    "",
    "## Final Summary",
    "",
    paste("**Total Processing Steps:** ", trace$step_counter),
    paste("**Total Genes Processed:** ", trace$gene_counter),
    paste("**Final Rule Count:** ", final_rule_count),
    paste("**Processing Duration:** ", sprintf("%.2f seconds", duration)),
    "",
    "### Rules by Disease",
    ""
  )
  
  # Add disease breakdown
  for (disease in names(trace$disease_rules)) {
    disease_info <- trace$disease_rules[[disease]]
    summary_lines <- c(summary_lines, 
                      paste("- **", disease, ":** ", disease_info$genes, " genes → ", disease_info$rules, " rules"))
  }
  
  summary_lines <- c(summary_lines, 
                    "",
                    "### Processing Rate",
                    "",
                    paste("- **Rules per second:** ", sprintf("%.2f", final_rule_count / duration)),
                    paste("- **Genes per second:** ", sprintf("%.2f", trace$gene_counter / duration)),
                    "",
                    "---",
                    "",
                    "*Report generated by Rules Generation Framework*"
  )
  
  writeLines(summary_lines, trace$file, sep = "\n")
  # Removed console output: cat(summary_lines, sep = "\n")
  
  # Write final summary to TSV
  timestamp_str <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  final_tsv_line <- paste("FINAL", "Summary", timestamp_str, "", "", "", 
                         0, final_rule_count, 
                         paste("Total:", trace$gene_counter, "genes,", final_rule_count, "rules,", 
                               sprintf("%.2f", duration), "seconds"), sep = "\t")
  cat(final_tsv_line, "\n", file = trace$tsv_file, append = TRUE)
  
  log_info(logger, paste("Step trace completed:", trace$file))
  log_info(logger, paste("Step trace TSV data:", trace$tsv_file))
  log_info(logger, paste("Final statistics: ", trace$gene_counter, "genes →", final_rule_count, "rules"))
}

#' Perform quality control checks
#' @param gene_list Original gene list
#' @param output_filename Generated rules file
#' @param logger Logger instance
#' @return List of QC results
perform_quality_control <- function(gene_list, output_filename, logger) {
  log_info(logger, "Performing quality control checks")
  
  # Read generated rules
  rules_data <- read.csv(output_filename, sep = "\t", stringsAsFactors = FALSE)
  
  # Check for genes with no rules
  no_rules_genes <- character()
  for (gene in unique(gene_list$Gene)) {
    if (is.na(gene)) next
    if (length(grep(gene, rules_data$RULE)) == 0) {
      no_rules_genes <- c(no_rules_genes, gene)
    }
  }
  
  if (length(no_rules_genes) > 0) {
    log_warning(logger, paste("These genes had no rules associated with them:", paste(sort(no_rules_genes), collapse = ", ")))
  }
  
  # Check for problematic disease names
  disease_names <- unique(gene_list$Disease)
  weird_names <- disease_names[grepl("[^a-zA-Z0-9_-]", disease_names)]
  if (length(weird_names) > 0) {
    log_warning(logger, paste("Check these disease names for problematic characters:", paste(weird_names, collapse = ", ")))
  }
  
  log_info(logger, paste("Quality control completed. Found", length(no_rules_genes), "genes without rules"))
  
  return(list(
    no_rules_genes = no_rules_genes,
    weird_names = weird_names,
    total_rules = nrow(rules_data)
  ))
}

#' Fix spacing issues in the generated rules file
#' @param output_filename Path to the rules file
#' @param logger Logger instance
fix_rule_spacing <- function(output_filename, logger) {
  log_info(logger, "Applying post-processing spacing fixes...")
  
  # Read the file
  lines <- readLines(output_filename)
  
  # Fix common spacing issues where && gets concatenated without proper spacing
  fixed_lines <- lines
  
  # Fix all spacing issues with a comprehensive pattern: any non-space character followed by &&
  fixed_lines <- gsub("([^\\s])&&", "\\1 &&", fixed_lines)
  
  # Normalize multiple spaces to single spaces (except for tabs which are field separators)
  fixed_lines <- gsub("  +", " ", fixed_lines)
  
  # Count fixes made
  fixes_made <- sum(lines != fixed_lines)
  log_info(logger, paste("Applied spacing fixes to", fixes_made, "rules"))
  
  # Write back the fixed content
  writeLines(fixed_lines, output_filename)
} 
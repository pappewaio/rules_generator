# Logger Module
# Simple logging functionality using base R only

#' Initialize logger
#' @param log_file Path to log file
#' @param level Logging level (DEBUG, INFO, WARNING, ERROR)
#' @return Logger environment
init_logger <- function(log_file, level = "INFO") {
  log_env <- new.env()
  log_env$file <- log_file
  log_env$level <- level
  log_env$levels <- c("DEBUG" = 1, "INFO" = 2, "WARNING" = 3, "ERROR" = 4)
  log_env$current_level <- log_env$levels[[level]]
  
  # Create log directory if it doesn't exist
  log_dir <- dirname(log_file)
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
  }
  
  # Initialize log file with header
  cat(paste0("=== Log initialized at ", Sys.time(), " ===\n"), file = log_file, append = FALSE)
  
  return(log_env)
}

#' Write log message
#' @param logger Logger environment from init_logger
#' @param level Message level (DEBUG, INFO, WARNING, ERROR)
#' @param message Log message
#' @param ... Additional parameters to paste into message
log_message <- function(logger, level, message, ...) {
  if (logger$levels[[level]] >= logger$current_level) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    full_message <- paste(c(message, list(...)), collapse = " ")
    log_line <- paste0("[", timestamp, "] [", level, "] ", full_message, "\n")
    
    # Write to file
    cat(log_line, file = logger$file, append = TRUE)
    
    # Only print to console for ERROR (not WARNING)
    if (level == "ERROR") {
      cat(log_line)
    }
  }
}

#' Log debug message
#' @param logger Logger environment
#' @param message Debug message
#' @param ... Additional parameters
log_debug <- function(logger, message, ...) {
  log_message(logger, "DEBUG", message, ...)
}

#' Log info message
#' @param logger Logger environment
#' @param message Info message
#' @param ... Additional parameters
log_info <- function(logger, message, ...) {
  log_message(logger, "INFO", message, ...)
}

#' Log warning message
#' @param logger Logger environment
#' @param message Warning message
#' @param ... Additional parameters
log_warning <- function(logger, message, ...) {
  log_message(logger, "WARNING", message, ...)
}

#' Log error message
#' @param logger Logger environment
#' @param message Error message
#' @param ... Additional parameters
log_error <- function(logger, message, ...) {
  log_message(logger, "ERROR", message, ...)
}

#' Log section header
#' @param logger Logger environment
#' @param section_name Name of the section
log_section <- function(logger, section_name) {
  separator <- paste(rep("=", 50), collapse = "")
  log_info(logger, separator)
  log_info(logger, paste("SECTION:", section_name))
  log_info(logger, separator)
  
  # Initialize timing if not exists
  if (is.null(logger$step_timings)) {
    logger$step_timings <- list()
    logger$step_start_times <- list()
  }
  
  # End previous step if exists
  if (length(logger$step_start_times) > 0) {
    last_step <- names(logger$step_start_times)[length(logger$step_start_times)]
    if (!is.null(last_step)) {
      end_time <- Sys.time()
      duration <- as.numeric(difftime(end_time, logger$step_start_times[[last_step]], units = "secs"))
      logger$step_timings[[last_step]] <- duration
      log_info(logger, paste("⏱️  Step completed:", last_step, "- Duration:", round(duration, 2), "seconds"))
    }
  }
  
  # Start timing for current step
  current_time <- Sys.time()
  logger$step_start_times[[section_name]] <- current_time
  log_info(logger, paste("⏱️  Step started:", section_name, "at", format(current_time, "%H:%M:%S")))
}

#' Finalize timing and write timing report
#' @param logger Logger environment
#' @param output_dir Output directory for timing report
finalize_timing <- function(logger, output_dir) {
  if (is.null(logger$step_timings)) return()
  
  # Finalize last step
  if (length(logger$step_start_times) > 0) {
    last_step <- names(logger$step_start_times)[length(logger$step_start_times)]
    if (!is.null(last_step) && is.null(logger$step_timings[[last_step]])) {
      end_time <- Sys.time()
      duration <- as.numeric(difftime(end_time, logger$step_start_times[[last_step]], units = "secs"))
      logger$step_timings[[last_step]] <- duration
      log_info(logger, paste("⏱️  Final step completed:", last_step, "- Duration:", round(duration, 2), "seconds"))
    }
  }
  
  # Write timing report
  timing_file <- file.path(output_dir, "step_timings.json")
  timing_data <- list(
    step_timings = logger$step_timings,
    total_duration = sum(unlist(logger$step_timings)),
    timestamp = Sys.time()
  )
  
  tryCatch({
    jsonlite::write_json(timing_data, timing_file, pretty = TRUE)
    log_info(logger, paste("⏱️  Timing report saved to:", timing_file))
    
    # Log summary
    total_time <- sum(unlist(logger$step_timings))
    log_info(logger, paste("⏱️  TIMING SUMMARY - Total:", round(total_time, 2), "seconds"))
    for (step in names(logger$step_timings)) {
      duration <- logger$step_timings[[step]]
      percentage <- round((duration / total_time) * 100, 1)
      log_info(logger, paste("⏱️  ", step, ":", round(duration, 2), "s (", percentage, "%)", sep = ""))
    }
  }, error = function(e) {
    log_warning(logger, paste("Failed to write timing report:", e$message))
  })
}

#' Log function start
#' @param logger Logger environment
#' @param function_name Name of the function
#' @param ... Function parameters to log
log_function_start <- function(logger, function_name, ...) {
  params <- list(...)
  if (length(params) > 0) {
    param_string <- paste(names(params), params, sep = "=", collapse = ", ")
    log_debug(logger, paste("Starting function:", function_name, "with parameters:", param_string))
  } else {
    log_debug(logger, paste("Starting function:", function_name))
  }
}

#' Log function end
#' @param logger Logger environment
#' @param function_name Name of the function
#' @param result Optional result to log
log_function_end <- function(logger, function_name, result = NULL) {
  if (!is.null(result)) {
    log_debug(logger, paste("Completed function:", function_name, "with result:", result))
  } else {
    log_debug(logger, paste("Completed function:", function_name))
  }
}

#' Log statistics
#' @param logger Logger environment
#' @param stats Named list of statistics
log_stats <- function(logger, stats) {
  log_info(logger, "Statistics:")
  for (name in names(stats)) {
    log_info(logger, paste("  ", name, ":", stats[[name]]))
  }
}

#' Close logger
#' @param logger Logger environment
close_logger <- function(logger) {
  log_info(logger, paste("=== Log session ended at", Sys.time(), "==="))
} 
# File Write Tracing Module
# This module provides wrapper functions for all file write operations
# to trace exactly where files are being written

#' Global trace file handle
TRACE_FILE_HANDLE <- NULL

#' Initialize the file write trace
#' @param output_dir Base output directory
#' @param logger Logger instance (optional)
init_write_trace <- function(output_dir, logger = NULL) {
  trace_file_path <- file.path(output_dir, "outputs", "trace_write_file.txt")
  
  # Ensure directory exists
  dir.create(dirname(trace_file_path), recursive = TRUE, showWarnings = FALSE)
  
  # Initialize trace file
  TRACE_FILE_HANDLE <<- file(trace_file_path, "w")
  
  # Write header
  writeLines(paste("File Write Trace Log"), TRACE_FILE_HANDLE)
  writeLines(paste("Started:", Sys.time()), TRACE_FILE_HANDLE)
  writeLines(paste("Output Dir:", output_dir), TRACE_FILE_HANDLE)
  writeLines(paste("Working Dir:", getwd()), TRACE_FILE_HANDLE)
  writeLines("", TRACE_FILE_HANDLE)
  writeLines("TIMESTAMP | OPERATION | ABSOLUTE_PATH | RELATIVE_PATH | CALLER | STATUS", TRACE_FILE_HANDLE)
  writeLines("=" %r% 80, TRACE_FILE_HANDLE)
  
  if (!is.null(logger)) {
    log_info(logger, paste("File write trace initialized:", trace_file_path))
  }
  
  return(trace_file_path)
}

#' Log a file write operation
#' @param operation Type of operation (writeLines, write.table, etc.)
#' @param file_path Path where file is being written
#' @param status Success/failure status
#' @param caller Optional caller identification
log_write_operation <- function(operation, file_path, status = "SUCCESS", caller = "") {
  if (is.null(TRACE_FILE_HANDLE)) {
    return()
  }
  
  # Get absolute path
  abs_path <- normalizePath(file_path, mustWork = FALSE)
  
  # Get relative path from current working directory
  rel_path <- file_path
  if (file.exists(dirname(file_path))) {
    tryCatch({
      rel_path <- relative_path(file_path, getwd())
    }, error = function(e) {
      rel_path <- file_path
    })
  }
  
  # Get caller info if not provided
  if (caller == "") {
    caller <- paste(sys.calls()[[max(1, length(sys.calls()) - 2)]], collapse = "")
    caller <- substr(caller, 1, 50)  # Limit length
  }
  
  # Log entry
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- paste(timestamp, operation, abs_path, rel_path, caller, status, sep = " | ")
  
  writeLines(log_entry, TRACE_FILE_HANDLE)
  flush(TRACE_FILE_HANDLE)
}

#' Wrapper for writeLines with tracing
#' @param text Text to write
#' @param con Connection or file path
#' @param sep Line separator
traced_writeLines <- function(text, con, sep = "\n") {
  # Determine file path
  file_path <- if (is.character(con)) con else summary(con)$description
  
  # Log the operation
  tryCatch({
    result <- writeLines(text, con, sep = sep)
    log_write_operation("writeLines", file_path, "SUCCESS")
    return(result)
  }, error = function(e) {
    log_write_operation("writeLines", file_path, paste("ERROR:", e$message))
    stop(e)
  })
}

#' Wrapper for write.table with tracing
#' @param x Data to write
#' @param file File path
#' @param ... Additional arguments passed to write.table
traced_write_table <- function(x, file, ...) {
  tryCatch({
    result <- write.table(x, file, ...)
    log_write_operation("write.table", file, "SUCCESS")
    return(result)
  }, error = function(e) {
    log_write_operation("write.table", file, paste("ERROR:", e$message))
    stop(e)
  })
}

#' Wrapper for write.csv with tracing
#' @param x Data to write
#' @param file File path
#' @param ... Additional arguments passed to write.csv
traced_write_csv <- function(x, file, ...) {
  tryCatch({
    result <- write.csv(x, file, ...)
    log_write_operation("write.csv", file, "SUCCESS")
    return(result)
  }, error = function(e) {
    log_write_operation("write.csv", file, paste("ERROR:", e$message))
    stop(e)
  })
}

#' Wrapper for jsonlite::write_json with tracing
#' @param x Data to write
#' @param path File path
#' @param ... Additional arguments passed to write_json
traced_write_json <- function(x, path, ...) {
  tryCatch({
    result <- jsonlite::write_json(x, path, ...)
    log_write_operation("write_json", path, "SUCCESS")
    return(result)
  }, error = function(e) {
    log_write_operation("write_json", path, paste("ERROR:", e$message))
    stop(e)
  })
}

#' Wrapper for file() with tracing
#' @param description File path
#' @param open Mode to open file
#' @param ... Additional arguments
traced_file <- function(description, open = "", ...) {
  log_write_operation("file_open", description, "OPENED")
  result <- file(description, open, ...)
  return(result)
}

#' Wrapper for dir.create with tracing
#' @param path Directory path
#' @param ... Additional arguments
traced_dir_create <- function(path, ...) {
  tryCatch({
    result <- dir.create(path, ...)
    log_write_operation("dir.create", path, "SUCCESS")
    return(result)
  }, error = function(e) {
    log_write_operation("dir.create", path, paste("ERROR:", e$message))
    stop(e)
  })
}

#' Helper function to calculate relative path
#' @param path Absolute path
#' @param base Base directory
relative_path <- function(path, base) {
  # Simple relative path calculation
  path <- normalizePath(path, mustWork = FALSE)
  base <- normalizePath(base, mustWork = FALSE)
  
  if (startsWith(path, base)) {
    return(substring(path, nchar(base) + 2))  # +2 to remove leading slash
  } else {
    return(path)
  }
}

#' Close the trace file
close_write_trace <- function() {
  if (!is.null(TRACE_FILE_HANDLE)) {
    writeLines("", TRACE_FILE_HANDLE)
    writeLines(paste("Trace completed:", Sys.time()), TRACE_FILE_HANDLE)
    close(TRACE_FILE_HANDLE)
    TRACE_FILE_HANDLE <<- NULL
  }
}

#' String repeat operator
`%r%` <- function(x, n) {
  paste(rep(x, n), collapse = "")
} 
#!/bin/bash

# Rules Generation Framework - Consolidated Script
# This script handles rules generation from the project root with all functionality integrated

set -e

# Get the directory where this script is located (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$SCRIPT_DIR"
R_SCRIPT="$SCRIPT_DIR/bin/R/generate_rules_simplified.R"

# Default values
INPUT_DIR="$SCRIPT_DIR/input"
OUTPUT_DIR="$SCRIPT_DIR/out_rule_generation"
CONFIG_DIR="$SCRIPT_DIR/config"
S3_VERSION=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if R is installed
    if ! command -v Rscript &> /dev/null; then
        print_error "Rscript not found. Please install R."
        exit 1
    fi
    
    # Check if required R packages are available
    Rscript -e "if (!require('openxlsx', quietly=TRUE)) { cat('openxlsx package not found\n'); quit(status=1) }"
    if [ $? -ne 0 ]; then
        print_error "Required R package 'openxlsx' not found. Please install it with: install.packages('openxlsx')"
        exit 1
    fi
    
    Rscript -e "if (!require('jsonlite', quietly=TRUE)) { cat('jsonlite package not found\n'); quit(status=1) }"
    if [ $? -ne 0 ]; then
        print_error "Required R package 'jsonlite' not found. Please install it with: install.packages('jsonlite')"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create directory structure
setup_directories() {
    print_status "Setting up directory structure..."
    
    mkdir -p "$OUTPUT_DIR"
    
    print_success "Directory structure created"
}

# Function to show usage
show_usage() {
    cat << EOF
Simplified Rules Generation Framework

Usage: $0 [options]

Required Options:
  --master-gene-list FILE  Path to master gene list Excel file
  --variant-list FILE      Path to variant list Excel file
  --rules-version VER      Version identifier for rules file (e.g., 45, 45A, 45B)

Optional Options:
  --variantcall-database FILE  Path to variantCall database CSV/Excel file
  --compare-with-version VER  Previous version to compare with (e.g., 43, 45A)
                             (default: intelligent previous version detection)
  --version-comment "TEXT"    User comment describing this version's changes
  --s3-version VERSION       Deploy to S3 with this version (e.g., 1.2.22)
  --devel-rules             Add devel_ prefixed rules with lower QC thresholds
  --overwrite               Overwrite existing version without prompting
  --check                   Check prerequisites and exit
  --skip-checker            Skip rules checker validation (faster for development)
  --help, -h                Show this help message

Step-wise Versioning:
  Use alphanumeric versions (45A, 45B, 45C) to isolate complex changes.
  Steps are stored nested within the base version folder for easy cross-reference.
  Final version (45) can reference all previous steps in its summary report.
  
  CRITICAL: Use --rules-version 44A (not step_44A!) - framework auto-creates step_44A directory

Examples:
  # Standard version workflow (auto-detects previous version)
  $0 --master-gene-list /path/to/master_gene_list.xlsx \\
     --variant-list /path/to/variant_list.xlsx \\
     --rules-version 45

  # STEP-WISE VERSIONING WORKFLOW (recommended for complex changes)
  # Step 1: Format QC condition changes (affects most rules)
  $0 --master-gene-list /path/to/master_gene_list.xlsx \\
     --variant-list /path/to/variant_list.xlsx \\
     --rules-version 45A \\
     --compare-with-version 44 \\
     --version-comment "Updated format_QC conditions - affects most rules"

  # Step 2: Inheritance pattern updates (builds on 45A)
  $0 --master-gene-list /path/to/updated_gene_list.xlsx \\
     --variant-list /path/to/variant_list.xlsx \\
     --rules-version 45B \\
     --compare-with-version 45A \\
     --version-comment "Updated inheritance patterns for 12 genes"

  # Step 3: New gene additions (builds on 45B)
  $0 --master-gene-list /path/to/final_gene_list.xlsx \\
     --variant-list /path/to/variant_list.xlsx \\
     --rules-version 45C \\
     --compare-with-version 45B \\
     --version-comment "Added 5 new genes to master list"

  # Final combined version (references all stepwise versions)
  $0 --master-gene-list /path/to/final_gene_list.xlsx \\
     --variant-list /path/to/variant_list.xlsx \\
     --rules-version 45 \\
     --version-comment "Final version incorporating 45A-45C changes"

  # Standard workflow with S3 deployment
  $0 --master-gene-list /path/to/master_gene_list.xlsx \\
     --variant-list /path/to/variant_list.xlsx \\
     --rules-version 45 --s3-version 1.2.22

EOF
}

# Parse command line arguments
CHECK_ONLY=false
R_ARGS=()
RULES_VERSION_NUM=""
COMPARE_WITH_VERSION_NUM=""
VERSION_COMMENT=""
OVERWRITE=false
DEVEL_RULES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --master-gene-list)
            if [[ -n "$2" && "$2" != --* ]]; then
                R_ARGS+=("$1" "$2")
                shift 2
            else
                print_error "Option --master-gene-list requires a file path"
                exit 1
            fi
            ;;
        --variant-list)
            if [[ -n "$2" && "$2" != --* ]]; then
                R_ARGS+=("$1" "$2")
                shift 2
            else
                print_error "Option --variant-list requires a file path"
                exit 1
            fi
            ;;
        --variantcall-database)
            if [[ -n "$2" && "$2" != --* ]]; then
                R_ARGS+=("$1" "$2")
                shift 2
            else
                print_error "Option --variantcall-database requires a file path"
                exit 1
            fi
            ;;
        --rules-version)
            if [[ -n "$2" && "$2" != --* ]]; then
                RULES_VERSION_NUM="$2"
                R_ARGS+=("$1" "$2")
                shift 2
            else
                print_error "Option --rules-version requires a version number"
                exit 1
            fi
            ;;
        --compare-with-version)
            if [[ -n "$2" && "$2" != --* ]]; then
                COMPARE_WITH_VERSION_NUM="$2"
                shift 2
            else
                print_error "Option --compare-with-version requires a version identifier"
                exit 1
            fi
            ;;
        --version-comment)
            if [[ -n "$2" && "$2" != --* ]]; then
                VERSION_COMMENT="$2"
                shift 2
            else
                print_error "Option --version-comment requires a comment string"
                exit 1
            fi
            ;;
        --s3-version)
            if [[ -n "$2" && "$2" != --* ]]; then
                S3_VERSION="$2"
                shift 2
            else
                print_error "Option --s3-version requires a version string"
                exit 1
            fi
            ;;
        --overwrite)
            OVERWRITE=true
            # Don't pass --overwrite to R script, we handle it here
            shift
            ;;
        --skip-checker)
            R_ARGS+=("--skip-checker")
            shift
            ;;
        --devel-rules)
            DEVEL_RULES=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to find most recent previous version (updated for nested structure)
find_previous_version() {
    local current_version="$1"
    local base_num=""
    local current_suffix=""
    
    # Extract base number and suffix (e.g., 85A -> base=85, suffix=A)
    if [[ "$current_version" =~ ^([0-9]+)([A-Za-z]*)$ ]]; then
        base_num="${BASH_REMATCH[1]}"
        current_suffix="${BASH_REMATCH[2]}"
    else
        echo ""
        return
    fi
    
    local base_version_dir="$OUTPUT_DIR/version_${base_num}"
    
    # If current version has suffix (e.g., 85B), look for previous steps in same base
    if [[ -n "$current_suffix" ]]; then
        local prev_ascii=$(printf "%d" "'$current_suffix")
        while [[ $prev_ascii -gt 65 ]]; do  # ASCII 'A' = 65
            prev_ascii=$((prev_ascii - 1))
            local prev_char=$(printf "\\$(printf "%03o" $prev_ascii)")
            local prev_step_dir="$base_version_dir/step_${base_num}${prev_char}"
            if [[ -d "$prev_step_dir" ]]; then
                echo "${base_num}${prev_char}"
                return
            fi
        done
        
        # If no previous step found, try base version
        if [[ -d "$base_version_dir" && -f "$base_version_dir/version_metadata.json" ]]; then
            echo "${base_num}"
            return
        fi
    fi
    
    # Look for previous base versions
    for (( i = base_num - 1; i >= 1; i-- )); do
        if [[ -d "$OUTPUT_DIR/version_${i}" ]]; then
            echo "${i}"
            return
        fi
    done
    
    echo ""
}

# Handle default compare-with-version behavior
if [[ -n "$RULES_VERSION_NUM" && -z "$COMPARE_WITH_VERSION_NUM" ]]; then
    # Intelligent previous version detection
    COMPARE_WITH_VERSION_NUM=$(find_previous_version "$RULES_VERSION_NUM")
    if [[ -n "$COMPARE_WITH_VERSION_NUM" ]]; then
        print_status "Auto-detected comparison version: $COMPARE_WITH_VERSION_NUM"
    else
        print_status "No previous version found for comparison"
    fi
fi

# Add compare-with parameter to R_ARGS if specified
if [[ -n "$COMPARE_WITH_VERSION_NUM" ]]; then
    R_ARGS+=("--compare-with" "version_$COMPARE_WITH_VERSION_NUM")
fi

# Add version comment if specified
if [[ -n "$VERSION_COMMENT" ]]; then
    R_ARGS+=("--version-comment" "$VERSION_COMMENT")
fi

# Set output directory to project root
R_ARGS+=("--output-dir" "$OUTPUT_DIR")

# Handle special modes
if $CHECK_ONLY; then
    check_prerequisites
    exit 0
fi

# Main execution
print_status "Starting Simplified Rules Generation Framework from project root..."
print_status "Framework directory: $FRAMEWORK_DIR"
print_status "Output directory: $OUTPUT_DIR"
print_status "Working directory: $SCRIPT_DIR"

# Check prerequisites
check_prerequisites

# Handle overwrite logic for version directories (updated for nested structure)
if [[ -n "$RULES_VERSION_NUM" ]]; then
    # Parse version to determine structure
    base_version=$(echo "$RULES_VERSION_NUM" | sed 's/[A-Za-z].*$//')
    BASE_VERSION_DIR="$OUTPUT_DIR/version_$base_version"
    
    # Determine target directory based on version type
    if [[ "$RULES_VERSION_NUM" =~ ^[0-9]+[A-Za-z]+$ ]]; then
        # Step-wise version: nested within base version
        TARGET_DIR="$BASE_VERSION_DIR/step_$RULES_VERSION_NUM"
        VERSION_DESC="step $RULES_VERSION_NUM"
    else
        # Standard version: direct version directory
        TARGET_DIR="$BASE_VERSION_DIR"
        VERSION_DESC="version $RULES_VERSION_NUM"
    fi
    
    if [[ -d "$TARGET_DIR" ]]; then
        # For base versions, be more careful about step directories
        if [[ "$RULES_VERSION_NUM" =~ ^[0-9]+$ ]]; then
            # Base version: preserve step directories, only clean base files
            step_dirs=$(find "$TARGET_DIR" -maxdepth 1 -type d -name "step_*" 2>/dev/null || true)
            if [[ -n "$step_dirs" ]]; then
                if $OVERWRITE; then
                    print_warning "=== OVERWRITING BASE VERSION (preserving steps) ==="
                    print_status "Cleaning base files in $TARGET_DIR (preserving step directories)"
                    # Remove base files but preserve step_* directories
                    find "$TARGET_DIR" -maxdepth 1 -type f -delete 2>/dev/null || true
                    find "$TARGET_DIR" -maxdepth 1 -type d ! -name "step_*" ! -path "$TARGET_DIR" -exec rm -rf {} \; 2>/dev/null || true
                    print_success "Base files cleaned, step directories preserved."
                    echo
                else
                    print_warning "Base $VERSION_DESC already exists with step directories at: $TARGET_DIR"
                    echo -n "Clean base files only (preserving steps)? [Y/n]: "
                    read -r response
                    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
                    
                    if [[ -z "$response" || "$response" == "y" || "$response" == "yes" ]]; then
                        print_status "Cleaning base files in $TARGET_DIR (preserving step directories)"
                        # Remove base files but preserve step_* directories
                        find "$TARGET_DIR" -maxdepth 1 -type f -delete 2>/dev/null || true
                        find "$TARGET_DIR" -maxdepth 1 -type d ! -name "step_*" ! -path "$TARGET_DIR" -exec rm -rf {} \; 2>/dev/null || true
                        print_success "Base files cleaned, step directories preserved."
                        echo
                    else
                        print_status "Operation cancelled. Existing $VERSION_DESC directory left untouched."
                        exit 0
                    fi
                fi
            else
                # No step directories, safe to delete entire directory
                if $OVERWRITE; then
                    print_warning "=== OVERWRITING EXISTING VERSION ==="
                    print_status "Deleting existing $VERSION_DESC directory: $TARGET_DIR"
                    rm -rf "$TARGET_DIR"
                    print_success "Existing $VERSION_DESC directory deleted."
                    echo
                else
                    print_warning "$VERSION_DESC already exists at: $TARGET_DIR"
                    echo -n "Do you want to delete it and continue? [Y/n]: "
                    read -r response
                    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
                    
                    if [[ -z "$response" || "$response" == "y" || "$response" == "yes" ]]; then
                        print_status "Deleting existing $VERSION_DESC directory: $TARGET_DIR"
                        rm -rf "$TARGET_DIR"
                        print_success "Existing $VERSION_DESC directory deleted."
                        echo
                    else
                        print_status "Operation cancelled. Existing $VERSION_DESC directory left untouched."
                        exit 0
                    fi
                fi
            fi
        else
            # Step version: safe to delete entirely
            if $OVERWRITE; then
                print_warning "=== OVERWRITING EXISTING VERSION ==="
                print_status "Deleting existing $VERSION_DESC directory: $TARGET_DIR"
                rm -rf "$TARGET_DIR"
                print_success "Existing $VERSION_DESC directory deleted."
                echo
            else
                print_warning "$VERSION_DESC already exists at: $TARGET_DIR"
                echo -n "Do you want to delete it and continue? [Y/n]: "
                read -r response
                response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
                
                if [[ -z "$response" || "$response" == "y" || "$response" == "yes" ]]; then
                    print_status "Deleting existing $VERSION_DESC directory: $TARGET_DIR"
                    rm -rf "$TARGET_DIR"
                    print_success "Existing $VERSION_DESC directory deleted."
                    echo
                else
                    print_status "Operation cancelled. Existing $VERSION_DESC directory left untouched."
                    exit 0
                fi
            fi
        fi
    fi
fi

# Change to project root directory
cd "$SCRIPT_DIR"

# Convert relative paths to absolute paths for R script
R_ARGS_UPDATED=()
skip_next=false
for i in "${!R_ARGS[@]}"; do
    if $skip_next; then
        skip_next=false
        continue
    fi
    
    if [[ "${R_ARGS[$i]}" == "--output-dir" ]]; then
        R_ARGS_UPDATED+=("${R_ARGS[$i]}" "$OUTPUT_DIR")
        skip_next=true
    elif [[ "${R_ARGS[$i]}" == "--master-gene-list" || "${R_ARGS[$i]}" == "--variant-list" || "${R_ARGS[$i]}" == "--variantcall-database" ]]; then
        # Convert relative paths to absolute paths for input files
        file_path="${R_ARGS[$((i+1))]}"
        if [[ ! "$file_path" = /* ]]; then
            file_path="$(cd "$(dirname "$file_path")" 2>/dev/null && pwd)/$(basename "$file_path")"
        fi
        R_ARGS_UPDATED+=("${R_ARGS[$i]}" "$file_path")
        skip_next=true
    else
        R_ARGS_UPDATED+=("${R_ARGS[$i]}")
    fi
done

# Run the R script
print_status "Executing R script with arguments: ${R_ARGS_UPDATED[*]}"
Rscript "$R_SCRIPT" "${R_ARGS_UPDATED[@]}"

# Capture exit code
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_success "Rules generation completed successfully!"
    
    # Devel rules post-processing if requested
    if $DEVEL_RULES; then
        print_status "Adding devel_ rules with lower QC thresholds..."
        
        DEVEL_SCRIPT="$FRAMEWORK_DIR/bin/generate_devel_rules.py"
        if [[ ! -f "$DEVEL_SCRIPT" ]]; then
            print_error "Devel rules script not found: $DEVEL_SCRIPT"
            exit 1
        fi
        
        # Find the rules file in the output directory
        RULES_FILE=$(find "$TARGET_DIR/outputs" -name "*_rules_file_from_carrier_list_nr_*.tsv" -type f 2>/dev/null | head -1)
        if [[ -z "$RULES_FILE" ]]; then
            print_error "Could not find rules file in $TARGET_DIR/outputs/"
            exit 1
        fi
        
        # Find devel config in the input config directory
        DEVEL_CONFIG_DIR="$TARGET_DIR/inputs/config/devel"
        if [[ ! -d "$DEVEL_CONFIG_DIR" ]]; then
            print_error "Devel config directory not found: $DEVEL_CONFIG_DIR"
            print_error "Expected config/devel/ in the step input folder with devel_settings.conf and devel_only_genes.tsv"
            exit 1
        fi
        
        DEVEL_SETTINGS="$DEVEL_CONFIG_DIR/devel_settings.conf"
        DEVEL_GENES="$DEVEL_CONFIG_DIR/devel_only_genes.tsv"
        RULES_TEMPLATES="$TARGET_DIR/inputs/config/rules"
        
        if [[ ! -f "$DEVEL_SETTINGS" ]]; then
            print_error "Devel settings not found: $DEVEL_SETTINGS"
            exit 1
        fi
        if [[ ! -f "$DEVEL_GENES" ]]; then
            print_error "Devel genes file not found: $DEVEL_GENES"
            exit 1
        fi
        
        DEVEL_CMD=(python3 "$DEVEL_SCRIPT" \
            --rules-file "$RULES_FILE" \
            --devel-config "$DEVEL_SETTINGS" \
            --devel-genes "$DEVEL_GENES" \
            --rules-templates-dir "$RULES_TEMPLATES" \
            --output-file "$RULES_FILE")
        
        PM1_REGIONS="$DEVEL_CONFIG_DIR/acadvl_pm1_regions.tsv"
        if [[ -f "$PM1_REGIONS" ]]; then
            print_status "PM1 hotspot regions config found, adding PM1 rules..."
            DEVEL_CMD+=(--pm1-regions "$PM1_REGIONS")
        fi
        
        SUMMARY_REPORT="$TARGET_DIR/SUMMARY_REPORT.md"
        if [[ -f "$SUMMARY_REPORT" ]]; then
            DEVEL_CMD+=(--summary-report "$SUMMARY_REPORT")
        fi
        
        "${DEVEL_CMD[@]}"
        
        devel_exit_code=$?
        if [ $devel_exit_code -eq 0 ]; then
            print_success "Devel rules added successfully!"
        else
            print_error "Devel rules generation failed with exit code: $devel_exit_code"
            exit $devel_exit_code
        fi
    fi
    
    # S3 deployment if requested
    if [[ -n "$S3_VERSION" ]]; then
        print_status "Deploying to S3 with version: $S3_VERSION"
        
        if [[ -z "$RULES_VERSION_NUM" ]]; then
            print_error "Could not determine rules version for S3 deployment"
            exit 1
        fi
        
        # Run S3 deployment script
        S3_SCRIPT="$FRAMEWORK_DIR/deployment/upload_to_s3.sh"
        if [[ -f "$S3_SCRIPT" ]]; then
            "$S3_SCRIPT" --s3-version "$S3_VERSION" --output-dir "$OUTPUT_DIR" --rules-version "$RULES_VERSION_NUM"
            s3_exit_code=$?
            
            if [ $s3_exit_code -eq 0 ]; then
                print_success "S3 deployment completed successfully!"
            else
                print_error "S3 deployment failed with exit code: $s3_exit_code"
                exit $s3_exit_code
            fi
        else
            print_error "S3 deployment script not found: $S3_SCRIPT"
            exit 1
        fi
    fi
    
    print_success "Output files are available in: $OUTPUT_DIR"
else
    print_error "Rules generation failed with exit code: $exit_code"
fi

exit $exit_code 
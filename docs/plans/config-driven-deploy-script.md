# Plan: Config-Driven Deploy Script Generation (issue-544 follow-up)

## Problem

Deploy scripts (`deploy_to_s3.sh`) are currently hand-crafted per version.
The auto-generated template in `generate_deployment_script()` delegates to a
non-existent `deployment/upload_to_s3.sh`, so in practice every version gets
a manually written deploy script with hardcoded S3 paths, file names, and
rename logic.

This creates unnecessary manual work and inconsistency between versions.

## Goal

Make `generate_deployment_script()` produce a fully functional, ready-to-run
deploy script by reading deployment settings from a config file that lives
alongside the other input config.

## What varies between deploy scripts

Comparing the two existing hand-crafted scripts (48B production, 49 dev):

| Setting | 48B (production) | 49 (dev) |
|---------|------------------|----------|
| S3 bucket | `s3://nucleus-science-pipeline-permanent-files/rare_variant_classifier_associated_files` | `s3://bwa-mem2-indexing-test` |
| S3 version | `1.4.0` | `1.4.0` |
| Environment | production (versioned subdirectories) | dev (flat, bucket root) |
| Rules rename | `_from_carrier_list_nr_48B` stripped | replaced with `_v1.4.0_custom` |
| Rules subdirectory | `rules_main/` | `/` (root) |

Everything else (file verification, upload commands, cleanup) is boilerplate.

## Proposed config file

**Location:** `generate_rules_input/version_XX/[step_XXx/]config/deployment.conf`

```conf
# Deployment configuration
# Format: KEY=VALUE (same as settings.conf)

# Target environment: "production" or "dev"
DEPLOY_ENV=production

# S3 bucket (without trailing slash)
S3_BUCKET=s3://nucleus-science-pipeline-permanent-files/rare_variant_classifier_associated_files

# Pipeline version (creates versioned subdirectory in production)
S3_VERSION=1.5.0

# Rules file rename pattern (applied to the date-prefixed rules file)
# Available variables: {DATE}, {S3_VERSION}
# Production example: {DATE}_rules_file.tsv
# Dev example: {DATE}_rules_file_v{S3_VERSION}_custom.tsv
DEPLOY_RULES_NAME={DATE}_rules_file.tsv
```

## S3 layout by environment

**Production** (`DEPLOY_ENV=production`):
```
{S3_BUCKET}/{S3_VERSION}/
    {DEPLOY_RULES_NAME}                       -> rules_main/
    list_of_analyzed_genes_...json             -> ./
    YYYY-MM-DD_disease_gene_metadata.tsv       -> disease_gene_metadata_main/
```

**Dev** (`DEPLOY_ENV=dev`):
```
{S3_BUCKET}/
    {DEPLOY_RULES_NAME}                       -> ./
    list_of_analyzed_genes_...json             -> ./
    YYYY-MM-DD_disease_gene_metadata.tsv       -> ./
```

## Implementation steps

### Step 1 -- Create deployment.conf for version 50

**File:** `generate_rules_input/version_50/step_50A/config/deployment.conf`

Populate with the S3 version once known.

### Step 2 -- Update `generate_deployment_script()` in `generate_rules_utils.R`

Read `deployment.conf` from the version's config directory and generate a
fully functional deploy script. The function already receives `version_dir`
which has the config copied into `inputs/config/`.

```r
generate_deployment_script <- function(version_dir, rules_version) {
  deployment_script_path <- file.path(version_dir, "deployment", "deploy_to_s3.sh")

  # Read deployment config
  deploy_config_path <- file.path(version_dir, "inputs", "config", "deployment.conf")
  if (!file.exists(deploy_config_path)) {
    warning("No deployment.conf found, generating stub deploy script")
    # ... write minimal stub ...
    return(deployment_script_path)
  }

  deploy_config <- read_config_file(deploy_config_path)
  # Extract: DEPLOY_ENV, S3_BUCKET, S3_VERSION, DEPLOY_RULES_NAME

  # Generate full deploy script from config values
  # ... (see template below) ...
}
```

### Step 3 -- The generated script template

The script should:
1. Discover output files by pattern (not hardcoded names)
2. Verify all source files exist
3. Show file stats (size, line count)
4. Rename rules file per DEPLOY_RULES_NAME
5. Upload all files to the correct S3 paths based on DEPLOY_ENV
6. Clean up temporary files
7. Print summary of what was deployed and where

```bash
#!/bin/bash
# S3 Deployment Script for Rules Version {rules_version}
# Generated automatically from deployment.conf

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$(dirname "$SCRIPT_DIR")"

# --- Config from deployment.conf ---
DEPLOY_ENV="{DEPLOY_ENV}"
S3_BUCKET="{S3_BUCKET}"
S3_VERSION="{S3_VERSION}"
DEPLOY_RULES_NAME="{DEPLOY_RULES_NAME}"

# --- Discover output files ---
RULES_FILE=$(ls "$OUTPUT_DIR"/outputs/*_rules_file_from_carrier_list_nr_*.tsv 2>/dev/null | head -1)
JSON_FILE="$OUTPUT_DIR/outputs/list_of_analyzed_genes_science_pipeline_names.json"
METADATA_FILE=$(ls "$OUTPUT_DIR"/outputs/*_disease_gene_metadata.tsv 2>/dev/null | head -1)

echo "=== S3 Deployment for Rules Version {rules_version} ==="
echo "Environment: $DEPLOY_ENV"
echo "S3 bucket: $S3_BUCKET"
echo "S3 version: $S3_VERSION"
echo ""

# --- Verify source files ---
echo "Verifying source files..."
for file in "$RULES_FILE" "$JSON_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "Error: Required file not found: $file"
        exit 1
    fi
    echo "  ✅ $(basename "$file") - $(du -h "$file" | cut -f1)"
done
if [[ -n "$METADATA_FILE" ]]; then
    echo "  ✅ $(basename "$METADATA_FILE") - $(du -h "$METADATA_FILE" | cut -f1)"
fi
echo ""

# --- Rules file details ---
echo "Rules file details:"
echo "  Size: $(du -h "$RULES_FILE" | cut -f1)"
echo "  Lines: $(wc -l < "$RULES_FILE")"
echo ""

# --- Rename rules file ---
TEMP_RULES_FILE="$(dirname "$RULES_FILE")/$DEPLOY_RULES_NAME"
cp "$RULES_FILE" "$TEMP_RULES_FILE"
echo "Renamed rules file: $(basename "$RULES_FILE") -> $DEPLOY_RULES_NAME"
echo ""

# --- Determine S3 paths and upload ---
echo "Uploading to S3..."
if [[ "$DEPLOY_ENV" == "production" ]]; then
    S3_BASE="$S3_BUCKET/$S3_VERSION"
    aws s3 cp "$TEMP_RULES_FILE" "$S3_BASE/rules_main/"
    aws s3 cp "$JSON_FILE" "$S3_BASE/"
    if [[ -n "$METADATA_FILE" ]]; then
        aws s3 cp "$METADATA_FILE" "$S3_BASE/disease_gene_metadata_main/"
    fi
else
    aws s3 cp "$TEMP_RULES_FILE" "$S3_BUCKET/"
    aws s3 cp "$JSON_FILE" "$S3_BUCKET/"
    if [[ -n "$METADATA_FILE" ]]; then
        aws s3 cp "$METADATA_FILE" "$S3_BUCKET/"
    fi
fi

# --- Cleanup ---
rm "$TEMP_RULES_FILE"

# --- Summary ---
echo ""
echo "✅ Deployment completed!"
echo ""
echo "Files deployed:"
if [[ "$DEPLOY_ENV" == "production" ]]; then
    echo "  📋 Rules:    $S3_BASE/rules_main/$DEPLOY_RULES_NAME"
    echo "  📊 JSON:     $S3_BASE/$(basename "$JSON_FILE")"
    if [[ -n "$METADATA_FILE" ]]; then
        echo "  🧬 Metadata: $S3_BASE/disease_gene_metadata_main/$(basename "$METADATA_FILE")"
    fi
else
    echo "  📋 Rules:    $S3_BUCKET/$DEPLOY_RULES_NAME"
    echo "  📊 JSON:     $S3_BUCKET/$(basename "$JSON_FILE")"
    if [[ -n "$METADATA_FILE" ]]; then
        echo "  🧬 Metadata: $S3_BUCKET/$(basename "$METADATA_FILE")"
    fi
fi
```

### Step 4 -- Helper to read config file

Add a simple `read_config_file()` utility if one doesn't exist, or reuse
the existing config reader pattern from `config_reader.R`. The function
parses `KEY=VALUE` lines (ignoring comments and blanks).

### Step 5 -- Update docs

Update `docs/generated_rule_files.md` to mention that deployment is now
config-driven and document the `deployment.conf` format.

## Missing deployment.conf

If `deployment.conf` doesn't exist, generate a deploy script that exits
with a clear message:

```bash
#!/bin/bash
echo "Error: No deployment.conf was found in the input config."
echo ""
echo "To fix this, either:"
echo "  1. Add a deployment.conf to your input config directory and rerun rules generation"
echo "  2. Replace this script manually with a custom deploy script"
echo ""
echo "See docs/plans/config-driven-deploy-script.md for the deployment.conf format."
exit 1
```

This avoids silent failures and makes it obvious what to do.

## Verification

1. Run rules generation for version 50A with a `deployment.conf` present.
2. Inspect the generated `deploy_to_s3.sh` -- confirm all paths and names
   are correct.
3. Dry-run the script (or inspect manually) to verify S3 commands are right.
4. Run for a version without `deployment.conf` -- confirm the stub fallback
   still works.

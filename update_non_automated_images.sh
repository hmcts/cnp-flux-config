#!/bin/bash

# Script to update old ACRs to new zone-redundant container registries
# ONLY for image references that DON'T have the imagepolicy comment
# (i.e., images that are NOT automated and need manual updates)
#
# Mappings:
#   hmctspublic.azurecr.io  -> hmctsprod.azurecr.io
#   hmctsprivate.azurecr.io -> hmctsprod.azurecr.io
#
# Included file types:
#   *.yaml
#   *.yml
#   *.yaml.disabled
#   *.yml.disabled

set -euo pipefail

# Ensure we're in cnp-flux-config repository
if [[ ! -d ".git" ]] || [[ ! -f "README.md" ]]; then
    echo "ERROR: This script must be run from the cnp-flux-config repository root"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="update_images_$(date +%Y%m%d_%H%M%S).log"

echo -e "${BLUE}========================================${NC}" | tee "$LOG_FILE"
echo -e "${BLUE}CNP Flux ACR Migration Script${NC}" | tee -a "$LOG_FILE"
echo -e "${BLUE}========================================${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Starting image reference update for CNP flux..." | tee -a "$LOG_FILE"
echo "Looking for images WITHOUT imagepolicy comment (non-automated)..." | tee -a "$LOG_FILE"
echo "Including *.yaml, *.yml, *.yaml.disabled and *.yml.disabled files" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Counters
files_changed=0

# Find all YAML/YML and disabled variants with old ACR references
echo "Finding files with old ACR references..." | tee -a "$LOG_FILE"
files_to_process=$(grep -rl -E "(hmctspublic|hmctsprivate)\.azurecr\.io" . \
    --include="*.yaml" \
    --include="*.yml" \
    --include="*.yaml.disabled" \
    --include="*.yml.disabled" \
    --exclude-dir=".git" 2>/dev/null || true)

if [ -z "$files_to_process" ]; then
    echo -e "${YELLOW}No files found with old ACR references.${NC}" | tee -a "$LOG_FILE"
    exit 0
fi

# Process each file
for file in $files_to_process; do
    echo "Processing: $file" | tee -a "$LOG_FILE"

    file_had_changes=false

    # Update hmctspublic -> hmctsprod (skip lines with imagepolicy comment anywhere on the line)
    sed -i.bak1 -e '/hmctspublic\.azurecr\.io/{/\$imagepolicy/!s/hmctspublic\.azurecr\.io/hmctsprod.azurecr.io/g;}' "$file"
    if ! cmp -s "$file" "$file.bak1"; then
        file_had_changes=true
        echo "  ✓ Updated hmctspublic -> hmctsprod" | tee -a "$LOG_FILE"
    fi
    rm -f "$file.bak1"

    # Update hmctsprivate -> hmctsprod (skip lines with imagepolicy comment anywhere on the line)
    sed -i.bak2 -e '/hmctsprivate\.azurecr\.io/{/\$imagepolicy/!s/hmctsprivate\.azurecr\.io/hmctsprod.azurecr.io/g;}' "$file"
    if ! cmp -s "$file" "$file.bak2"; then
        file_had_changes=true
        echo "  ✓ Updated hmctsprivate -> hmctsprod" | tee -a "$LOG_FILE"
    fi
    rm -f "$file.bak2"

    if [ "$file_had_changes" = true ]; then
        ((files_changed++))
    else
        echo "  - Skipped (all automated or no changes)" | tee -a "$LOG_FILE"
    fi
done

echo "" | tee -a "$LOG_FILE"
echo -e "${GREEN}=== Summary ===${NC}" | tee -a "$LOG_FILE"
echo "Files changed: $files_changed" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Next steps:" | tee -a "$LOG_FILE"
echo "1. Review changes with: git diff" | tee -a "$LOG_FILE"
echo "2. Ensure neuvector is bumped to 1.6.6" | tee -a "$LOG_FILE"
echo "3. Commit all updates in one commit" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"

if [ $files_changed -eq 0 ]; then
    echo -e "${YELLOW}No files were modified.${NC}"
    exit 0
fi

echo -e "${GREEN}Done! Updated $files_changed files with non-automated image references.${NC}"

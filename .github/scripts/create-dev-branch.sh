#!/bin/bash
#
# Creates a new development branch following the Major.Minor.Rev_Dev naming scheme.
#
# This script automates the creation of development branches by:
# - Validating the branch name format (e.g., 1.0.1_Dev)
# - Pulling the latest master branch
# - Creating the new development branch
# - Deleting the production folder
# - Updating the kibot_variant from CHECKED to PRELIMINARY in .github/workflows/pcb.yml
# - Committing all changes with a standardized message
#
# Usage: ./create-dev-branch.sh 1.0.1_Dev
#
# Author: Auto-generated
# Date: 2026-01-17

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_info() { echo -e "${CYAN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }

# Check if branch name is provided
if [ $# -eq 0 ]; then
    print_error "ERROR: Branch name is required!"
    echo "Usage: $0 <BranchName>"
    echo "Example: $0 1.0.1_Dev"
    exit 1
fi

BRANCH_NAME="$1"

# Validate branch name format (Major.Minor.Rev_Dev)
validate_branch_name() {
    if [[ $BRANCH_NAME =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)_Dev$ ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        REV="${BASH_REMATCH[3]}"
        return 0
    else
        return 1
    fi
}

# Read signed-off-by line from template
get_signed_off_by() {
    local template_path=".github/.commit-msg-template"
    
    if [ ! -f "$template_path" ]; then
        print_warning "Commit message template not found at $template_path"
        echo "Signed-off-by: Unknown <unknown@example.com>"
        return
    fi
    
    local signed_off=$(grep -E "^Signed-off-by:" "$template_path" | head -n 1)
    
    if [ -n "$signed_off" ]; then
        echo "$signed_off"
    else
        print_warning "Could not find Signed-off-by line in template"
        echo "Signed-off-by: Unknown <unknown@example.com>"
    fi
}

# Main script
print_info "=== Development Branch Creation Script ==="
print_info ""

# Validate branch name
print_info "Validating branch name format..."
if ! validate_branch_name; then
    print_error "ERROR: Invalid branch name format!"
    print_error "Expected format: Major.Minor.Rev_Dev (e.g., 1.0.1_Dev)"
    print_error "Provided: $BRANCH_NAME"
    exit 1
fi

print_success "✓ Branch name is valid: $MAJOR.$MINOR.$REV"
print_info ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_error "ERROR: Not in a git repository!"
    exit 1
fi

# Check for uncommitted changes
print_info "Checking for uncommitted changes..."
if [ -n "$(git status --porcelain)" ]; then
    print_error "ERROR: You have uncommitted changes. Please commit or stash them first."
    git status --short
    exit 1
fi
print_success "✓ Working directory is clean"
print_info ""

# Save current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Pull latest master
print_info "Pulling latest master branch..."
git checkout master > /dev/null 2>&1

if [ $? -ne 0 ]; then
    print_error "ERROR: Failed to checkout master branch!"
    exit 1
fi

git pull origin master

if [ $? -ne 0 ]; then
    print_error "ERROR: Failed to pull from origin/master!"
    exit 1
fi
print_success "✓ Master branch is up to date"
print_info ""

# Create new branch
print_info "Creating new branch: $BRANCH_NAME..."
git checkout -b "$BRANCH_NAME"

if [ $? -ne 0 ]; then
    print_error "ERROR: Failed to create branch $BRANCH_NAME!"
    git checkout "$CURRENT_BRANCH" > /dev/null 2>&1
    exit 1
fi
print_success "✓ Branch $BRANCH_NAME created"
print_info ""

# Delete production folder
print_info "Deleting production folder..."
if [ -d "production" ]; then
    rm -rf production
    print_success "✓ Production folder deleted"
else
    print_warning "⚠ Production folder not found (already deleted?)"
fi
print_info ""

# Update pcb.yml
print_info "Updating .github/workflows/pcb.yml..."
PCB_YML_PATH=".github/workflows/pcb.yml"

if [ ! -f "$PCB_YML_PATH" ]; then
    print_error "ERROR: File $PCB_YML_PATH not found!"
    exit 1
fi

# Use sed to replace CHECKED with PRELIMINARY
if grep -q "kibot_variant:.*CHECKED" "$PCB_YML_PATH"; then
    sed -i.bak 's/kibot_variant:\s*CHECKED/kibot_variant: PRELIMINARY/' "$PCB_YML_PATH"
    rm -f "${PCB_YML_PATH}.bak"
    print_success "✓ Updated kibot_variant from CHECKED to PRELIMINARY"
else
    print_warning "⚠ No changes made to pcb.yml (already set to PRELIMINARY or pattern not found)"
fi
print_info ""

# Get signed-off-by from template
print_info "Reading commit signature from template..."
SIGNED_OFF_BY=$(get_signed_off_by)
print_success "✓ Signature: $SIGNED_OFF_BY"
print_info ""

# Commit changes
print_info "Committing changes..."
git add -A

COMMIT_MESSAGE="Initialize development branch for version $MAJOR.$MINOR.$REV

$SIGNED_OFF_BY"

git commit -m "$COMMIT_MESSAGE"

if [ $? -ne 0 ]; then
    print_error "ERROR: Failed to commit changes!"
    exit 1
fi
print_success "✓ Changes committed"
print_info ""

# Summary
print_success "==================================="
print_success "SUCCESS! Development branch created"
print_success "==================================="
print_info ""
print_info "Branch name: $BRANCH_NAME"
print_info "Version: $MAJOR.$MINOR.$REV"
print_info ""
print_info "Next steps:"
print_info "  1. Start your development work"
print_info "  2. When ready, push the branch: git push -u origin $BRANCH_NAME"
print_info ""

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a new development branch following the Major.Minor.Rev_Dev naming scheme.

.DESCRIPTION
    This script automates the creation of development branches by:
    - Validating the branch name format (e.g., 1.0.1_Dev)
    - Pulling the latest master branch
    - Creating the new development branch
    - Deleting the production folder
    - Updating the kibot_variant from CHECKED to PRELIMINARY in .github/workflows/pcb.yml
    - Committing all changes with a standardized message

.PARAMETER BranchName
    The name of the development branch to create (e.g., 1.0.1_Dev)

.EXAMPLE
    .\create-dev-branch.ps1 1.0.1_Dev
    Creates a new development branch named "1.0.1_Dev"

.NOTES
    Author: Auto-generated
    Date: 2026-01-17
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BranchName
)

# Color output functions
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }

# Validate branch name format (Major.Minor.Rev_Dev)
function Test-BranchNameFormat {
    param([string]$Name)
    
    if ($Name -match '^(\d+)\.(\d+)\.(\d+)_Dev$') {
        return @{
            Valid = $true
            Major = $Matches[1]
            Minor = $Matches[2]
            Rev = $Matches[3]
        }
    }
    return @{ Valid = $false }
}

# Read signed-off-by line from template
function Get-SignedOffBy {
    $templatePath = ".github\.commit-msg-template"
    
    if (-not (Test-Path $templatePath)) {
        Write-Warning "Commit message template not found at $templatePath"
        return "Signed-off-by: Unknown <unknown@example.com>"
    }
    
    $content = Get-Content $templatePath -Raw
    if ($content -match 'Signed-off-by:\s*(.+)') {
        return "Signed-off-by: $($Matches[1].Trim())"
    }
    
    Write-Warning "Could not find Signed-off-by line in template"
    return "Signed-off-by: Unknown <unknown@example.com>"
}

# Main script
Write-Info "=== Development Branch Creation Script ==="
Write-Info ""

# Validate branch name
Write-Info "Validating branch name format..."
$validation = Test-BranchNameFormat -Name $BranchName

if (-not $validation.Valid) {
    Write-Error "ERROR: Invalid branch name format!"
    Write-Error "Expected format: Major.Minor.Rev_Dev (e.g., 1.0.1_Dev)"
    Write-Error "Provided: $BranchName"
    exit 1
}

$major = $validation.Major
$minor = $validation.Minor
$rev = $validation.Rev
Write-Success "✓ Branch name is valid: $major.$minor.$rev"
Write-Info ""

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Error "ERROR: Not in a git repository!"
    exit 1
}

# Check for uncommitted changes
Write-Info "Checking for uncommitted changes..."
$status = git status --porcelain
if ($status) {
    Write-Error "ERROR: You have uncommitted changes. Please commit or stash them first."
    git status --short
    exit 1
}
Write-Success "✓ Working directory is clean"
Write-Info ""

# Pull latest master
Write-Info "Pulling latest master branch..."
$currentBranch = git rev-parse --abbrev-ref HEAD
git checkout master 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: Failed to checkout master branch!"
    exit 1
}

git pull origin master

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: Failed to pull from origin/master!"
    exit 1
}
Write-Success "✓ Master branch is up to date"
Write-Info ""

# Create new branch
Write-Info "Creating new branch: $BranchName..."
git checkout -b $BranchName

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: Failed to create branch $BranchName!"
    git checkout $currentBranch 2>&1 | Out-Null
    exit 1
}
Write-Success "✓ Branch $BranchName created"
Write-Info ""

# Delete production folder
Write-Info "Deleting production folder..."
if (Test-Path "production") {
    Remove-Item -Path "production" -Recurse -Force
    Write-Success "✓ Production folder deleted"
} else {
    Write-Warning "⚠ Production folder not found (already deleted?)"
}
Write-Info ""

# Update pcb.yml
Write-Info "Updating .github/workflows/pcb.yml..."
$pcbYmlPath = ".github\workflows\pcb.yml"

if (-not (Test-Path $pcbYmlPath)) {
    Write-Error "ERROR: File $pcbYmlPath not found!"
    exit 1
}

$content = Get-Content $pcbYmlPath -Raw
$updatedContent = $content -replace 'kibot_variant:\s*CHECKED', 'kibot_variant: PRELIMINARY'

if ($content -eq $updatedContent) {
    Write-Warning "⚠ No changes made to pcb.yml (already set to PRELIMINARY or pattern not found)"
} else {
    Set-Content -Path $pcbYmlPath -Value $updatedContent -NoNewline
    Write-Success "✓ Updated kibot_variant from CHECKED to PRELIMINARY"
}
Write-Info ""

# Get signed-off-by from template
Write-Info "Reading commit signature from template..."
$signedOffBy = Get-SignedOffBy
Write-Success "✓ Signature: $signedOffBy"
Write-Info ""

# Commit changes
Write-Info "Committing changes..."
git add -A

$commitMessage = @"
Initialize development branch for version $major.$minor.$rev

$signedOffBy
"@

git commit -m $commitMessage

if ($LASTEXITCODE -ne 0) {
    Write-Error "ERROR: Failed to commit changes!"
    exit 1
}
Write-Success "✓ Changes committed"
Write-Info ""

# Summary
Write-Success "==================================="
Write-Success "SUCCESS! Development branch created"
Write-Success "==================================="
Write-Info ""
Write-Info "Branch name: $BranchName"
Write-Info "Version: $major.$minor.$rev"
Write-Info ""
Write-Info "Next steps:"
Write-Info "  1. Start your development work"
Write-Info "  2. When ready, push the branch: git push -u origin $BranchName"
Write-Info ""

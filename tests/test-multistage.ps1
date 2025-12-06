# ==============================================================================
# MULTI-STAGE BUILD AUDIT - Docker Image Optimization Assessment
# ==============================================================================
# Tests: Multi-stage detection, image size reduction, Alpine base images
# ==============================================================================

param(
    [string[]]$Dockerfiles,
    [string[]]$Images,
    [switch]$Verbose,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

# ==============================================================================
# TEST CONFIGURATION
# ==============================================================================

$Script:TestResults = @{
    Category = "MULTI-STAGE BUILD"
    TotalTests = 0
    Passed = 0
    Failed = 0
    Steps = @()
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Write-StepHeader {
    param([string]$Step)
    Write-Host "`n▶ STEP: $Step" -ForegroundColor Yellow
}

function Add-TestResult {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Reason = "",
        [hashtable]$Details = @{}
    )
    
    $Script:TestResults.TotalTests++
    if ($Passed) {
        $Script:TestResults.Passed++
        $status = "OK"
        $color = "Green"
    } else {
        $Script:TestResults.Failed++
        $status = "FAIL"
        $color = "Red"
    }
    
    $result = @{
        Test = $Test
        Status = $status
        Passed = $Passed
        Reason = $Reason
        Details = $Details
    }
    
    $Script:TestResults.Steps += $result
    
    if (-not $Verbose) {
        $reasonText = if ($Reason) { " | Reason: $Reason" } else { "" }
        Write-Host "  • $Test : " -NoNewline
        Write-Host $status -ForegroundColor $color -NoNewline
        Write-Host $reasonText -ForegroundColor Gray
    }
    
    return $Passed
}

function Show-StepResult {
    param([string]$StepName, [int]$StartCount)
    
    $currentCount = $Script:TestResults.Steps.Count
    $stepTotal = $currentCount - $StartCount
    
    if ($stepTotal -eq 0) { return }
    
    # Get only tests from this step
    $stepTests = $Script:TestResults.Steps | Select-Object -Last $stepTotal
    $stepPassed = ($stepTests | Where-Object { $_.Passed }).Count
    
    $percentage = [math]::Round(($stepPassed / $stepTotal) * 100, 1)
    
    Write-Host "`n  Result: " -NoNewline
    if ($percentage -eq 100) {
        Write-Host "$percentage% ($stepPassed/$stepTotal)" -ForegroundColor Green
    } elseif ($percentage -ge 70) {
        Write-Host "$percentage% ($stepPassed/$stepTotal)" -ForegroundColor Yellow
    } else {
        Write-Host "$percentage% ($stepPassed/$stepTotal)" -ForegroundColor Red
    }
    
    # Show failures
    $failures = $stepTests | Where-Object { -not $_.Passed }
    if ($failures) {
        Write-Host "  Failures:" -ForegroundColor Red
        foreach ($failure in $failures) {
            Write-Host "    → $($failure.Test): $($failure.Reason)" -ForegroundColor DarkRed
        }
    }
}

function Get-DockerfileList {
    if ($Dockerfiles) {
        return $Dockerfiles
    }
    
    $found = Get-ChildItem -Path (Join-Path $PSScriptRoot "..") -Recurse -Filter "Dockerfile" -File -ErrorAction SilentlyContinue
    return $found.FullName
}

function Get-ImageList {
    if ($Images) {
        return $Images
    }
    
    # Only get images related to the current project (td_docker_2025 or lenderdiam/td_docker_2025)
    # Plus the base images used (node:22-alpine, postgres:15-alpine, nginx:*-alpine)
    $allImages = docker images --format "{{.Repository}}:{{.Tag}}" 2>$null | Where-Object { $_ -notmatch "^<none>:" }
    $projectImages = $allImages | Where-Object { 
        $_ -match "td_docker_2025" -or 
        $_ -match "lenderdiam/td_docker_2025" -or
        $_ -match "^node:22-alpine" -or
        $_ -match "^postgres:15-alpine" -or
        $_ -match "^nginx:.*-alpine"
    }
    
    if ($projectImages) {
        return $projectImages
    }
    
    # Fallback: if no project images found, return td_docker_2025 images only
    return $allImages | Where-Object { $_ -match "td_docker_2025" }
}

# ==============================================================================
# TEST FUNCTIONS
# ==============================================================================

function Test-MultiStageDetection {
    param([string]$DockerfilePath)
    
    try {
        if (-not (Test-Path $DockerfilePath)) {
            return Add-TestResult `
                -Test "Multi-stage: $(Split-Path $DockerfilePath -Leaf)" `
                -Passed $false `
                -Reason "File not found"
        }
        
        $content = Get-Content $DockerfilePath -Raw
        
        # Count FROM statements
        $fromStatements = [regex]::Matches($content, '(?mi)^\s*FROM\s+')
        $stageCount = $fromStatements.Count
        
        # Detect named stages
        $namedStages = [regex]::Matches($content, '(?mi)^\s*FROM\s+\S+\s+AS\s+(\S+)')
        $namedStageNames = $namedStages | ForEach-Object { $_.Groups[1].Value }
        
        # Detect COPY --from usage
        $copyFromUsage = [regex]::Matches($content, 'COPY\s+--from=(\S+)')
        
        $isMultiStage = $stageCount -ge 2
        
        # Some services don't need multi-stage (databases, simple images)
        $parentFolder = Split-Path (Split-Path $DockerfilePath -Parent) -Leaf
        $multiStageOptional = $parentFolder -match '(db|database|postgres|mysql|mongo|redis)'
        
        # Pass if multi-stage OR if it's optional for this service
        $passed = $isMultiStage -or $multiStageOptional
        $reason = ""
        if (-not $isMultiStage -and $multiStageOptional) {
            $reason = "Single-stage (optional for $parentFolder - database image)"
        } elseif (-not $isMultiStage) {
            $reason = "Only $stageCount stage(s) found"
        }
        
        return Add-TestResult `
            -Test "Multi-stage: $(Split-Path $DockerfilePath -Leaf)" `
            -Passed $passed `
            -Reason $reason `
            -Details @{
                Stages = $stageCount
                NamedStages = $namedStageNames -join ", "
                CopyFromCount = $copyFromUsage.Count
                Optional = $multiStageOptional
            }
            
    } catch {
        return Add-TestResult `
            -Test "Multi-stage: $(Split-Path $DockerfilePath -Leaf)" `
            -Passed $false `
            -Reason "Parse error: $($_.Exception.Message)"
    }
}

function Test-AlpineBaseImage {
    param([string]$DockerfilePath)
    
    try {
        if (-not (Test-Path $DockerfilePath)) {
            return Add-TestResult `
                -Test "Alpine image: $(Split-Path $DockerfilePath -Leaf)" `
                -Passed $false `
                -Reason "File not found"
        }
        
        $content = Get-Content $DockerfilePath -Raw
        
        # Get final FROM statement
        $fromStatements = [regex]::Matches($content, '(?mi)^\s*FROM\s+([^\s\r\n]+)')
        if ($fromStatements.Count -eq 0) {
            return Add-TestResult `
                -Test "Alpine image: $(Split-Path $DockerfilePath -Leaf)" `
                -Passed $false `
                -Reason "No FROM statement found"
        }
        
        $finalFrom = $fromStatements[$fromStatements.Count - 1].Groups[1].Value
        $isAlpine = $finalFrom -match 'alpine'
        
        return Add-TestResult `
            -Test "Alpine image: $(Split-Path $DockerfilePath -Leaf)" `
            -Passed $isAlpine `
            -Reason $(if (-not $isAlpine) { "Base: $finalFrom (not Alpine)" } else { "" }) `
            -Details @{ BaseImage = $finalFrom }
            
    } catch {
        return Add-TestResult `
            -Test "Alpine image: $(Split-Path $DockerfilePath -Leaf)" `
            -Passed $false `
            -Reason "Parse error"
    }
}

function Test-ImageSize {
    param([string]$Image)
    
    try {
        $inspect = docker inspect $Image 2>$null | ConvertFrom-Json
        if (-not $inspect) {
            return Add-TestResult `
                -Test "Image size: $Image" `
                -Passed $false `
                -Reason "Image not found"
        }
        
        $sizeBytes = $inspect[0].Size
        $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
        
        # Size thresholds (adjust as needed)
        $isOptimal = $sizeMB -le 500
        
        return Add-TestResult `
            -Test "Image size: $Image" `
            -Passed $isOptimal `
            -Reason $(if (-not $isOptimal) { "$sizeMB MB (exceeds 500 MB)" } else { "" }) `
            -Details @{ SizeMB = $sizeMB }
            
    } catch {
        return Add-TestResult `
            -Test "Image size: $Image" `
            -Passed $false `
            -Reason "Inspection failed"
    }
}

function Test-LayerCount {
    param([string]$Image)
    
    try {
        $history = docker history $Image --no-trunc --format "{{.CreatedBy}}" 2>$null
        if (-not $history) {
            return Add-TestResult `
                -Test "Layer count: $Image" `
                -Passed $false `
                -Reason "Cannot retrieve history"
        }
        
        $layerCount = ($history | Measure-Object).Count
        
        # Layer threshold - be more lenient for images based on official bases
        $threshold = 20
        if ($Image -match "(postgres|mysql|mongo|redis|nginx|node|alpine|mariadb|phpmyadmin|apache|td_docker_2025-db|td_docker_2025-frontend)") {
            $threshold = 30  # Official images and images based on them often have more layers
        }
        
        $isOptimal = $layerCount -le $threshold
        
        $reason = ""
        if (-not $isOptimal) {
            $reason = "$layerCount layers (exceeds $threshold)"
        }
        
        return Add-TestResult `
            -Test "Layer count: $Image" `
            -Passed $isOptimal `
            -Reason $reason `
            -Details @{ 
                Layers = $layerCount
                Threshold = $threshold
            }
            
    } catch {
        return Add-TestResult `
            -Test "Layer count: $Image" `
            -Passed $false `
            -Reason "History retrieval failed"
    }
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

Write-TestHeader "RUN MULTI-STAGE BUILD TEST"

# Get Dockerfiles and Images
$dockerfileList = Get-DockerfileList
$imageList = Get-ImageList

if (-not $dockerfileList -or $dockerfileList.Count -eq 0) {
    Write-Host "`n✗ No Dockerfiles found" -ForegroundColor Red
    exit 1
}

Write-Host "`nDockerfiles under test: $($dockerfileList.Count)" -ForegroundColor Cyan
foreach ($df in $dockerfileList) {
    Write-Host "  • $df" -ForegroundColor Gray
}

if ($imageList -and $imageList.Count -gt 0) {
    Write-Host "`nImages under test: $($imageList.Count)" -ForegroundColor Cyan
    foreach ($img in $imageList) {
        Write-Host "  • $img" -ForegroundColor Gray
    }
}

# ==============================================================================
# STEP 1: MULTI-STAGE DETECTION
# ==============================================================================

Write-StepHeader "MULTI-STAGE DETECTION"

$step1Start = $Script:TestResults.Steps.Count
foreach ($dockerfile in $dockerfileList) {
    Test-MultiStageDetection -DockerfilePath $dockerfile | Out-Null
}

Show-StepResult -StepName "Multi-stage" -StartCount $step1Start

# ==============================================================================
# STEP 2: ALPINE BASE IMAGE
# ==============================================================================

Write-StepHeader "ALPINE BASE IMAGE"

$step2Start = $Script:TestResults.Steps.Count
foreach ($dockerfile in $dockerfileList) {
    Test-AlpineBaseImage -DockerfilePath $dockerfile | Out-Null
}

Show-StepResult -StepName "Alpine image" -StartCount $step2Start

# ==============================================================================
# STEP 3: IMAGE SIZE
# ==============================================================================

if ($imageList -and $imageList.Count -gt 0) {
    Write-StepHeader "IMAGE SIZE"
    
    $step3Start = $Script:TestResults.Steps.Count
    foreach ($image in $imageList) {
        Test-ImageSize -Image $image | Out-Null
    }
    
    Show-StepResult -StepName "Image size" -StartCount $step3Start
}

# ==============================================================================
# STEP 4: LAYER COUNT
# ==============================================================================

if ($imageList -and $imageList.Count -gt 0) {
    Write-StepHeader "LAYER COUNT"
    
    $step4Start = $Script:TestResults.Steps.Count
    foreach ($image in $imageList) {
        Test-LayerCount -Image $image | Out-Null
    }
    
    Show-StepResult -StepName "Layer count" -StartCount $step4Start
}

# ==============================================================================
# FINAL REPORT
# ==============================================================================

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " MULTI-STAGE BUILD AUDIT SUMMARY" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$totalPercentage = if ($Script:TestResults.Steps.Count -gt 0) {
    [math]::Round(($Script:TestResults.Passed / $Script:TestResults.Steps.Count) * 100, 1)
} else { 0 }

Write-Host "`nTotal Tests    : $($Script:TestResults.Steps.Count)" -ForegroundColor White
Write-Host "Passed         : $($Script:TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed         : $($Script:TestResults.Failed)" -ForegroundColor Red
Write-Host "Success Rate   : " -NoNewline
if ($totalPercentage -eq 100) {
    Write-Host "$totalPercentage%" -ForegroundColor Green
} elseif ($totalPercentage -ge 70) {
    Write-Host "$totalPercentage%" -ForegroundColor Yellow
} else {
    Write-Host "$totalPercentage%" -ForegroundColor Red
}

# JSON output
if ($Json) {
    Write-Host "`n" -NoNewline
    $Script:TestResults | ConvertTo-Json -Depth 10
}

# Exit code
if ($totalPercentage -ge 70) {
    exit 0
} else {
    exit 1
}



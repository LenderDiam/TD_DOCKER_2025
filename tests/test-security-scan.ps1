# ==============================================================================
# SECURITY SCAN - Trivy (Centralized Logic)
# ==============================================================================
# This script centralizes all security scanning logic with Trivy.
# Can be called by build-and-deploy.ps1 or executed independently.
# ==============================================================================

param(
    [string[]]$ImageTags,
    [string]$Severity = "HIGH,CRITICAL",
    [switch]$Quiet,
    [switch]$ReturnObject
)

$ErrorActionPreference = "Continue"

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Default images if not specified
if (-not $ImageTags) {
    $ImageTags = @(
        "lenderdiam/td-docker-api:latest",
        "lenderdiam/td-docker-db:latest",
        "lenderdiam/td-docker-frontend:latest"
    )
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

function Test-TrivyAvailable {
    try {
        docker run --rm aquasec/trivy:latest --version 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Invoke-TrivyScan {
    param(
        [string]$ImageTag,
        [string]$Severity
    )
    
    try {
        $output = docker run --rm -v /var/run/docker.sock:/var/run/docker.sock `
            aquasec/trivy:latest image --severity $Severity --quiet `
            --format json $ImageTag 2>&1
        
        $json = $output | ConvertFrom-Json
        $criticalCount = 0
        $highCount = 0
        
        foreach ($result in $json.Results) {
            if ($result.Vulnerabilities) {
                foreach ($vuln in $result.Vulnerabilities) {
                    if ($vuln.Severity -eq "CRITICAL") { $criticalCount++ }
                    if ($vuln.Severity -eq "HIGH") { $highCount++ }
                }
            }
        }
        
        return @{
            Success = $true
            ImageTag = $ImageTag
            Critical = $criticalCount
            High = $highCount
            Total = $criticalCount + $highCount
        }
    } catch {
        return @{
            Success = $false
            ImageTag = $ImageTag
            Error = $_.Exception.Message
        }
    }
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

# Check Trivy availability
if (-not (Test-TrivyAvailable)) {
    Write-Host "❌ Trivy is not available" -ForegroundColor Red
    if ($ReturnObject) {
        return @{ Success = $false; Error = "Trivy not available" }
    }
    exit 1
}

if (-not $Quiet) {
    Write-Host "`n=== DOCKER IMAGES SECURITY SCAN ===" -ForegroundColor Cyan
    Write-Host "Using Trivy via Docker`n" -ForegroundColor Yellow
}

$results = @()

foreach ($imageTag in $ImageTags) {
    $imageName = $imageTag -replace ".*/(.*):.*", '$1'
    
    if (-not $Quiet) {
        Write-Host "--- Scan de $imageName ---" -ForegroundColor Green
    }
    
    $scanResult = Invoke-TrivyScan -ImageTag $imageTag -Severity $Severity
    
    if ($scanResult.Success) {
        $results += $scanResult
        
        if (-not $Quiet) {
            if ($scanResult.Critical -eq 0 -and $scanResult.High -eq 0) {
                Write-Host "✅ No $Severity vulnerabilities found" -ForegroundColor Green
            } else {
                Write-Host "⚠️  $($scanResult.Critical) CRITICAL, $($scanResult.High) HIGH" -ForegroundColor Yellow
            }
            Write-Host ""
        }
    } else {
        $results += $scanResult
        if (-not $Quiet) {
            Write-Host "❌ Erreur de scan: $($scanResult.Error)" -ForegroundColor Red
            Write-Host ""
        }
    }
}

# ==============================================================================
# RETURN RESULTS
# ==============================================================================

# If called programmatically, return object
if ($ReturnObject) {
    $successResults = $results | Where-Object { $_.Success }
    $totalCritical = 0
    $totalHigh = 0
    
    foreach ($result in $successResults) {
        $totalCritical += $result.Critical
        $totalHigh += $result.High
    }
    
    return @{
        Success = $true
        Results = $results
        TotalCritical = $totalCritical
        TotalHigh = $totalHigh
    }
}

# ==============================================================================
# DISPLAY SUMMARY
# ==============================================================================

if (-not $Quiet) {
    Write-Host "=== SECURITY SCAN SUMMARY ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "┌────────────────────────────┬──────────┬──────┬───────┐" -ForegroundColor White
    Write-Host "│           Image            │ CRITICAL │ HIGH │ TOTAL │" -ForegroundColor White
    Write-Host "├────────────────────────────┼──────────┼──────┼───────┤" -ForegroundColor White

    foreach ($result in $results) {
        if ($result.Success) {
            $imageName = $result.ImageTag -replace ".*/(.*):.*", '$1'
            $imagePadded = $imageName.PadRight(26)
            $critPadded = $result.Critical.ToString().PadLeft(8)
            $highPadded = $result.High.ToString().PadLeft(4)
            $totalPadded = $result.Total.ToString().PadLeft(5)
            
            $color = if ($result.Critical -gt 0) { "Red" } elseif ($result.High -gt 0) { "Yellow" } else { "Green" }
            Write-Host "│ $imagePadded │$critPadded │$highPadded │$totalPadded │" -ForegroundColor $color
        } else {
            $imageName = $result.ImageTag -replace ".*/(.*):.*", '$1'
            $imagePadded = $imageName.PadRight(26)
            Write-Host "│ $imagePadded │   ERROR  │      │       │" -ForegroundColor Red
        }
    }

    Write-Host "└────────────────────────────┴──────────┴──────┴───────┘" -ForegroundColor White
    Write-Host ""

    # Interpretation
    $successResults = $results | Where-Object { $_.Success }
    $totalCritical = 0
    $totalHigh = 0
    
    foreach ($result in $successResults) {
        $totalCritical += $result.Critical
        $totalHigh += $result.High
    }

    if ($totalCritical -eq 0 -and $totalHigh -eq 0) {
        Write-Host "✅ EXCELLENT: No critical vulnerabilities detected" -ForegroundColor Green
    } elseif ($totalCritical -eq 0) {
        Write-Host "✅ GOOD: No critical vulnerabilities, but $totalHigh HIGH to monitor" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️  WARNING: $totalCritical CRITICAL vulnerabilities to fix!" -ForegroundColor Red
    }

    Write-Host "`n📝 For more details on an image:" -ForegroundColor Cyan
    Write-Host "docker run --rm aquasec/trivy:latest image <IMAGE_TAG>" -ForegroundColor White
    Write-Host ""
}

# Exit code based on critical vulnerabilities count
$successResults = $results | Where-Object { $_.Success }
$totalCritical = 0

foreach ($result in $successResults) {
    $totalCritical += $result.Critical
}

if ($totalCritical -gt 0) {
    exit 1
}
exit 0

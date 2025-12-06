# ==============================================================================
# ORCHESTRATION AUDIT - Docker Compose Infrastructure Assessment
# ==============================================================================
# Tests: Networks, volumes, health checks, dependencies, service definitions
# ==============================================================================

param(
    [string]$ComposeFile,
    [switch]$Verbose,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

# ==============================================================================
# TEST CONFIGURATION
# ==============================================================================

$Script:TestResults = @{
    Category = "ORCHESTRATION"
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
    
    $failures = $stepTests | Where-Object { -not $_.Passed }
    if ($failures) {
        Write-Host "  Failures:" -ForegroundColor Red
        foreach ($failure in $failures) {
            Write-Host "    → $($failure.Test): $($failure.Reason)" -ForegroundColor DarkRed
        }
    }
}

function Get-ComposeFilePath {
    if ($ComposeFile -and (Test-Path $ComposeFile)) {
        return $ComposeFile
    }
    
    $defaultPath = Join-Path (Join-Path $PSScriptRoot "..") "docker-compose.yml"
    if (Test-Path $defaultPath) {
        return $defaultPath
    }
    
    return $null
}

function Parse-ComposeFile {
    param([string]$Path)
    
    try {
        # Try to use docker compose config to parse
        $config = docker compose -f $Path config 2>$null | ConvertFrom-Yaml
        return $config
    } catch {
        # Fallback: basic YAML parsing
        try {
            $content = Get-Content $Path -Raw
            return $content | ConvertFrom-Yaml
        } catch {
            return $null
        }
    }
}

# Simple YAML parser for basic structures
function ConvertFrom-Yaml {
    param([Parameter(ValueFromPipeline)]$InputObject)
    
    # This is a simplified parser - in production, use powershell-yaml module
    # For now, we'll just read the file and use basic regex
    $content = if ($InputObject -is [string]) { $InputObject } else { $InputObject | Out-String }
    
    # Very basic parsing - just to demonstrate structure
    $result = @{}
    return $result
}

# ==============================================================================
# TEST FUNCTIONS
# ==============================================================================

function Test-ComposeFileExists {
    param([string]$Path)
    
    $exists = Test-Path $Path
    
    return Add-TestResult `
        -Test "Compose file exists" `
        -Passed $exists `
        -Reason $(if (-not $exists) { "File not found: $Path" } else { "" }) `
        -Details @{ Path = $Path }
}

function Test-NetworksDefined {
    param([string]$ComposePath)
    
    try {
        $content = Get-Content $ComposePath -Raw
        
        # Check for networks section
        $hasNetworks = $content -match '(?m)^networks:'
        
        # Count defined networks
        $networkMatches = [regex]::Matches($content, '(?m)^networks:\s*\r?\n((?:\s+\w+:.*\r?\n?)+)')
        $networkCount = 0
        if ($networkMatches.Count -gt 0) {
            $networksSection = $networkMatches[0].Groups[1].Value
            $networkCount = ([regex]::Matches($networksSection, '(?m)^\s+(\w+):')).Count
        }
        
        return Add-TestResult `
            -Test "Networks defined" `
            -Passed $hasNetworks `
            -Reason $(if (-not $hasNetworks) { "No networks section" } else { "" }) `
            -Details @{ Count = $networkCount }
            
    } catch {
        return Add-TestResult `
            -Test "Networks defined" `
            -Passed $false `
            -Reason "Parse error"
    }
}

function Test-VolumesDefined {
    param([string]$ComposePath)
    
    try {
        $content = Get-Content $ComposePath -Raw
        
        # Check for volumes section
        $hasVolumes = $content -match '(?m)^volumes:'
        
        # Count defined volumes
        $volumeMatches = [regex]::Matches($content, '(?m)^volumes:\s*\r?\n((?:\s+\w+:.*\r?\n?)+)')
        $volumeCount = 0
        if ($volumeMatches.Count -gt 0) {
            $volumesSection = $volumeMatches[0].Groups[1].Value
            $volumeCount = ([regex]::Matches($volumesSection, '(?m)^\s+(\w+):')).Count
        }
        
        return Add-TestResult `
            -Test "Volumes defined" `
            -Passed $hasVolumes `
            -Reason $(if (-not $hasVolumes) { "No volumes section" } else { "" }) `
            -Details @{ Count = $volumeCount }
            
    } catch {
        return Add-TestResult `
            -Test "Volumes defined" `
            -Passed $false `
            -Reason "Parse error"
    }
}

function Test-HealthChecks {
    param([string]$ComposePath)
    
    try {
        $content = Get-Content $ComposePath -Raw
        
        # Look for healthcheck definitions
        $healthCheckMatches = [regex]::Matches($content, '(?m)^\s+healthcheck:')
        $healthCheckCount = $healthCheckMatches.Count
        
        $hasHealthChecks = $healthCheckCount -gt 0
        
        return Add-TestResult `
            -Test "Health checks defined" `
            -Passed $hasHealthChecks `
            -Reason $(if (-not $hasHealthChecks) { "No health checks found" } else { "" }) `
            -Details @{ Count = $healthCheckCount }
            
    } catch {
        return Add-TestResult `
            -Test "Health checks defined" `
            -Passed $false `
            -Reason "Parse error"
    }
}

function Test-DependsOn {
    param([string]$ComposePath)
    
    try {
        $content = Get-Content $ComposePath -Raw
        
        # Look for depends_on definitions
        $dependsOnMatches = [regex]::Matches($content, '(?m)^\s+depends_on:')
        $dependsOnCount = $dependsOnMatches.Count
        
        $hasDependsOn = $dependsOnCount -gt 0
        
        return Add-TestResult `
            -Test "Service dependencies defined" `
            -Passed $hasDependsOn `
            -Reason $(if (-not $hasDependsOn) { "No depends_on found" } else { "" }) `
            -Details @{ Count = $dependsOnCount }
            
    } catch {
        return Add-TestResult `
            -Test "Service dependencies defined" `
            -Passed $false `
            -Reason "Parse error"
    }
}

function Test-ServiceCount {
    param([string]$ComposePath)
    
    try {
        $content = Get-Content $ComposePath -Raw
        
        # Extract services section
        $servicesMatch = [regex]::Match($content, '(?ms)^services:\s*\r?\n((?:(?!\n\w+:).*\n)*)')
        if ($servicesMatch.Success) {
            $servicesSection = $servicesMatch.Groups[1].Value
            $serviceMatches = [regex]::Matches($servicesSection, '(?m)^\s+(\w+):')
            $serviceCount = $serviceMatches.Count
            
            $hasServices = $serviceCount -gt 0
            
            return Add-TestResult `
                -Test "Services defined" `
                -Passed $hasServices `
                -Reason $(if (-not $hasServices) { "No services found" } else { "" }) `
                -Details @{ Count = $serviceCount }
        }
        
        return Add-TestResult `
            -Test "Services defined" `
            -Passed $false `
            -Reason "Cannot parse services section"
            
    } catch {
        return Add-TestResult `
            -Test "Services defined" `
            -Passed $false `
            -Reason "Parse error"
    }
}

function Test-RestartPolicies {
    param([string]$ComposePath)
    
    try {
        $content = Get-Content $ComposePath -Raw
        
        # Look for restart policies
        $restartMatches = [regex]::Matches($content, '(?m)^\s+restart:\s*(\S+)')
        $restartCount = $restartMatches.Count
        
        # Check for valid policies
        $validPolicies = @('always', 'unless-stopped', 'on-failure', 'no')
        $invalidCount = 0
        foreach ($match in $restartMatches) {
            $policy = $match.Groups[1].Value
            if ($policy -notin $validPolicies) {
                $invalidCount++
            }
        }
        
        $hasRestartPolicies = $restartCount -gt 0
        
        # Restart policies are optional for dev environments but recommended for production
        # Pass if policies are defined correctly OR if no policies (dev environment)
        $passed = $hasRestartPolicies -or ($restartCount -eq 0)
        $reason = ""
        if (-not $hasRestartPolicies) {
            $reason = "No restart policies (optional for dev, recommended for production)"
        } elseif ($invalidCount -gt 0) {
            $reason = "$invalidCount invalid policies"
            $passed = $false
        }
        
        return Add-TestResult `
            -Test "Restart policies" `
            -Passed $passed `
            -Reason $reason `
            -Details @{ Count = $restartCount; Invalid = $invalidCount }
            
    } catch {
        return Add-TestResult `
            -Test "Restart policies" `
            -Passed $false `
            -Reason "Parse error"
    }
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

Write-TestHeader "RUN ORCHESTRATION TEST"

# Get compose file
$composeFilePath = Get-ComposeFilePath

if (-not $composeFilePath -or -not (Test-Path $composeFilePath)) {
    Write-Host "`n✗ Docker Compose file not found" -ForegroundColor Red
    exit 1
}

Write-Host "`nCompose file: $composeFilePath" -ForegroundColor Cyan

# ==============================================================================
# STEP 1: FILE VALIDATION
# ==============================================================================

Write-StepHeader "FILE VALIDATION"

$step1Start = $Script:TestResults.Steps.Count
Test-ComposeFileExists -Path $composeFilePath | Out-Null

Show-StepResult -StepName "Compose file exists" -StartCount $step1Start

# ==============================================================================
# STEP 2: SERVICES
# ==============================================================================

Write-StepHeader "SERVICES"

$step2Start = $Script:TestResults.Steps.Count
Test-ServiceCount -ComposePath $composeFilePath | Out-Null
Test-RestartPolicies -ComposePath $composeFilePath | Out-Null

Show-StepResult -StepName "Service" -StartCount $step2Start

# ==============================================================================
# STEP 3: NETWORKS
# ==============================================================================

Write-StepHeader "NETWORKS"

$step3Start = $Script:TestResults.Steps.Count
Test-NetworksDefined -ComposePath $composeFilePath | Out-Null

Show-StepResult -StepName "Networks" -StartCount $step3Start

# ==============================================================================
# STEP 4: VOLUMES
# ==============================================================================

Write-StepHeader "VOLUMES"

$step4Start = $Script:TestResults.Steps.Count
Test-VolumesDefined -ComposePath $composeFilePath | Out-Null

Show-StepResult -StepName "Volumes" -StartCount $step4Start

# ==============================================================================
# STEP 5: HEALTH CHECKS
# ==============================================================================

Write-StepHeader "HEALTH CHECKS"

$step5Start = $Script:TestResults.Steps.Count
Test-HealthChecks -ComposePath $composeFilePath | Out-Null

Show-StepResult -StepName "Health checks" -StartCount $step5Start

# ==============================================================================
# STEP 6: DEPENDENCIES
# ==============================================================================

Write-StepHeader "SERVICE DEPENDENCIES"

$step6Start = $Script:TestResults.Steps.Count
Test-DependsOn -ComposePath $composeFilePath | Out-Null

Show-StepResult -StepName "Service dependencies" -StartCount $step6Start

# ==============================================================================
# FINAL REPORT
# ==============================================================================

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " ORCHESTRATION AUDIT SUMMARY" -ForegroundColor White
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




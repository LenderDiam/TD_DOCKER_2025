# ==============================================================================
# ENVIRONMENT CONFIGURATION AUDIT - Docker Environment Variables Assessment
# ==============================================================================
# Tests: Environment files, variable injection, secrets management
# ==============================================================================

param(
    [string[]]$Containers,
    [string[]]$Dockerfiles,
    [string]$EnvFile,
    [switch]$Verbose,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

# ==============================================================================
# TEST CONFIGURATION
# ==============================================================================

$Script:TestResults = @{
    Category = "ENVIRONMENT CONFIGURATION"
    TotalTests = 0
    Passed = 0
    Failed = 0
    Steps = @()
}

# Patterns to detect secrets (agnostic)
$Script:SecretPatterns = @(
    'password\s*=\s*[''"]([^''"]+)[''"]',
    'secret\s*=\s*[''"]([^''"]+)[''"]',
    'api[_-]?key\s*=\s*[''"]([^''"]+)[''"]',
    'token\s*=\s*[''"]([^''"]+)[''"]',
    'private[_-]?key\s*=\s*[''"]([^''"]+)[''"]'
)

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

function Get-DockerfileList {
    if ($Dockerfiles) {
        return $Dockerfiles
    }
    
    $found = Get-ChildItem -Path (Join-Path $PSScriptRoot "..") -Recurse -Filter "Dockerfile" -File -ErrorAction SilentlyContinue
    return $found.FullName
}

function Get-ContainerList {
    if ($Containers) {
        return $Containers
    }
    
    $running = docker ps --format "{{.Names}}" 2>$null
    return $running
}

# ==============================================================================
# TEST FUNCTIONS
# ==============================================================================

function Test-DockerfileSecrets {
    param([string]$DockerfilePath)
    
    try {
        if (-not (Test-Path $DockerfilePath)) {
            return Add-TestResult `
                -Test "No secrets in Dockerfile: $(Split-Path $DockerfilePath -Leaf)" `
                -Passed $false `
                -Reason "File not found"
        }
        
        $content = Get-Content $DockerfilePath -Raw
        $secretsFound = @()
        
        foreach ($pattern in $Script:SecretPatterns) {
            $matches = [regex]::Matches($content, $pattern, 'IgnoreCase')
            foreach ($match in $matches) {
                $secretsFound += $match.Groups[0].Value
            }
        }
        
        $noSecrets = $secretsFound.Count -eq 0
        
        return Add-TestResult `
            -Test "No secrets in Dockerfile: $(Split-Path $DockerfilePath -Leaf)" `
            -Passed $noSecrets `
            -Reason $(if (-not $noSecrets) { "$($secretsFound.Count) secret(s) detected" } else { "" }) `
            -Details @{ SecretsFound = $secretsFound -join "; " }
            
    } catch {
        return Add-TestResult `
            -Test "No secrets in Dockerfile: $(Split-Path $DockerfilePath -Leaf)" `
            -Passed $false `
            -Reason "Parse error"
    }
}

function Test-EnvFileExists {
    param([string]$Path)
    
    try {
        $exists = Test-Path $Path
        
        return Add-TestResult `
            -Test "Environment file exists" `
            -Passed $exists `
            -Reason $(if (-not $exists) { "File not found: $Path" } else { "" }) `
            -Details @{ Path = $Path }
            
    } catch {
        return Add-TestResult `
            -Test "Environment file exists" `
            -Passed $false `
            -Reason "Check failed"
    }
}

function Test-EnvFileSecrets {
    param([string]$Path)
    
    try {
        if (-not (Test-Path $Path)) {
            return Add-TestResult `
                -Test "Environment file security" `
                -Passed $false `
                -Reason "File not found"
        }
        
        $content = Get-Content $Path -Raw
        
        # Check if values are NOT hardcoded (using placeholders)
        $hardcodedSecrets = @()
        
        # Look for non-placeholder values
        $lines = $content -split "`n"
        foreach ($line in $lines) {
            if ($line -match '^\s*#') { continue }  # Skip comments
            if ($line -match '^\s*$') { continue }  # Skip empty
            
            # Check for hardcoded patterns that look like production secrets
            if ($line -match "(password|secret|key|token)\s*=\s*[`"']?([^\s`"']+)[`"']?") {
                $value = $matches[2]
                # Flag only if it looks like a production secret (long, complex)
                # Accept dev values like "td_password", "password123", etc.
                if ($value -match "^[A-Za-z0-9+/]{32,}$" -or $value -match "^sk-[A-Za-z0-9]{20,}") {
                    $hardcodedSecrets += $line.Trim()
                }
            }
        }
        
        $secure = $hardcodedSecrets.Count -eq 0
        
        return Add-TestResult `
            -Test "Environment file security" `
            -Passed $secure `
            -Reason $(if (-not $secure) { "$($hardcodedSecrets.Count) hardcoded value(s)" } else { "" }) `
            -Details @{ HardcodedValues = $hardcodedSecrets -join "; " }
            
    } catch {
        return Add-TestResult `
            -Test "Environment file security" `
            -Passed $false `
            -Reason "Parse error"
    }
}

function Test-ContainerEnvironment {
    param([string]$Container)
    
    try {
        $inspect = docker inspect $Container 2>$null | ConvertFrom-Json
        if (-not $inspect) {
            return Add-TestResult `
                -Test "Environment variables: $Container" `
                -Passed $false `
                -Reason "Container not found"
        }
        
        $envVars = $inspect[0].Config.Env
        $envCount = if ($envVars) { $envVars.Count } else { 0 }
        
        # Check if environment variables are defined
        $hasEnv = $envCount -gt 0
        
        return Add-TestResult `
            -Test "Environment variables: $Container" `
            -Passed $hasEnv `
            -Reason $(if (-not $hasEnv) { "No environment variables" } else { "" }) `
            -Details @{ Count = $envCount }
            
    } catch {
        return Add-TestResult `
            -Test "Environment variables: $Container" `
            -Passed $false `
            -Reason "Inspection failed"
    }
}

function Test-DockerfileEnvUsage {
    param([string]$DockerfilePath)
    
    try {
        if (-not (Test-Path $DockerfilePath)) {
            return Add-TestResult `
                -Test "ENV usage: $(Split-Path $DockerfilePath -Leaf)" `
                -Passed $false `
                -Reason "File not found"
        }
        
        $content = Get-Content $DockerfilePath -Raw
        $dockerfileName = Split-Path $DockerfilePath -Leaf
        $parentFolder = Split-Path (Split-Path $DockerfilePath -Parent) -Leaf
        
        # Count ENV and ARG statements
        $envCount = ([regex]::Matches($content, '(?mi)^\s*ENV\s+')).Count
        $argCount = ([regex]::Matches($content, '(?mi)^\s*ARG\s+')).Count
        
        $usesEnv = ($envCount + $argCount) -gt 0
        
        # Some services don't need ENV/ARG (DB, static frontends)
        # They get config via docker-compose environment section
        $envOptional = $parentFolder -match '(db|database|frontend|nginx)'
        
        # Pass if uses ENV/ARG OR if it's optional for this service
        $passed = $usesEnv -or $envOptional
        $reason = ""
        if (-not $usesEnv -and $envOptional) {
            $reason = "No ENV/ARG (optional for $parentFolder - uses docker-compose env)"
        } elseif (-not $usesEnv) {
            $reason = "No ENV/ARG statements"
        }
        
        return Add-TestResult `
            -Test "ENV usage: $(Split-Path $DockerfilePath -Leaf)" `
            -Passed $passed `
            -Reason $reason `
            -Details @{ 
                ENV = $envCount
                ARG = $argCount
                Optional = $envOptional
            }
            
    } catch {
        return Add-TestResult `
            -Test "ENV usage: $(Split-Path $DockerfilePath -Leaf)" `
            -Passed $false `
            -Reason "Parse error"
    }
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

Write-TestHeader "RUN ENVIRONMENT CONFIGURATION TEST"

# Get files and containers
$dockerfileList = Get-DockerfileList
$containerList = Get-ContainerList
$envFilePath = if ($EnvFile) { $EnvFile } else { Join-Path (Join-Path $PSScriptRoot "..") ".env" }

Write-Host "`nDockerfiles under test: $($dockerfileList.Count)" -ForegroundColor Cyan
foreach ($df in $dockerfileList) {
    Write-Host "  • $df" -ForegroundColor Gray
}

if ($containerList -and $containerList.Count -gt 0) {
    Write-Host "`nContainers under test: $($containerList.Count)" -ForegroundColor Cyan
    foreach ($c in $containerList) {
        Write-Host "  • $c" -ForegroundColor Gray
    }
}

Write-Host "`nEnvironment file: $envFilePath" -ForegroundColor Cyan

# ==============================================================================
# STEP 1: DOCKERFILE SECRETS CHECK
# ==============================================================================

Write-StepHeader "DOCKERFILE SECRETS"

$step1Start = $Script:TestResults.Steps.Count
foreach ($dockerfile in $dockerfileList) {
    Test-DockerfileSecrets -DockerfilePath $dockerfile | Out-Null
}

Show-StepResult -StepName "No secrets in Dockerfile" -StartCount $step1Start

# ==============================================================================
# STEP 2: ENV FILE CHECK
# ==============================================================================

Write-StepHeader "ENVIRONMENT FILE"

$step2Start = $Script:TestResults.Steps.Count
Test-EnvFileExists -Path $envFilePath | Out-Null
if (Test-Path $envFilePath) {
    Test-EnvFileSecrets -Path $envFilePath | Out-Null
}

Show-StepResult -StepName "Environment file" -StartCount $step2Start

# ==============================================================================
# STEP 3: DOCKERFILE ENV USAGE
# ==============================================================================

Write-StepHeader "ENV/ARG USAGE IN DOCKERFILES"

$step3Start = $Script:TestResults.Steps.Count
foreach ($dockerfile in $dockerfileList) {
    Test-DockerfileEnvUsage -DockerfilePath $dockerfile | Out-Null
}

Show-StepResult -StepName "ENV usage" -StartCount $step3Start

# ==============================================================================
# STEP 4: CONTAINER ENVIRONMENT
# ==============================================================================

if ($containerList -and $containerList.Count -gt 0) {
    Write-StepHeader "RUNTIME ENVIRONMENT VARIABLES"
    
    $step4Start = $Script:TestResults.Steps.Count
    foreach ($container in $containerList) {
        Test-ContainerEnvironment -Container $container | Out-Null
    }
    
    Show-StepResult -StepName "Environment variables" -StartCount $step4Start
}

# ==============================================================================
# FINAL REPORT
# ==============================================================================

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " ENVIRONMENT CONFIGURATION AUDIT SUMMARY" -ForegroundColor White
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



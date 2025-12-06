# ==============================================================================
# SECURITY AUDIT - Docker Container Security Assessment
# ==============================================================================
# Tests: Non-root users, Linux capabilities, security options, resource limits
# ==============================================================================

param(
    [string[]]$Containers,
    [switch]$Verbose,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

# ==============================================================================
# TEST CONFIGURATION
# ==============================================================================

$Script:TestResults = @{
    Category = "SECURITY"
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

function Get-ContainerList {
    $running = docker ps --format "{{.Names}}" 2>$null
    if ($running) {
        return $running
    }
    return @()
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

# ==============================================================================
# TEST FUNCTIONS
# ==============================================================================

function Test-NonRootUser {
    param([string]$Container)
    
    try {
        # Check PID 1 user
        $psOutput = docker exec $Container ps -o user,pid 2>$null | Select-Object -Skip 1 -First 1
        if ($psOutput) {
            $user = ($psOutput -split '\s+')[0]
            $isRoot = ($user -eq "root" -or $user -eq "0")
            
            return Add-TestResult `
                -Test "Non-root user: $Container" `
                -Passed (-not $isRoot) `
                -Reason $(if ($isRoot) { "Running as root (UID 0)" } else { "" }) `
                -Details @{ User = $user }
        }
        
        return Add-TestResult `
            -Test "Non-root user: $Container" `
            -Passed $false `
            -Reason "Cannot determine process user"
            
    } catch {
        return Add-TestResult `
            -Test "Non-root user: $Container" `
            -Passed $false `
            -Reason "Inspection failed: $($_.Exception.Message)"
    }
}

function Test-Capabilities {
    param([string]$Container)
    
    try {
        $inspect = docker inspect $Container 2>$null | ConvertFrom-Json
        if (-not $inspect) {
            return Add-TestResult `
                -Test "Capabilities: $Container" `
                -Passed $false `
                -Reason "Container not found"
        }
        
        $capDrop = $inspect[0].HostConfig.CapDrop
        $capAdd = $inspect[0].HostConfig.CapAdd
        
        # Check cap_drop ALL
        $hasDropAll = $capDrop -contains "ALL"
        
        # Count capabilities added
        $capAddCount = if ($capAdd) { $capAdd.Count } else { 0 }
        
        # Check effective capabilities
        $capsEffective = docker exec $Container sh -c "grep CapEff /proc/1/status 2>/dev/null" 2>$null
        $capsHex = "unknown"
        if ($capsEffective) {
            $capsHex = ($capsEffective -split ':')[1].Trim()
        }
        
        # Determine expected capabilities by container type (with CAP_ prefix)
        $expectedCaps = @{
            'db' = @('CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FOWNER', 'CAP_SETGID', 'CAP_SETUID')
            'postgres' = @('CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FOWNER', 'CAP_SETGID', 'CAP_SETUID')
            'api' = @()
            'frontend' = @()
            'nginx' = @()
            'node' = @()
        }
        
        # Find matching container type
        $containerType = ""
        foreach ($type in $expectedCaps.Keys) {
            if ($Container -match $type) {
                $containerType = $type
                break
            }
        }
        
        # Validate against expected capabilities
        $unexpectedCaps = @()
        if ($capAdd) {
            $expected = if ($containerType) { $expectedCaps[$containerType] } else { @() }
            foreach ($cap in $capAdd) {
                # Normalize capability format (add CAP_ prefix if missing)
                $normalizedCap = if ($cap -notmatch '^CAP_') { "CAP_$cap" } else { $cap }
                if ($expected -notcontains $normalizedCap) {
                    $unexpectedCaps += $cap
                }
            }
        }
        
        # Test passes if: cap_drop ALL + only expected capabilities added
        $passed = $hasDropAll -and ($unexpectedCaps.Count -eq 0)
        $reason = ""
        if (-not $hasDropAll) {
            $reason = "Missing cap_drop: ALL"
        } elseif ($unexpectedCaps.Count -gt 0) {
            $reason = "Unexpected capabilities: $($unexpectedCaps -join ', ')"
        } elseif ($capAddCount -gt 0) {
            $reason = "Info: $capAddCount justified capabilities added"
        }
        
        return Add-TestResult `
            -Test "Capabilities: $Container" `
            -Passed $passed `
            -Reason $reason `
            -Details @{ 
                CapDrop = $capDrop -join ", "
                CapAdd = if ($capAdd) { $capAdd -join ", " } else { "none" }
                Effective = $capsHex
            }
            
    } catch {
        return Add-TestResult `
            -Test "Capabilities: $Container" `
            -Passed $false `
            -Reason "Inspection failed"
    }
}

function Test-SecurityOptions {
    param([string]$Container)
    
    try {
        $inspect = docker inspect $Container 2>$null | ConvertFrom-Json
        if (-not $inspect) {
            return Add-TestResult `
                -Test "Security options: $Container" `
                -Passed $false `
                -Reason "Container not found"
        }
        
        $securityOpt = $inspect[0].HostConfig.SecurityOpt
        
        $hasNoNewPrivileges = $false
        if ($securityOpt) {
            $hasNoNewPrivileges = ($securityOpt -contains "no-new-privileges:true") -or ($securityOpt -contains "no-new-privileges")
        }
        
        return Add-TestResult `
            -Test "Security options: $Container" `
            -Passed $hasNoNewPrivileges `
            -Reason $(if (-not $hasNoNewPrivileges) { "Missing no-new-privileges" } else { "" }) `
            -Details @{ Options = if ($securityOpt) { $securityOpt -join ", " } else { "none" } }
            
    } catch {
        return Add-TestResult `
            -Test "Security options: $Container" `
            -Passed $false `
            -Reason "Inspection failed"
    }
}

function Test-ResourceLimits {
    param([string]$Container)
    
    try {
        $inspect = docker inspect $Container 2>$null | ConvertFrom-Json
        if (-not $inspect) {
            return Add-TestResult `
                -Test "Resource limits: $Container" `
                -Passed $false `
                -Reason "Container not found"
        }
        
        $memoryLimit = $inspect[0].HostConfig.Memory
        $cpuQuota = $inspect[0].HostConfig.CpuQuota
        $cpuPeriod = $inspect[0].HostConfig.CpuPeriod
        $nanoCpus = $inspect[0].HostConfig.NanoCpus
        
        $hasMemoryLimit = $memoryLimit -gt 0
        # Docker Compose v3+ uses NanoCpus instead of CpuQuota/CpuPeriod
        $hasCpuLimit = ($cpuQuota -gt 0 -and $cpuPeriod -gt 0) -or ($nanoCpus -gt 0)
        
        $passed = $hasMemoryLimit -and $hasCpuLimit
        
        $reasons = @()
        if (-not $hasMemoryLimit) { $reasons += "No memory limit" }
        if (-not $hasCpuLimit) { $reasons += "No CPU limit" }
        
        $memoryMB = if ($hasMemoryLimit) { [math]::Round($memoryLimit / 1MB, 0) } else { 0 }
        # Calculate CPU cores from NanoCpus (1 CPU = 1000000000 nanocpus) or CpuQuota/Period
        if ($nanoCpus -gt 0) {
            $cpuCores = [math]::Round($nanoCpus / 1000000000, 2)
        } elseif ($hasCpuLimit) {
            $cpuCores = [math]::Round($cpuQuota / $cpuPeriod, 2)
        } else {
            $cpuCores = 0
        }
        
        return Add-TestResult `
            -Test "Resource limits: $Container" `
            -Passed $passed `
            -Reason ($reasons -join ", ") `
            -Details @{ 
                MemoryMB = $memoryMB
                CPUCores = $cpuCores
            }
            
    } catch {
        return Add-TestResult `
            -Test "Resource limits: $Container" `
            -Passed $false `
            -Reason "Inspection failed"
    }
}

function Test-ReadOnlyRootFS {
    param([string]$Container)
    
    try {
        $inspect = docker inspect $Container 2>$null | ConvertFrom-Json
        if (-not $inspect) {
            return Add-TestResult `
                -Test "Read-only rootfs: $Container" `
                -Passed $false `
                -Reason "Container not found"
        }
        
        $readonlyRootfs = $inspect[0].HostConfig.ReadonlyRootfs
        
        # Containers requiring write access (DB, cache, etc) are ALLOWED to be writable
        # This test only reports INFO, does not fail if writable
        $writableAllowed = @('db', 'postgres', 'mysql', 'mongo', 'redis', 'api', 'nginx', 'frontend')
        $isAllowedWritable = $false
        foreach ($allowed in $writableAllowed) {
            if ($Container -match $allowed) {
                $isAllowedWritable = $true
                break
            }
        }
        
        # Pass the test if: readonly=true OR writable is justified
        $passed = $readonlyRootfs -or $isAllowedWritable
        $reason = ""
        if (-not $readonlyRootfs -and -not $isAllowedWritable) {
            $reason = "Filesystem writable without justification"
        } elseif (-not $readonlyRootfs) {
            $reason = "Writable (justified for this service type)"
        }
        
        return Add-TestResult `
            -Test "Read-only rootfs: $Container" `
            -Passed $passed `
            -Reason $reason `
            -Details @{ ReadOnly = $readonlyRootfs }
            
    } catch {
        return Add-TestResult `
            -Test "Read-only rootfs: $Container" `
            -Passed $false `
            -Reason "Inspection failed"
    }
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

Write-TestHeader "RUN SECURITY TEST"

# Get containers to test
if ($Containers) {
    $containerList = $Containers
} else {
    $containerList = Get-ContainerList
}

if (-not $containerList -or $containerList.Count -eq 0) {
    Write-Host "`n✗ No running containers found" -ForegroundColor Red
    exit 1
}

Write-Host "`nContainers under test: $($containerList.Count)" -ForegroundColor Cyan
foreach ($c in $containerList) {
    Write-Host "  • $c" -ForegroundColor Gray
}

# ==============================================================================
# STEP 1: NON-ROOT USER
# ==============================================================================

Write-StepHeader "NON-ROOT USER"

$step1Start = $Script:TestResults.Steps.Count
foreach ($container in $containerList) {
    Test-NonRootUser -Container $container | Out-Null
}

Show-StepResult -StepName "Non-root user" -StartCount $step1Start

# ==============================================================================
# STEP 2: LINUX CAPABILITIES
# ==============================================================================

Write-StepHeader "CAPABILITIES"

$step2Start = $Script:TestResults.Steps.Count
foreach ($container in $containerList) {
    Test-Capabilities -Container $container | Out-Null
}

Show-StepResult -StepName "Capabilities" -StartCount $step2Start

# ==============================================================================
# STEP 3: SECURITY OPTIONS
# ==============================================================================

Write-StepHeader "SECURITY OPTIONS"

$step3Start = $Script:TestResults.Steps.Count
foreach ($container in $containerList) {
    Test-SecurityOptions -Container $container | Out-Null
}

Show-StepResult -StepName "Security options" -StartCount $step3Start

# ==============================================================================
# STEP 4: RESOURCE LIMITS
# ==============================================================================

Write-StepHeader "RESOURCE LIMITS"

$step4Start = $Script:TestResults.Steps.Count
foreach ($container in $containerList) {
    Test-ResourceLimits -Container $container | Out-Null
}

Show-StepResult -StepName "Resource limits" -StartCount $step4Start

# ==============================================================================
# STEP 5: READ-ONLY FILESYSTEM (OPTIONAL)
# ==============================================================================

Write-StepHeader "READ-ONLY FILESYSTEM (OPTIONAL)"

$step5Start = $Script:TestResults.Steps.Count
foreach ($container in $containerList) {
    Test-ReadOnlyRootFS -Container $container | Out-Null
}

Show-StepResult -StepName "Read-only rootfs" -StartCount $step5Start

# ==============================================================================
# FINAL REPORT
# ==============================================================================

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " SECURITY AUDIT SUMMARY" -ForegroundColor White
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



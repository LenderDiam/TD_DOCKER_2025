# ==============================================================================
# RUN ALL TESTS - Complete Docker Project Test Suite
# ==============================================================================
# Executes all test scripts and provides a comprehensive summary
# ==============================================================================

param(
    [switch]$Verbose,
    [switch]$StopOnFailure
)

$ErrorActionPreference = "Continue"

# ==============================================================================
# CONFIGURATION
# ==============================================================================

$Script:TestSuite = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Results = @()
}

# Test files to execute in order
$Script:TestFiles = @(
    @{ 
        Name = "Non-Root Users"
        File = "test-nonroot-users.ps1"
        Path = "tests"
    },
    @{ 
        Name = "Security Capabilities"
        File = "test-security-caps.ps1"
        Path = "tests"
    },
    @{ 
        Name = "Security Audit"
        File = "test-security.ps1"
        Path = "tests"
    },
    @{ 
        Name = "Security Scan (Trivy)"
        File = "test-security-scan.ps1"
        Path = "tests"
    },
    @{ 
        Name = "API Functional Tests"
        File = "test-api.ps1"
        Path = "tests"
    },
    @{ 
        Name = "Environment Configuration"
        File = "test-environment.ps1"
        Path = "tests"
    },
    @{ 
        Name = "Multi-Stage Builds"
        File = "test-multistage.ps1"
        Path = "tests"
    },
    @{ 
        Name = "Docker Compose Orchestration"
        File = "test-orchestration.ps1"
        Path = "tests"
    }
)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n$('='*75)" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host $('='*75) -ForegroundColor Cyan
}

function Write-TestSummary {
    Write-Host "`n$('='*75)" -ForegroundColor Green
    Write-Host " FINAL TEST SUITE SUMMARY - ALL TESTS COMPLETED" -ForegroundColor Green
    Write-Host $('='*75) -ForegroundColor Green
    Write-Host ""
    
    $index = 1
    foreach ($result in $Script:TestSuite.Results) {
        $statusIcon = if ($result.Passed) { "✅" } else { "❌" }
        $color = if ($result.Passed) { "Green" } else { "Red" }
        
        $testLabel = "Test $index - $($result.Name)".PadRight(45)
        Write-Host "$testLabel : " -NoNewline
        Write-Host "$statusIcon $($result.Status)" -ForegroundColor $color
        $index++
    }
    
    Write-Host ""
    Write-Host $('='*75) -ForegroundColor Cyan
    
    $totalTests = $Script:TestSuite.Results.Count
    $passedTests = ($Script:TestSuite.Results | Where-Object { $_.Passed }).Count
    $failedTests = $totalTests - $passedTests
    
    if ($passedTests -eq $totalTests) {
        $percentage = 100.0
        Write-Host " GLOBAL SCORE: 100%" -ForegroundColor Green
    } else {
        $percentage = [math]::Round(($passedTests / $totalTests) * 100, 1)
        Write-Host " GLOBAL SCORE: $percentage%" -ForegroundColor Yellow
    }
    
    Write-Host $('='*75) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total Test Suites : $totalTests" -ForegroundColor White
    Write-Host "Passed            : $passedTests" -ForegroundColor Green
    Write-Host "Failed            : $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })
    Write-Host ""
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

Write-TestHeader "DOCKER PROJECT - COMPLETE TEST SUITE"

Write-Host "`nStarting comprehensive test suite execution..." -ForegroundColor Cyan
Write-Host "Total test files: $($Script:TestFiles.Count)" -ForegroundColor Gray
Write-Host ""

$testIndex = 1
foreach ($testConfig in $Script:TestFiles) {
    Write-Host $('='*75) -ForegroundColor Yellow
    Write-Host "TEST $testIndex/$($Script:TestFiles.Count): $($testConfig.Name)" -ForegroundColor Yellow
    Write-Host $('='*75) -ForegroundColor Yellow
    
    $testPath = Join-Path $PSScriptRoot $testConfig.Path
    $testFile = Join-Path $testPath $testConfig.File
    
    if (-not (Test-Path $testFile)) {
        Write-Host "⚠️  Test file not found: $testFile" -ForegroundColor Red
        $Script:TestSuite.Results += @{
            Name = $testConfig.Name
            Passed = $false
            Status = "FILE NOT FOUND"
            ExitCode = -1
        }
        $testIndex++
        continue
    }
    
    try {
        # Execute test script
        $output = & $testFile 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($Verbose) {
            $output | ForEach-Object { Write-Host $_ }
        }
        
        $passed = $exitCode -eq 0
        
        if ($passed) {
            Write-Host "`n TEST PASSED" -ForegroundColor Green
            $Script:TestSuite.Results += @{
                Name = $testConfig.Name
                Passed = $true
                Status = "PASSED"
                ExitCode = $exitCode
            }
        } else {
            Write-Host "`n TEST FAILED (Exit code: $exitCode)" -ForegroundColor Red
            $Script:TestSuite.Results += @{
                Name = $testConfig.Name
                Passed = $false
                Status = "FAILED (Exit: $exitCode)"
                ExitCode = $exitCode
            }
            
            if ($StopOnFailure) {
                Write-Host "`n⚠️  Stopping test suite due to failure" -ForegroundColor Red
                break
            }
        }
        
    } catch {
        Write-Host "`n TEST ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $Script:TestSuite.Results += @{
            Name = $testConfig.Name
            Passed = $false
            Status = "ERROR"
            ExitCode = -1
        }
        
        if ($StopOnFailure) {
            Write-Host "`n⚠️  Stopping test suite due to error" -ForegroundColor Red
            break
        }
    }
    
    $testIndex++
}

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================

Write-TestSummary

# Set exit code based on results
$failedCount = ($Script:TestSuite.Results | Where-Object { -not $_.Passed }).Count
if ($failedCount -eq 0) {
    Write-Host "All tests passed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  $failedCount test(s) failed" -ForegroundColor Red
    exit 1
}

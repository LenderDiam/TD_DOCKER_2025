# ============================================================================
# Test Script: Non-Root Users Verification
# ============================================================================
# This script verifies that all services run with non-root users
# to comply with Docker security best practices.
# ============================================================================

Write-Host ("="*75) -ForegroundColor Cyan
Write-Host "TEST: Non-Root Users" -ForegroundColor Cyan
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host ""

# Function to check container user
function Test-ContainerUser {
    param(
        [string]$ServiceName,
        [string]$ExpectedUser
    )
    
    Write-Host "Checking service: $ServiceName" -ForegroundColor Yellow
    
    # Get container name
    $ContainerName = docker compose ps -q $ServiceName 2>$null
    
    if (-not $ContainerName) {
        Write-Host "  ❌ ERROR: Service $ServiceName not found" -ForegroundColor Red
        return $false
    }
    
    # Method 1: Check main process user (PID 1)
    Write-Host "  [Method 1] Analyzing PID 1 process" -ForegroundColor Gray
    $ProcessInfo = docker compose exec -T $ServiceName ps -o pid,user,comm | Select-String "^\s*1\s+" 2>$null
    
    if (-not $ProcessInfo) {
        Write-Host "  ⚠️  Unable to determine PID 1 user" -ForegroundColor Yellow
        return $null
    }
    
    # Extract PID 1 user
    if ($ProcessInfo -match "^\s*1\s+(\S+)\s+") {
        $ProcessUser = $Matches[1]
    } else {
        Write-Host "  ⚠️  Unexpected ps output format" -ForegroundColor Yellow
        return $null
    }
    
    Write-Host "  PID 1 user: $ProcessUser" -ForegroundColor White
    
    # Method 2: Check default container user (without --user)
    # This is the real validation: is the container configured correctly?
    Write-Host "  [Method 2] Validation with whoami (default user)" -ForegroundColor Gray
    $WhoamiResult = docker compose exec -T $ServiceName whoami 2>$null
    if ($LASTEXITCODE -eq 0) {
        $WhoamiResult = $WhoamiResult.Trim()
        Write-Host "  whoami (default) returns: $WhoamiResult" -ForegroundColor White
        
        if ($WhoamiResult -eq "root") {
            Write-Host "  ❌ ISSUE: Default user is root (bad Dockerfile config)" -ForegroundColor Red
            Write-Host "     Even if PID 1 runs as $ProcessUser, container is not configured correctly" -ForegroundColor Red
            return $false
        }
        
        if ($WhoamiResult -ne $ProcessUser) {
            Write-Host "  ⚠️  WARNING: Default user ($WhoamiResult) different from PID 1 ($ProcessUser)" -ForegroundColor Yellow
            Write-Host "     Recommendation: Add 'USER $ProcessUser' to Dockerfile" -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ Consistency validated: default user = PID 1" -ForegroundColor Green
        }
    } else {
        Write-Host "  ⚠️  Unable to execute whoami" -ForegroundColor Yellow
    }
    
    # Check if running as root
    if ($ProcessUser -eq "root") {
        Write-Host "  ❌ FAIL: Service runs as root!" -ForegroundColor Red
        return $false
    }
    
    # Check expected user
    if ($ExpectedUser -and $ProcessUser -ne $ExpectedUser) {
        Write-Host "  ⚠️  User different from expected ($ExpectedUser)" -ForegroundColor Yellow
    }
    
    # Check UID (User ID) of detected process user
    $UID = docker compose exec -T $ServiceName id -u $ProcessUser 2>$null
    if ($LASTEXITCODE -eq 0) {
        $UID = $UID.Trim()
        Write-Host "  UID: $UID" -ForegroundColor White
        
        if ($UID -eq "0") {
            Write-Host "  ❌ FAIL: UID = 0 (root)!" -ForegroundColor Red
            return $false
        }
    }
    
    Write-Host "  ✅ SUCCESS: Service runs as non-root user" -ForegroundColor Green
    Write-Host ""
    return $true
}

# Function to display process details
function Show-ContainerProcesses {
    param([string]$ServiceName)
    
    Write-Host "Processes in container ${ServiceName}:" -ForegroundColor Cyan
    docker compose exec -T $ServiceName ps aux 2>$null | Select-Object -First 10
    Write-Host ""
}

# ============================================================================
# TESTS
# ============================================================================

Write-Host "Waiting for services to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

$Results = @{}

# Test 1: API (Node.js)
Write-Host "`n" -NoNewline
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host "TEST 1: SERVICE API (Node.js)" -ForegroundColor Cyan
Write-Host ("="*75) -ForegroundColor Cyan
$Results['api'] = Test-ContainerUser -ServiceName "api" -ExpectedUser "node"
if ($Results['api'] -eq $true) {
    Show-ContainerProcesses -ServiceName "api"
}

# Test 2: Frontend (Nginx)
Write-Host "`n" -NoNewline
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host "TEST 2: SERVICE FRONTEND (Nginx)" -ForegroundColor Cyan
Write-Host ("="*75) -ForegroundColor Cyan
$Results['frontend'] = Test-ContainerUser -ServiceName "frontend" -ExpectedUser "nginx"
if ($Results['frontend'] -eq $true) {
    Show-ContainerProcesses -ServiceName "frontend"
}

# Test 3: Database (PostgreSQL)
Write-Host "`n" -NoNewline
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host "TEST 3: SERVICE DATABASE (PostgreSQL)" -ForegroundColor Cyan
Write-Host ("="*75) -ForegroundColor Cyan
$Results['db'] = Test-ContainerUser -ServiceName "db" -ExpectedUser "postgres"
if ($Results['db'] -eq $true) {
    Show-ContainerProcesses -ServiceName "db"
}

# ============================================================================
# ADVANCED TESTS
# ============================================================================

Write-Host "`n" -NoNewline
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host "ADVANCED TESTS: Capabilities Verification" -ForegroundColor Cyan
Write-Host ("="*75) -ForegroundColor Cyan

foreach ($service in @('api', 'frontend', 'db')) {
    Write-Host "`nCapabilities for service ${service}:" -ForegroundColor Yellow
    
    # Inspect container to see its capabilities
    $ContainerID = docker compose ps -q $service 2>$null
    if ($ContainerID) {
        $Inspect = docker inspect $ContainerID | ConvertFrom-Json
        $CapAdd = $Inspect.HostConfig.CapAdd
        $CapDrop = $Inspect.HostConfig.CapDrop
        
        Write-Host "  Added capabilities: " -NoNewline
        if ($CapAdd) {
            Write-Host ($CapAdd -join ", ") -ForegroundColor Yellow
        } else {
            Write-Host "None" -ForegroundColor Gray
        }
        
        Write-Host "  Dropped capabilities: " -NoNewline
        if ($CapDrop) {
            Write-Host ($CapDrop -join ", ") -ForegroundColor Green
        } else {
            Write-Host "⚠️  None (recommendation: add cap_drop: [ALL])" -ForegroundColor Yellow
        }
    }
}

# ============================================================================
# RAPPORT FINAL
# ============================================================================

Write-Host "`n" 
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host "FINAL REPORT" -ForegroundColor Cyan
Write-Host ("="*75) -ForegroundColor Cyan

$TotalTests = $Results.Count
$PassedTests = ($Results.Values | Where-Object { $_ -eq $true }).Count
$FailedTests = ($Results.Values | Where-Object { $_ -eq $false }).Count
$SkippedTests = ($Results.Values | Where-Object { $_ -eq $null }).Count

Write-Host ""
Write-Host "Total tests:  $TotalTests" -ForegroundColor White
Write-Host "Passed tests: $PassedTests" -ForegroundColor Green
Write-Host "Failed tests: $FailedTests" -ForegroundColor Red
Write-Host "Skipped tests: $SkippedTests" -ForegroundColor Yellow
Write-Host ""

if ($FailedTests -eq 0 -and $SkippedTests -eq 0) {
    Write-Host "✅ ALL SERVICES RUN AS NON-ROOT USERS" -ForegroundColor Green
    Write-Host "   Security criteria VALIDATED" -ForegroundColor Green
    exit 0
} elseif ($FailedTests -gt 0) {
    Write-Host "❌ SOME SERVICES RUN AS ROOT" -ForegroundColor Red
    Write-Host "   Security criteria NOT VALIDATED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "⚠️  UNABLE TO VERIFY ALL SERVICES" -ForegroundColor Yellow
    Write-Host "   Check that services are started" -ForegroundColor Yellow
    exit 2
}

# ============================================================================
# RECOMMANDATIONS
# ============================================================================

Write-Host "`n" -NoNewline
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host "SECURITY RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host ""
Write-Host "To further improve security, add to docker-compose.yml:" -ForegroundColor Yellow
Write-Host ""
Write-Host "services:" -ForegroundColor Gray
Write-Host "  api:" -ForegroundColor Gray
Write-Host "    cap_drop:" -ForegroundColor Gray
Write-Host "      - ALL" -ForegroundColor Green
Write-Host "    security_opt:" -ForegroundColor Gray
Write-Host "      - no-new-privileges:true" -ForegroundColor Green
Write-Host ""

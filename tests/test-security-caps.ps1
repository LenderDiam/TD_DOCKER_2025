# ============================================================================
# Test Script: Docker Security Capabilities Audit
# ============================================================================
# This script verifies Linux capabilities of each container
# to ensure security best practices are followed.
# ============================================================================

Write-Host ("="*75) -ForegroundColor Cyan
Write-Host "SECURITY AUDIT: Linux Capabilities" -ForegroundColor Cyan
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host ""

# Fonction pour analyser les capacités d'un conteneur
function Test-ContainerCapabilities {
    param(
        [string]$ServiceName
    )
    
    Write-Host ("="*75) -ForegroundColor Cyan
    Write-Host "SERVICE: $ServiceName" -ForegroundColor Cyan
    Write-Host ("="*75) -ForegroundColor Cyan
    
    # Récupérer l'ID du conteneur
    $ContainerID = docker compose ps -q $ServiceName 2>$null
    
    if (-not $ContainerID) {
        Write-Host "  ❌ ERREUR: Service $ServiceName non trouvé" -ForegroundColor Red
        return @{ service = $ServiceName; score = 0 }
    }
    
    # Inspecter le conteneur
    $Inspect = docker inspect $ContainerID | ConvertFrom-Json
    
    if (-not $Inspect) {
        Write-Host "  ❌ ERREUR: Impossible d'inspecter le conteneur" -ForegroundColor Red
        return @{ service = $ServiceName; score = 0 }
    }
    
    $HostConfig = $Inspect.HostConfig
    $Score = 0
    $MaxScore = 6
    
    # 1. Check CapDrop
    Write-Host "`n[1/6] Dropped Capabilities (CapDrop)" -ForegroundColor Yellow
    $CapDrop = $HostConfig.CapDrop
    if ($CapDrop -and $CapDrop -contains "ALL") {
        Write-Host "  ✅ CapDrop: ALL (all capabilities dropped)" -ForegroundColor Green
        $Score++
    } elseif ($CapDrop -and $CapDrop.Count -gt 0) {
        Write-Host "  ⚠️  CapDrop: $($CapDrop -join ', ')" -ForegroundColor Yellow
        Write-Host "     Recommendation: Use 'ALL' to drop all capabilities" -ForegroundColor Yellow
        $Score += 0.5
    } else {
        Write-Host "  ❌ No capabilities dropped (HIGH RISK!)" -ForegroundColor Red
        Write-Host "     Container has Docker's 14 default capabilities" -ForegroundColor Red
    }
    
    # 2. Check CapAdd
    Write-Host "`n[2/6] Added Capabilities (CapAdd)" -ForegroundColor Yellow
    $CapAdd = $HostConfig.CapAdd
    if (-not $CapAdd -or $CapAdd.Count -eq 0) {
        Write-Host "  ✅ No capabilities added (principle of least privilege)" -ForegroundColor Green
        $Score++
    } else {
        Write-Host "  ⚠️  Added capabilities: $($CapAdd -join ', ')" -ForegroundColor Yellow
        $RequiredCaps = @{
            'nginx' = @('CAP_CHOWN', 'CAP_SETGID', 'CAP_SETUID')
            'frontend' = @('CAP_CHOWN', 'CAP_SETGID', 'CAP_SETUID')
            'postgres' = @('CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FOWNER', 'CAP_SETGID', 'CAP_SETUID')
            'db' = @('CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FOWNER', 'CAP_SETGID', 'CAP_SETUID')
            'node' = @()
            'api' = @()
        }
        
        $allJustified = $true
        foreach ($cap in $CapAdd) {
            $Justified = $false
            foreach ($service in $RequiredCaps.Keys) {
                if ($ServiceName -match $service -and $RequiredCaps[$service] -contains $cap) {
                    $Justified = $true
                    break
                }
            }
            
            if ($Justified) {
                Write-Host "     ✓ $cap : justified for $ServiceName" -ForegroundColor Green
            } else {
                Write-Host "     ⚠️ $cap : not justified, needs verification" -ForegroundColor Yellow
                $allJustified = $false
            }
        }
        if ($allJustified) {
            $Score++
        } else {
            $Score += 0.5
        }
    }
    
    # 3. Check security options
    Write-Host "`n[3/6] Security Options (SecurityOpt)" -ForegroundColor Yellow
    $SecurityOpt = $HostConfig.SecurityOpt
    if ($SecurityOpt -and $SecurityOpt -contains "no-new-privileges:true") {
        Write-Host "  ✅ no-new-privileges: enabled" -ForegroundColor Green
        Write-Host "     Container cannot acquire new privileges" -ForegroundColor Gray
        $Score++
    } else {
        Write-Host "  ❌ no-new-privileges: not enabled (RISK!)" -ForegroundColor Red
        Write-Host "     A process could elevate privileges (setuid, sudo, etc.)" -ForegroundColor Red
    }
    
    # 4. Check Privileged mode
    Write-Host "`n[4/6] Privileged Mode" -ForegroundColor Yellow
    if ($HostConfig.Privileged -eq $true) {
        Write-Host "  ❌ Privileged mode ENABLED (CRITICAL!)" -ForegroundColor Red
        Write-Host "     Container has full kernel access (equivalent to root on host)" -ForegroundColor Red
    } else {
        Write-Host "  ✅ Privileged mode disabled" -ForegroundColor Green
        $Score++
    }
    
    # 5. Check User namespace
    Write-Host "`n[5/6] User Namespace" -ForegroundColor Yellow
    $UsernsMode = $HostConfig.UsernsMode
    if ($UsernsMode -eq "host") {
        Write-Host "  ⚠️  User namespace: host (shares host namespace)" -ForegroundColor Yellow
    } elseif ($UsernsMode) {
        Write-Host "  ✅ User namespace: $UsernsMode (isolated)" -ForegroundColor Green
        $Score++
    } else {
        Write-Host "  ℹ️  User namespace: default" -ForegroundColor Gray
        $Score += 0.5
    }
    
    # 6. Check resource limits
    Write-Host "`n[6/6] Resource Limits" -ForegroundColor Yellow
    $Memory = $HostConfig.Memory
    $CpuQuota = $HostConfig.CpuQuota
    $CpuPeriod = $HostConfig.CpuPeriod
    
    $HasLimits = $false
    if ($Memory -gt 0) {
        $MemoryMB = [math]::Round($Memory / 1MB)
        Write-Host "  ✅ Memory limit: $MemoryMB MB" -ForegroundColor Green
        $HasLimits = $true
    } else {
        Write-Host "  ⚠️  No memory limit" -ForegroundColor Yellow
    }
    
    if ($CpuQuota -gt 0 -and $CpuPeriod -gt 0) {
        $CpuCount = $CpuQuota / $CpuPeriod
        Write-Host "  ✅ CPU limit: $CpuCount core(s)" -ForegroundColor Green
        $HasLimits = $true
    } else {
        Write-Host "  ⚠️  No CPU limit" -ForegroundColor Yellow
    }
    
    if ($HasLimits) {
        $Score++
    } else {
        Write-Host "     Recommendation: Add resource limits" -ForegroundColor Yellow
    }
    
    # Check EFFECTIVE capabilities in container
    Write-Host "`n[BONUS] Checking effective capabilities in container" -ForegroundColor Magenta
    $CapshOutput = docker compose exec -T $ServiceName sh -c "apk add --no-cache libcap 2>/dev/null && capsh --print 2>/dev/null | grep Current" 2>$null
    if ($LASTEXITCODE -eq 0 -and $CapshOutput) {
        Write-Host "  $CapshOutput" -ForegroundColor Gray
    } else {
        # Alternative with getpcaps
        $GetpcapsOutput = docker compose exec -T $ServiceName sh -c "cat /proc/1/status | grep Cap" 2>$null
        if ($LASTEXITCODE -eq 0 -and $GetpcapsOutput) {
            Write-Host "  Capabilities of PID 1 process:" -ForegroundColor Gray
            $GetpcapsOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    }
    
    # Final score
    $Percentage = [math]::Round(($Score / $MaxScore) * 100)
    Write-Host "`nSecurity score: $Score/$MaxScore ($Percentage%)" -ForegroundColor $(
        if ($Percentage -ge 80) { "Green" }
        elseif ($Percentage -ge 60) { "Yellow" }
        else { "Red" }
    )
    Write-Host ""
    
    return @{
        service = $ServiceName
        score = $Score
        maxScore = $MaxScore
        percentage = $Percentage
    }
}

# ============================================================================
# SERVICE TESTS
# ============================================================================

$Results = @()

# Test API
$Results += Test-ContainerCapabilities -ServiceName "api"

# Test Frontend
$Results += Test-ContainerCapabilities -ServiceName "frontend"

# Test Database
$Results += Test-ContainerCapabilities -ServiceName "db"

# ============================================================================
# RAPPORT GLOBAL
# ============================================================================

Write-Host "`n" 
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RAPPORT GLOBAL DE SÉCURITÉ" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$TotalScore = 0
$TotalMaxScore = 0
foreach ($result in $Results) {
    $TotalScore += $result.score
    $TotalMaxScore += $result.maxScore
}
$GlobalPercentage = if ($TotalMaxScore -gt 0) { [math]::Round(($TotalScore / $TotalMaxScore) * 100) } else { 0 }

Write-Host "Services analysés: $($Results.Count)" -ForegroundColor White
Write-Host "Score total: $TotalScore/$TotalMaxScore ($GlobalPercentage%)" -ForegroundColor White
Write-Host ""

# Summary table
Write-Host "Service         Score    Status" -ForegroundColor White
Write-Host ("-"*75) -ForegroundColor Gray
foreach ($result in $Results) {
    $StatusIcon = if ($result.percentage -ge 80) { "✅" }
                  elseif ($result.percentage -ge 60) { "⚠️ " }
                  else { "❌" }
    
    $StatusColor = if ($result.percentage -ge 80) { "Green" }
                   elseif ($result.percentage -ge 60) { "Yellow" }
                   else { "Red" }
    
    $ServicePadded = $result.service.PadRight(15)
    $ScorePadded = "$($result.score)/$($result.maxScore)".PadRight(8)
    
    Write-Host "$ServicePadded $ScorePadded $StatusIcon $($result.percentage)%" -ForegroundColor $StatusColor
}

Write-Host ""

# Recommendations
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host "SECURITY RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host ("="*75) -ForegroundColor Cyan
Write-Host ""

if ($GlobalPercentage -ge 80) {
    Write-Host "✅ Excellent security configuration!" -ForegroundColor Green
    Write-Host "   Best practices are well applied." -ForegroundColor Green
} elseif ($GlobalPercentage -ge 60) {
    Write-Host "⚠️  Security configuration is correct but could be improved" -ForegroundColor Yellow
} else {
    Write-Host "❌ Insufficient security configuration!" -ForegroundColor Red
    Write-Host "   Critical improvements are needed." -ForegroundColor Red
}

Write-Host ""
Write-Host "To improve security, ensure you have in docker-compose.yml:" -ForegroundColor White
Write-Host ""
Write-Host "services:" -ForegroundColor Gray
Write-Host "  your-service:" -ForegroundColor Gray
Write-Host "    cap_drop:" -ForegroundColor Gray
Write-Host "      - ALL                    # Drop all capabilities" -ForegroundColor Green
Write-Host "    cap_add:                   # Add only what's strictly needed" -ForegroundColor Gray
Write-Host "      - CAP_CHOWN              # If chown is needed" -ForegroundColor Yellow
Write-Host "    security_opt:" -ForegroundColor Gray
Write-Host "      - no-new-privileges:true # Prevent privilege escalation" -ForegroundColor Green
Write-Host "    deploy:" -ForegroundColor Gray
Write-Host "      resources:" -ForegroundColor Gray
Write-Host "        limits:" -ForegroundColor Gray
Write-Host "          cpus: '1'" -ForegroundColor Yellow
Write-Host "          memory: 512M" -ForegroundColor Yellow
Write-Host ""

# Exit status
if ($GlobalPercentage -ge 80) {
    exit 0
} elseif ($GlobalPercentage -ge 60) {
    exit 1
} else {
    exit 2
}

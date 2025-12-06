# ==============================================================================
# API FUNCTIONAL TEST - HTTP Endpoint Validation
# ==============================================================================
# Tests: API availability, endpoints, response codes, content types
# ==============================================================================

param(
    [string]$BaseUrl = "http://localhost:3000",
    [int]$Timeout = 10,
    [switch]$Verbose,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

# ==============================================================================
# TEST CONFIGURATION
# ==============================================================================

$Script:TestResults = @{
    Category = "API FUNCTIONAL"
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

function Invoke-HttpTest {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$Body = $null
    )
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            TimeoutSec = $Timeout
            UseBasicParsing = $true
        }
        
        if ($Headers.Count -gt 0) {
            $params['Headers'] = $Headers
        }
        
        if ($Body) {
            $params['Body'] = $Body
            $params['ContentType'] = 'application/json'
        }
        
        $response = Invoke-WebRequest @params -ErrorAction Stop
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            StatusDescription = $response.StatusDescription
            ContentType = $response.Headers['Content-Type']
            Content = $response.Content
            ResponseTime = 0
        }
        
    } catch {
        $statusCode = if ($_.Exception.Response) { 
            [int]$_.Exception.Response.StatusCode 
        } else { 0 }
        
        return @{
            Success = $false
            StatusCode = $statusCode
            Error = $_.Exception.Message
            ResponseTime = 0
        }
    }
}

# ==============================================================================
# TEST FUNCTIONS
# ==============================================================================

function Test-EndpointAvailability {
    param([string]$Url, [string]$Name)
    
    $response = Invoke-HttpTest -Url $Url
    
    return Add-TestResult `
        -Test "Endpoint available: $Name" `
        -Passed $response.Success `
        -Reason $(if (-not $response.Success) { "Error: $($response.Error)" } else { "" }) `
        -Details @{ 
            StatusCode = $response.StatusCode
            Url = $Url
        }
}

function Test-ResponseCode {
    param([string]$Url, [string]$Name, [int]$ExpectedCode = 200)
    
    $response = Invoke-HttpTest -Url $Url
    
    $passed = $response.StatusCode -eq $ExpectedCode
    
    return Add-TestResult `
        -Test "Response code $ExpectedCode : $Name" `
        -Passed $passed `
        -Reason $(if (-not $passed) { "Got $($response.StatusCode)" } else { "" }) `
        -Details @{ 
            Expected = $ExpectedCode
            Actual = $response.StatusCode
        }
}

function Test-ContentType {
    param([string]$Url, [string]$Name, [string]$ExpectedType = "application/json")
    
    $response = Invoke-HttpTest -Url $Url
    
    if (-not $response.Success) {
        return Add-TestResult `
            -Test "Content-Type: $Name" `
            -Passed $false `
            -Reason "Request failed"
    }
    
    $contentType = $response.ContentType
    $passed = $contentType -like "*$ExpectedType*"
    
    return Add-TestResult `
        -Test "Content-Type $ExpectedType : $Name" `
        -Passed $passed `
        -Reason $(if (-not $passed) { "Got: $contentType" } else { "" }) `
        -Details @{ 
            Expected = $ExpectedType
            Actual = $contentType
        }
}

function Test-JsonResponse {
    param([string]$Url, [string]$Name)
    
    $response = Invoke-HttpTest -Url $Url
    
    if (-not $response.Success) {
        return Add-TestResult `
            -Test "Valid JSON: $Name" `
            -Passed $false `
            -Reason "Request failed"
    }
    
    try {
        $json = $response.Content | ConvertFrom-Json
        $passed = $true
    } catch {
        $passed = $false
    }
    
    return Add-TestResult `
        -Test "Valid JSON: $Name" `
        -Passed $passed `
        -Reason $(if (-not $passed) { "Invalid JSON format" } else { "" })
}

function Test-PostRequest {
    param([string]$Url, [string]$Name, [string]$Body)
    
    $response = Invoke-HttpTest -Url $Url -Method "POST" -Body $Body
    
    $passed = $response.Success -and ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201)
    
    return Add-TestResult `
        -Test "POST request: $Name" `
        -Passed $passed `
        -Reason $(if (-not $passed) { "Status: $($response.StatusCode)" } else { "" }) `
        -Details @{ StatusCode = $response.StatusCode }
}

function Test-ResponseTime {
    param([string]$Url, [string]$Name, [int]$MaxMs = 2000)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-HttpTest -Url $Url
    $stopwatch.Stop()
    
    $responseTime = $stopwatch.ElapsedMilliseconds
    $passed = $responseTime -le $MaxMs
    
    return Add-TestResult `
        -Test "Response time < ${MaxMs}ms : $Name" `
        -Passed $passed `
        -Reason $(if (-not $passed) { "Took ${responseTime}ms" } else { "" }) `
        -Details @{ 
            ResponseTime = $responseTime
            Threshold = $MaxMs
        }
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

Write-TestHeader "RUN API FUNCTIONAL TEST"

Write-Host "`nBase URL: $BaseUrl" -ForegroundColor Cyan
Write-Host "Timeout : ${Timeout}s" -ForegroundColor Cyan

# ==============================================================================
# STEP 1: HEALTH CHECK (/status)
# ==============================================================================

Write-StepHeader "HEALTH CHECK (/status)"

$step1Start = $Script:TestResults.Steps.Count
Test-EndpointAvailability -Url "$BaseUrl/status" -Name "Status endpoint" | Out-Null
Test-ResponseCode -Url "$BaseUrl/status" -Name "Status endpoint" -ExpectedCode 200 | Out-Null
Test-ContentType -Url "$BaseUrl/status" -Name "Status endpoint" -ExpectedType "application/json" | Out-Null
Test-JsonResponse -Url "$BaseUrl/status" -Name "Status endpoint" | Out-Null

Show-StepResult -StepName "Health check" -StartCount $step1Start

# ==============================================================================
# STEP 2: READINESS CHECK (/ready)
# ==============================================================================

Write-StepHeader "READINESS CHECK (/ready)"

$step2Start = $Script:TestResults.Steps.Count
Test-EndpointAvailability -Url "$BaseUrl/ready" -Name "Ready endpoint" | Out-Null
Test-ResponseCode -Url "$BaseUrl/ready" -Name "Ready endpoint" -ExpectedCode 200 | Out-Null
Test-ContentType -Url "$BaseUrl/ready" -Name "Ready endpoint" -ExpectedType "application/json" | Out-Null
Test-JsonResponse -Url "$BaseUrl/ready" -Name "Ready endpoint" | Out-Null

# Verify database health in ready response
$response = Invoke-HttpTest -Url "$BaseUrl/ready"
if ($response.Success) {
    try {
        $readyData = $response.Content | ConvertFrom-Json
        $dbHealthy = $readyData.database -eq "healthy"
        Add-TestResult `
            -Test "Database healthy in ready check" `
            -Passed $dbHealthy `
            -Reason $(if (-not $dbHealthy) { "Database not healthy: $($readyData.database)" } else { "" }) | Out-Null
    } catch {
        Add-TestResult `
            -Test "Database healthy in ready check" `
            -Passed $false `
            -Reason "Failed to parse ready response" | Out-Null
    }
}

Show-StepResult -StepName "Readiness check" -StartCount $step2Start

# ==============================================================================
# STEP 3: ITEMS ENDPOINT
# ==============================================================================

Write-StepHeader "ITEMS ENDPOINT"

$step3Start = $Script:TestResults.Steps.Count
Test-EndpointAvailability -Url "$BaseUrl/items" -Name "Items endpoint" | Out-Null
Test-ResponseCode -Url "$BaseUrl/items" -Name "Items endpoint" -ExpectedCode 200 | Out-Null
Test-ContentType -Url "$BaseUrl/items" -Name "Items endpoint" -ExpectedType "application/json" | Out-Null
Test-JsonResponse -Url "$BaseUrl/items" -Name "Items endpoint" | Out-Null

Show-StepResult -StepName "Items endpoint" -StartCount $step3Start

# ==============================================================================
# STEP 4: RESOURCE VALIDATION
# ==============================================================================

Write-StepHeader "RESOURCE VALIDATION"

$step4Start = $Script:TestResults.Steps.Count

# Verify items endpoint returns an array
$response = Invoke-HttpTest -Url "$BaseUrl/items"
if ($response.Success) {
    try {
        $items = $response.Content | ConvertFrom-Json
        $isArray = $items -is [Array]
        Add-TestResult `
            -Test "Items returns array" `
            -Passed $isArray `
            -Reason $(if (-not $isArray) { "Response is not an array" } else { "" }) | Out-Null
    } catch {
        Add-TestResult `
            -Test "Items returns array" `
            -Passed $false `
            -Reason "Failed to parse JSON" | Out-Null
    }
}

Show-StepResult -StepName "Resource validation" -StartCount $step4Start

# ==============================================================================
# STEP 5: RESPONSE TIMES
# ==============================================================================

Write-StepHeader "RESPONSE TIMES"

$step5Start = $Script:TestResults.Steps.Count
Test-ResponseTime -Url "$BaseUrl/status" -Name "Status endpoint" -MaxMs 1000 | Out-Null
Test-ResponseTime -Url "$BaseUrl/ready" -Name "Ready endpoint" -MaxMs 2000 | Out-Null
Test-ResponseTime -Url "$BaseUrl/items" -Name "Items endpoint" -MaxMs 2000 | Out-Null

Show-StepResult -StepName "Response time" -StartCount $step5Start

# ==============================================================================
# STEP 6: ERROR HANDLING
# ==============================================================================

Write-StepHeader "ERROR HANDLING"

$step6Start = $Script:TestResults.Steps.Count
Test-ResponseCode -Url "$BaseUrl/nonexistent" -Name "404 handling" -ExpectedCode 404 | Out-Null

Show-StepResult -StepName "Error handling" -StartCount $step6Start

# ==============================================================================
# FINAL REPORT
# ==============================================================================

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " API FUNCTIONAL TEST SUMMARY" -ForegroundColor White
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



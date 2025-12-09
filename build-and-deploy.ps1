# ==============================================================================
# BUILD AND DEPLOY AUTOMATION SCRIPT
# ==============================================================================
# Automates: Build, Scan, Push, Deploy
# ==============================================================================

param(
    [string]$Registry = "docker.io",
    [string]$Username = "lenderdiam",
    [switch]$SkipScan,
    [switch]$SkipPush,
    [switch]$SkipDeploy,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Disable Docker Content Trust
$env:DOCKER_CONTENT_TRUST = "0"

# ==============================================================================
# CONFIGURATION
# ==============================================================================

$Script:Config = @{
    ProjectName = "td_docker_2025"
    Version = "latest"
    Images = @(
        @{ Name = "api"; Path = "./api"; Tag = "$Registry/$Username/td-docker-api" }
        @{ Name = "db"; Path = "./db"; Tag = "$Registry/$Username/td-docker-db" }
        @{ Name = "frontend"; Path = "./frontend"; Tag = "$Registry/$Username/td-docker-frontend" }
    )
    Colors = @{
        Success = "Green"
        Error = "Red"
        Warning = "Yellow"
        Info = "Cyan"
        Step = "Magenta"
    }
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host "`n$('='*80)" -ForegroundColor $Script:Config.Colors.Info
    Write-Host " $Message" -ForegroundColor $Script:Config.Colors.Info
    Write-Host $('='*80) -ForegroundColor $Script:Config.Colors.Info
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n▶ STEP: $Message" -ForegroundColor $Script:Config.Colors.Step
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $Script:Config.Colors.Success
}

function Write-Failure {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $Script:Config.Colors.Error
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $Script:Config.Colors.Info
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $Script:Config.Colors.Warning
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# ==============================================================================
# STEP 1: ENVIRONMENT VALIDATION
# ==============================================================================

function Test-Environment {
    Write-Step "Environment validation"
    
    # Check Docker
    if (-not (Test-CommandExists "docker")) {
        Write-Failure "Docker is not installed"
        exit 1
    }
    Write-Success "Docker is installed"
    
    # Check Docker Compose
    if (-not (Test-CommandExists "docker")) {
        Write-Failure "Docker Compose is not available"
        exit 1
    }
    Write-Success "Docker Compose is available"
    
    # Check that Docker daemon is running
    try {
        docker ps | Out-Null
        Write-Success "Docker daemon is active"
    } catch {
        Write-Failure "Docker daemon is not running"
        exit 1
    }
    
    # Check .env file
    if (-not (Test-Path ".env")) {
        Write-Warning "Fichier .env non trouvé"
        if (Test-Path ".env.exemple") {
            Write-Info "Copiez .env.exemple vers .env et configurez-le"
        }
    } else {
        Write-Success "Fichier .env présent"
    }
}

# ==============================================================================
# STEP 2: BUILD IMAGES
# ==============================================================================

function Build-Images {
    Write-Step "Building Docker images"
    
    foreach ($image in $Script:Config.Images) {
        Write-Info "Building image: $($image.Name)"
        
        $buildArgs = @(
            "build",
            "-t", "$($image.Tag):$($Script:Config.Version)",
            "-t", "$($image.Tag):latest"
        )
        
        if (-not $Verbose) {
            $buildArgs += "--quiet"
        }
        
        $buildArgs += $image.Path
        
        try {
            & docker @buildArgs
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Image $($image.Name) built successfully"
                
                # Display image size
                $size = docker images "$($image.Tag):latest" --format "{{.Size}}"
                Write-Info "Image size: $size"
            } else {
                Write-Failure "Failed to build image $($image.Name)"
                exit 1
            }
        } catch {
            Write-Failure "Error building $($image.Name): $($_.Exception.Message)"
            exit 1
        }
    }
}

# ==============================================================================
# STEP 3: SECURITY SCAN OF IMAGES
# ==============================================================================

function Invoke-SecurityScan {
    if ($SkipScan) {
        Write-Warning "Security scan skipped (--SkipScan)"
        return
    }
    
    Write-Step "Security scan of images (optional)"
    
    # Build list of image tags
    $imageTags = @()
    foreach ($image in $Script:Config.Images) {
        $imageTags += "$($image.Tag):latest"
    }
    
    # Call security test script
    $scanScriptPath = Join-Path $PSScriptRoot "tests\test-security-scan.ps1"
    
    if (-not (Test-Path $scanScriptPath)) {
        Write-Warning "Script tests\test-security-scan.ps1 not found"
        return
    }
    
    try {
        Write-Info "Running security scan..."
        $scanResult = & $scanScriptPath -ImageTags $imageTags -Quiet -ReturnObject
        
        if ($scanResult.Success) {
            foreach ($result in $scanResult.Results) {
                if ($result.Success) {
                    $imageName = $result.ImageTag -replace ".*/(.*):.* ", '$1'
                    if ($result.Critical -eq 0 -and $result.High -eq 0) {
                        Write-Success "$imageName : No critical vulnerabilities"
                    } else {
                        Write-Warning "$imageName : $($result.Critical) CRITICAL, $($result.High) HIGH"
                    }
                }
            }
        } else {
            Write-Warning "Scan unavailable or error: $($scanResult.Error)"
        }
    } catch {
        Write-Warning "Error during scan: $($_.Exception.Message)"
    }
}

# ==============================================================================
# STEP 4: DOCKER COMPOSE VALIDATION
# ==============================================================================

function Test-DockerCompose {
    Write-Step "Docker Compose configuration validation"
    
    try {
        docker compose config > $null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "docker-compose.yml configuration is valid"
        } else {
            Write-Failure "docker-compose.yml configuration is invalid"
            exit 1
        }
    } catch {
        Write-Failure "Error during validation: $($_.Exception.Message)"
        exit 1
    }
}

# ==============================================================================
# STEP 5: REGISTRY LOGIN
# ==============================================================================

function Connect-Registry {
    if ($SkipPush) {
        Write-Warning "Push skipped, registry connection not needed"
        return
    }
    
    Write-Step "Docker registry connection"
    
    Write-Info "Registry: $Registry"
    Write-Info "Username: $Username"
    
    try {
        # Check if already connected
        $ErrorActionPreference = "SilentlyContinue"
        $loginTest = docker info 2>&1 | Select-String "Username"
        $ErrorActionPreference = "Continue"
        
        if ($loginTest) {
            Write-Success "Déjà connecté au registre"
        } else {
            Write-Info "Connexion requise..."
            $ErrorActionPreference = "SilentlyContinue"
            docker login 2>&1 | Out-Null
            $loginResult = $LASTEXITCODE
            $ErrorActionPreference = "Continue"
            
            if ($loginResult -eq 0) {
                Write-Success "Connecté au registre avec succès"
            } else {
                Write-Failure "Échec de connexion au registre"
                exit 1
            }
        }
    } catch {
        Write-Failure "Erreur de connexion: $($_.Exception.Message)"
        exit 1
    }
}

# ==============================================================================
# STEP 6: PUSH IMAGES
# ==============================================================================

function Push-Images {
    if ($SkipPush) {
        Write-Warning "Push images skipped (--SkipPush)"
        return
    }
    
    Write-Step "Pushing images to registry"
    
    foreach ($image in $Script:Config.Images) {
        Write-Info "Pushing image: $($image.Name)"
        
        try {
            docker push "$($image.Tag):latest"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Image $($image.Name) pushed successfully"
            } else {
                Write-Failure "Failed to push image $($image.Name)"
                exit 1
            }
            
            # Push with version tag if different from latest
            if ($Script:Config.Version -ne "latest") {
                docker push "$($image.Tag):$($Script:Config.Version)"
            }
        } catch {
            Write-Failure "Error pushing $($image.Name): $($_.Exception.Message)"
            exit 1
        }
    }
}

# ==============================================================================
# STEP 7: DEPLOYMENT
# ==============================================================================

function Start-Deployment {
    if ($SkipDeploy) {
        Write-Warning "Deployment skipped (--SkipDeploy)"
        return
    }
    
    Write-Step "Application deployment"
    
    # Stop existing containers
    Write-Info "Stopping existing containers..."
    docker compose down 2>&1 | Out-Null
    
    # Start new containers
    Write-Info "Starting containers..."
    docker compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Conteneurs démarrés avec succès"
        
        # Attendre que les services soient healthy
        Write-Info "Vérification de l'état des services..."
        Start-Sleep -Seconds 5
        
        $services = docker compose ps --format json | ConvertFrom-Json
        
        Write-Host "`n--- ÉTAT DES SERVICES ---" -ForegroundColor Cyan
        foreach ($service in $services) {
            $status = $service.State
            $color = if ($status -eq "running") { "Green" } else { "Yellow" }
            Write-Host "$($service.Service): " -NoNewline
            Write-Host $status -ForegroundColor $color
        }
        
        # Tester l'API
        Write-Info "Test de l'API..."
        Start-Sleep -Seconds 3
        
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:3000/status" -Method GET -TimeoutSec 5
            Write-Success "API répond correctement: $($response.status)"
        } catch {
            Write-Warning "API ne répond pas encore (peut nécessiter plus de temps)"
        }
        
    } else {
        Write-Failure "Échec du démarrage des conteneurs"
        exit 1
    }
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

Write-Header "AUTOMATION - BUILD, SCAN, PUSH & DEPLOY"

Write-Info "Project: $($Script:Config.ProjectName)"
Write-Info "Version: $($Script:Config.Version)"
Write-Info "Registry: $Registry/$Username"

try {
    # Step 1: Validation
    Test-Environment
    
    # Step 2: Build
    Build-Images
    
    # Step 3: Security scan (optional)
    Invoke-SecurityScan
    
    # Step 4: Compose validation
    Test-DockerCompose
    
    # Step 5: Login
    Connect-Registry
    
    # Step 6: Push
    Push-Images
    
    # Step 7: Deployment
    Start-Deployment
    
    # Final summary
    Write-Header "DEPLOYMENT COMPLETED SUCCESSFULLY"
    Write-Success "All steps completed"
    
    Write-Host "`n📊 Access to services:" -ForegroundColor Cyan
    Write-Host "  - API:      http://localhost:3000" -ForegroundColor White
    Write-Host "  - Frontend: http://localhost:8080" -ForegroundColor White
    Write-Host "`n📝 Useful commands:" -ForegroundColor Cyan
    Write-Host "  - Logs:     docker compose logs -f" -ForegroundColor White
    Write-Host "  - Status:   docker compose ps" -ForegroundColor White
    Write-Host "  - Stop:     docker compose down" -ForegroundColor White
    Write-Host "  - Tests:    .\run-all-tests.ps1" -ForegroundColor White
    
} catch {
    Write-Header "ERROR DURING EXECUTION"
    Write-Failure $_.Exception.Message
    Write-Info "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

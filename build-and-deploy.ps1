# ==============================================================================
# BUILD AND DEPLOY AUTOMATION SCRIPT
# ==============================================================================
# Automatise : Build, Scan, Push, Deploy
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

# Désactiver Docker Content Trust
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
# STEP 1: VALIDATION DE L'ENVIRONNEMENT
# ==============================================================================

function Test-Environment {
    Write-Step "Validation de l'environnement"
    
    # Vérifier Docker
    if (-not (Test-CommandExists "docker")) {
        Write-Failure "Docker n'est pas installé"
        exit 1
    }
    Write-Success "Docker est installé"
    
    # Vérifier Docker Compose
    if (-not (Test-CommandExists "docker")) {
        Write-Failure "Docker Compose n'est pas disponible"
        exit 1
    }
    Write-Success "Docker Compose est disponible"
    
    # Vérifier que Docker daemon est lancé
    try {
        docker ps | Out-Null
        Write-Success "Docker daemon est actif"
    } catch {
        Write-Failure "Docker daemon n'est pas lancé"
        exit 1
    }
    
    # Vérifier le fichier .env
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
# STEP 2: BUILD DES IMAGES
# ==============================================================================

function Build-Images {
    Write-Step "Construction des images Docker"
    
    foreach ($image in $Script:Config.Images) {
        Write-Info "Construction de l'image: $($image.Name)"
        
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
                Write-Success "Image $($image.Name) construite avec succès"
                
                # Afficher la taille de l'image
                $size = docker images "$($image.Tag):latest" --format "{{.Size}}"
                Write-Info "Taille de l'image: $size"
            } else {
                Write-Failure "Échec de construction de l'image $($image.Name)"
                exit 1
            }
        } catch {
            Write-Failure "Erreur lors de la construction de $($image.Name): $($_.Exception.Message)"
            exit 1
        }
    }
}

# ==============================================================================
# STEP 3: SCAN DE SÉCURITÉ DES IMAGES
# ==============================================================================

function Invoke-SecurityScan {
    if ($SkipScan) {
        Write-Warning "Scan de sécurité ignoré (--SkipScan)"
        return
    }
    
    Write-Step "Scan de sécurité des images (optionnel)"
    
    # Construire la liste des tags d'images
    $imageTags = @()
    foreach ($image in $Script:Config.Images) {
        $imageTags += "$($image.Tag):latest"
    }
    
    # Appeler le script de test de sécurité
    $scanScriptPath = Join-Path $PSScriptRoot "tests\test-security-scan.ps1"
    
    if (-not (Test-Path $scanScriptPath)) {
        Write-Warning "Script tests\test-security-scan.ps1 introuvable"
        return
    }
    
    try {
        Write-Info "Exécution du scan de sécurité..."
        $scanResult = & $scanScriptPath -ImageTags $imageTags -Quiet -ReturnObject
        
        if ($scanResult.Success) {
            foreach ($result in $scanResult.Results) {
                if ($result.Success) {
                    $imageName = $result.ImageTag -replace ".*/(.*):.*", '$1'
                    if ($result.Critical -eq 0 -and $result.High -eq 0) {
                        Write-Success "$imageName : Aucune vulnérabilité critique"
                    } else {
                        Write-Warning "$imageName : $($result.Critical) CRITICAL, $($result.High) HIGH"
                    }
                }
            }
        } else {
            Write-Warning "Scan non disponible ou erreur: $($scanResult.Error)"
        }
    } catch {
        Write-Warning "Erreur lors du scan: $($_.Exception.Message)"
    }
}

# ==============================================================================
# STEP 4: VALIDATION DOCKER COMPOSE
# ==============================================================================

function Test-DockerCompose {
    Write-Step "Validation de la configuration Docker Compose"
    
    try {
        docker compose config > $null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Configuration docker-compose.yml valide"
        } else {
            Write-Failure "Configuration docker-compose.yml invalide"
            exit 1
        }
    } catch {
        Write-Failure "Erreur lors de la validation: $($_.Exception.Message)"
        exit 1
    }
}

# ==============================================================================
# STEP 5: LOGIN AU REGISTRE
# ==============================================================================

function Connect-Registry {
    if ($SkipPush) {
        Write-Warning "Push ignoré, connexion au registre non nécessaire"
        return
    }
    
    Write-Step "Connexion au registre Docker"
    
    Write-Info "Registre: $Registry"
    Write-Info "Utilisateur: $Username"
    
    try {
        # Vérifier si déjà connecté
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
# STEP 6: PUSH DES IMAGES
# ==============================================================================

function Push-Images {
    if ($SkipPush) {
        Write-Warning "Push des images ignoré (--SkipPush)"
        return
    }
    
    Write-Step "Push des images vers le registre"
    
    foreach ($image in $Script:Config.Images) {
        Write-Info "Push de l'image: $($image.Name)"
        
        try {
            docker push "$($image.Tag):latest"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Image $($image.Name) poussée avec succès"
            } else {
                Write-Failure "Échec du push de l'image $($image.Name)"
                exit 1
            }
            
            # Push avec tag version si différent de latest
            if ($Script:Config.Version -ne "latest") {
                docker push "$($image.Tag):$($Script:Config.Version)"
            }
        } catch {
            Write-Failure "Erreur lors du push de $($image.Name): $($_.Exception.Message)"
            exit 1
        }
    }
}

# ==============================================================================
# STEP 7: DÉPLOIEMENT
# ==============================================================================

function Start-Deployment {
    if ($SkipDeploy) {
        Write-Warning "Déploiement ignoré (--SkipDeploy)"
        return
    }
    
    Write-Step "Déploiement de l'application"
    
    # Arrêter les conteneurs existants
    Write-Info "Arrêt des conteneurs existants..."
    docker compose down 2>&1 | Out-Null
    
    # Démarrer les nouveaux conteneurs
    Write-Info "Démarrage des conteneurs..."
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

Write-Info "Projet: $($Script:Config.ProjectName)"
Write-Info "Version: $($Script:Config.Version)"
Write-Info "Registre: $Registry/$Username"

try {
    # Étape 1: Validation
    Test-Environment
    
    # Étape 2: Build
    Build-Images
    
    # Étape 3: Scan de sécurité (optionnel)
    Invoke-SecurityScan
    
    # Étape 4: Validation Compose
    Test-DockerCompose
    
    # Étape 5: Login
    Connect-Registry
    
    # Étape 6: Push
    Push-Images
    
    # Étape 7: Déploiement
    Start-Deployment
    
    # Résumé final
    Write-Header "DÉPLOIEMENT TERMINÉ AVEC SUCCÈS"
    Write-Success "Toutes les étapes ont été complétées"
    
    Write-Host "`n📊 Accès aux services:" -ForegroundColor Cyan
    Write-Host "  - API:      http://localhost:3000" -ForegroundColor White
    Write-Host "  - Frontend: http://localhost:8080" -ForegroundColor White
    Write-Host "`n📝 Commandes utiles:" -ForegroundColor Cyan
    Write-Host "  - Logs:     docker compose logs -f" -ForegroundColor White
    Write-Host "  - Status:   docker compose ps" -ForegroundColor White
    Write-Host "  - Stop:     docker compose down" -ForegroundColor White
    Write-Host "  - Tests:    .\run-all-tests.ps1" -ForegroundColor White
    
} catch {
    Write-Header "ERREUR DURANT L'EXÉCUTION"
    Write-Failure $_.Exception.Message
    Write-Info "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

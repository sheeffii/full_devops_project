# Full deployment script for infrastructure
param(
    [string]$Environment = "dev",
    [string]$Region = "eu-north-1",
    [string]$VarFile = "example.tfvars"
)

# Set error action preference to stop on any error
$ErrorActionPreference = "Stop"

# Function to check if Packer AMI exists
function Test-PackerAMI {
    $manifestPath = Join-Path $PSScriptRoot ".." "packer" "packer-manifest.json"
    if (-not (Test-Path $manifestPath)) {
        return $false
    }
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    $amiId = ($manifest.builds[0].artifact_id -split ':')[1]
    
    # Check if AMI exists in AWS
    try {
        aws ec2 describe-images --image-ids $amiId --region $Region | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Function to run Packer build
function Start-PackerBuild {
    Write-Host "🏗️ Building Docker AMI with Packer..."
    Set-Location (Join-Path $PSScriptRoot ".." "packer")
    
    # Initialize Packer
    packer init .
    if ($LASTEXITCODE -ne 0) {
        throw "Packer init failed"
    }

    # Build AMI
    packer build -force packer-docker-ami.pkr.hcl
    if ($LASTEXITCODE -ne 0) {
        throw "Packer build failed"
    }
}

# Function to run Terraform commands
function Invoke-Terraform {
    param(
        [string]$Command,
        [string]$WorkingDir,
        [string]$VarFile
    )

    Set-Location $WorkingDir
    
    # Clean any existing state
    Remove-Item -Path ".terraform" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path ".terraform.lock.hcl" -Force -ErrorAction SilentlyContinue

    # Initialize
    terraform init -reconfigure -upgrade
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform init failed in $WorkingDir"
    }

    # Validate
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform validate failed in $WorkingDir"
    }

    # Run specified command
    if ($VarFile) {
        terraform $Command -var-file=$VarFile -auto-approve
    } else {
        terraform $Command -auto-approve
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform $Command failed in $WorkingDir"
    }
}

try {
    Write-Host "🚀 Starting infrastructure deployment..."
    
    # Step 1: Build Docker AMI if needed
    if (-not (Test-PackerAMI)) {
        Write-Host "No valid Docker AMI found. Building new one..."
        Start-PackerBuild
    } else {
        Write-Host "✅ Docker AMI already exists"
    }

    # Step 2: Bootstrap backend if needed
    $bootstrapDir = Join-Path $PSScriptRoot ".." "bootstrap"
    Write-Host "🔧 Setting up backend infrastructure..."
    Invoke-Terraform -Command "apply" -WorkingDir $bootstrapDir

    # Step 3: Deploy main infrastructure
    $mainDir = Join-Path $PSScriptRoot ".." "dev"
    Write-Host "🌟 Deploying main infrastructure..."
    Invoke-Terraform -Command "apply" -WorkingDir $mainDir -VarFile $VarFile

    Write-Host "✅ Deployment completed successfully!"

} catch {
    Write-Host "❌ Error during deployment: $_" -ForegroundColor Red
    exit 1
}
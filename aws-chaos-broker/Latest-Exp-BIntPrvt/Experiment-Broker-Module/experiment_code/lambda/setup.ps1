# Setup script for lambda handler dependencies (PowerShell)
# This script sets up the virtual environment and installs all required dependencies

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Lambda Handler Setup Script (PowerShell)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if virtual environment exists and has pip
if (-not (Test-Path "chaos-venv") -or -not (Test-Path "chaos-venv\Scripts\pip.exe")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    # Remove old venv if it exists but is broken
    if (Test-Path "chaos-venv") {
        Write-Host "Removing broken virtual environment..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force "chaos-venv"
    }
    python -m venv chaos-venv
    Write-Host "Virtual environment created." -ForegroundColor Green
} else {
    Write-Host "Virtual environment already exists." -ForegroundColor Green
}

# Activate virtual environment
Write-Host ""
Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& "chaos-venv\Scripts\Activate.ps1"

# Ensure pip is installed and up to date
Write-Host ""
Write-Host "Ensuring pip is installed and up to date..." -ForegroundColor Yellow
python -m ensurepip --upgrade 2>$null
python -m pip install --upgrade pip setuptools wheel

# Install dependencies
Write-Host ""
Write-Host "Installing dependencies from requirements.txt..." -ForegroundColor Yellow
pip install -r requirements.txt

# Install local packages
Write-Host ""
Write-Host "Installing local packages..." -ForegroundColor Yellow

$CodeRoot = Split-Path -Parent $ScriptDir
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $CodeRoot)

# Install experiment_bofa
$ExperimentBofaDir = Join-Path $CodeRoot "experiment_bofa"
if (Test-Path $ExperimentBofaDir) {
    Write-Host "Installing experiment_bofa..." -ForegroundColor Yellow
    Push-Location $ExperimentBofaDir
    if (-not (Test-Path "setup.py")) {
        Write-Host "  Creating minimal setup.py for experiment_bofa..." -ForegroundColor Yellow
        @"
from setuptools import setup, find_packages
setup(
    name="experiment_bofa",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[]
)
"@ | Out-File -FilePath "setup.py" -Encoding utf8
    }
    pip install -e . --no-build-isolation 2>$null
    if ($LASTEXITCODE -ne 0) {
        pip install -e .
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠ Warning: experiment_bofa installation failed" -ForegroundColor Yellow
        }
    }
    Pop-Location
} else {
    Write-Host "⚠ Warning: experiment_bofa directory not found" -ForegroundColor Yellow
}

# Install experiment_runner_lite (now in chaos-toolkit-lite directory)
$ExperimentRunnerLiteDir = Join-Path $ProjectRoot "chaos-toolkit-lite\experiment_runner_lite"
if (Test-Path $ExperimentRunnerLiteDir) {
    Write-Host "Installing experiment_runner_lite from chaos-toolkit-lite..." -ForegroundColor Yellow
    Push-Location $ExperimentRunnerLiteDir
    if (-not (Test-Path "setup.py")) {
        Write-Host "  Creating minimal setup.py for experiment_runner_lite..." -ForegroundColor Yellow
        @"
from setuptools import setup, find_packages
setup(
    name="experiment_runner_lite",
    version="0.1.0",
    packages=find_packages(),
    install_requires=["boto3>=1.26.0"],
    python_requires=">=3.9"
)
"@ | Out-File -FilePath "setup.py" -Encoding utf8
    }
    pip install -e . --no-build-isolation 2>$null
    if ($LASTEXITCODE -ne 0) {
        pip install -e .
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠ Warning: experiment_runner_lite installation failed" -ForegroundColor Yellow
        }
    }
    Pop-Location
} else {
    Write-Host "⚠ Warning: experiment_runner_lite directory not found at $ExperimentRunnerLiteDir" -ForegroundColor Yellow
    Write-Host "  Looking for: chaos-toolkit-lite\experiment_runner_lite" -ForegroundColor Yellow
}

# Install experiment_broker_logging
$ExperimentBrokerLoggingDir = Join-Path $ProjectRoot "Experiment-Broker-Logging-Module"
if (Test-Path $ExperimentBrokerLoggingDir) {
    Write-Host "Installing experiment_broker_logging..." -ForegroundColor Yellow
    Push-Location $ExperimentBrokerLoggingDir
    if (-not (Test-Path "setup.py")) {
        Write-Host "  Creating minimal setup.py for experiment_broker_logging..." -ForegroundColor Yellow
        @"
from setuptools import setup, find_packages
setup(
    name="experiment_broker_logging",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[]
)
"@ | Out-File -FilePath "setup.py" -Encoding utf8
    }
    pip install -e . --no-build-isolation 2>$null
    if ($LASTEXITCODE -ne 0) {
        pip install -e .
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠ Warning: experiment_broker_logging installation failed" -ForegroundColor Yellow
        }
    }
    Pop-Location
} else {
    Write-Host "⚠ Warning: Experiment-Broker-Logging-Module directory not found" -ForegroundColor Yellow
}

# Go back to lambda directory
Set-Location $ScriptDir

# Set PYTHONPATH for verification (helps with editable installs)
# Include project root and chaos-toolkit-lite directory
$env:PYTHONPATH = "$ProjectRoot;$ProjectRoot\chaos-toolkit-lite;$env:PYTHONPATH"

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow
python -c "import handler; print('✓ handler imported successfully')" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to import handler" -ForegroundColor Red
}

python -c "import experiment_bofa; print('✓ experiment_bofa imported successfully')" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to import experiment_bofa" -ForegroundColor Red
}

$env:PYTHONPATH = "$ProjectRoot;$env:PYTHONPATH"
python -c "import experiment_runner_lite; print('✓ experiment_runner_lite imported successfully')" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to import experiment_runner_lite (may need PYTHONPATH)" -ForegroundColor Red
}

python -c "import experiment_broker_logging; print('✓ experiment_broker_logging imported successfully')" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to import experiment_broker_logging" -ForegroundColor Red
}

python -c "import boto3; print('✓ boto3 imported successfully')" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to import boto3" -ForegroundColor Red
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To activate the virtual environment manually:" -ForegroundColor Yellow
Write-Host "  .\chaos-venv\Scripts\Activate.ps1" -ForegroundColor White
Write-Host ""
Write-Host "To run tests:" -ForegroundColor Yellow
Write-Host "  python -m unittest test_handler_local_mode -v" -ForegroundColor White
Write-Host ""


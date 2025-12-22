# Test script for local_mode functionality (PowerShell)
# This script tests the handler in local mode from your local directory

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testing Handler in Local Mode" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Check if virtual environment exists
if (-not (Test-Path "chaos-venv")) {
    Write-Host "Error: Virtual environment not found. Please run .\setup.ps1 first." -ForegroundColor Red
    exit 1
}

# Activate virtual environment
Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& "chaos-venv\Scripts\Activate.ps1"

# Set PYTHONPATH for local packages
$CodeRoot = Split-Path -Parent $ScriptDir          # experiment_code
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $CodeRoot)  # repository root
# Include chaos-toolkit-lite directory for experiment_runner_lite
$env:PYTHONPATH = "$CodeRoot;$ProjectRoot;$ProjectRoot\chaos-toolkit-lite;$env:PYTHONPATH"

# Set local_mode environment variables
Write-Host "Setting local_mode environment variables..." -ForegroundColor Yellow
$env:local_mode = "true"

# Set experiment source (adjust path as needed)
$ExperimentSource = Join-Path $ScriptDir "local_only\experiments\experiment.yaml"
if (-not (Test-Path $ExperimentSource)) {
    Write-Host "Warning: Experiment file not found at $ExperimentSource" -ForegroundColor Yellow
    $ExpPath = Read-Host "Enter experiment file path (or press Enter to skip)"
    if ($ExpPath) {
        $ExperimentSource = $ExpPath
    } else {
        Write-Host "Using default dummy path" -ForegroundColor Yellow
        $ExperimentSource = "dummy\experiment.yml"
    }
}

$env:experiment_source = $ExperimentSource

# Set dummy values for AWS-related variables (not used in local mode)
$env:bucket_name = "dummy"
$env:output_bucket = "dummy"
$env:output_path = "dummy"
$env:secret_arn = "dummy"

# Verify experiment file exists (if not dummy)
if ($ExperimentSource -ne "dummy\experiment.yml" -and -not (Test-Path $ExperimentSource)) {
    Write-Host "Error: Experiment file not found: $ExperimentSource" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  local_mode: $env:local_mode" -ForegroundColor White
Write-Host "  experiment_source: $env:experiment_source" -ForegroundColor White
Write-Host "  PYTHONPATH: $env:PYTHONPATH" -ForegroundColor White
Write-Host ""

# Test 1: Import handler module
Write-Host "Test 1: Importing handler module..." -ForegroundColor Yellow
python -c "import handler; print('✓ Handler imported successfully')"
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to import handler" -ForegroundColor Red
    exit 1
}

# Test 2: Test handler function with local_mode
Write-Host ""
Write-Host "Test 2: Testing handler function with local_mode..." -ForegroundColor Yellow

$TestScript = @"
import json
import os
from handler import handler

# Create test event
event = {
    'local_mode': True,
    'experiment_source': os.environ.get('experiment_source', 'dummy/experiment.yml'),
    'configuration': {
        'aws_region': 'us-east-1'
    }
}

class MockContext:
    function_name = 'test-local-mode'
    aws_request_id = 'test-request-id'

try:
    result = handler(event, MockContext())
    print('✓ Handler executed successfully')
    print(f'  Execution mode: {result.get(\"execution_mode\", \"not set\")}')
    print(f'  State: {result.get(\"state\", \"unknown\")}')
    if 'response' in result:
        print('  Response: Available')
except Exception as e:
    print(f'✗ Handler execution failed: {e}')
    import traceback
    traceback.print_exc()
    exit(1)
"@

$TestScript | python
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Handler execution failed" -ForegroundColor Red
    exit 1
}

# Test 3: Run handler.py directly (if experiment file exists)
if ((Test-Path $ExperimentSource) -or ($ExperimentSource -eq "dummy\experiment.yml")) {
    Write-Host ""
    Write-Host "Test 3: Running handler.py directly..." -ForegroundColor Yellow
    Write-Host "Note: This will attempt to run the __main__ block" -ForegroundColor Yellow
    Write-Host ""
    
    # Check if handler.py has __main__ block that requires secret_arn
    $HandlerContent = Get-Content "handler.py" -Raw
    if ($HandlerContent -match "secret_arn") {
        Write-Host "Warning: handler.py requires secret_arn in __main__ block" -ForegroundColor Yellow
        Write-Host "Skipping direct execution test (requires AWS Secrets Manager)" -ForegroundColor Yellow
    } else {
        # Run handler.py (may fail if experiment file doesn't exist)
        python handler.py 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Note: Direct execution may require additional setup" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Local Mode Testing Complete" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Deploy Lambda function: cd terraform; terraform apply" -ForegroundColor White
Write-Host "  2. Test deployed Lambda: aws lambda invoke --function-name chaos-broker-handler ..." -ForegroundColor White
Write-Host "  3. Check CloudWatch logs: aws logs tail /aws/lambda/chaos-broker-handler --follow" -ForegroundColor White
Write-Host ""


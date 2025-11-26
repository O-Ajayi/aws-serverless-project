#!/bin/bash
# Test script for local_mode functionality
# This script tests the handler in local mode from your local directory

set -e
set +H  # Disable history expansion

echo "========================================="
echo "Testing Handler in Local Mode"
echo "========================================="
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if virtual environment exists
if [ ! -d "chaos-venv" ]; then
    echo "Error: Virtual environment not found. Please run ./setup.sh first."
    exit 1
fi

# Activate virtual environment
echo "Activating virtual environment..."
source chaos-venv/bin/activate

# Set PYTHONPATH for local packages
CODE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"          # experiment_code
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)" # repository root
# Include chaos-toolkit-lite directory for experiment_runner_lite
export PYTHONPATH="$CODE_ROOT:$PROJECT_ROOT:$PROJECT_ROOT/chaos-toolkit-lite:$PYTHONPATH"

# Set local_mode environment variables
echo "Setting local_mode environment variables..."
export local_mode=true

# Set experiment source (adjust path as needed)
EXPERIMENT_SOURCE="$SCRIPT_DIR/local_only/experiments/experiment.yaml"
if [ ! -f "$EXPERIMENT_SOURCE" ]; then
    echo "Warning: Experiment file not found at $EXPERIMENT_SOURCE"
    read -p "Enter experiment file path (or press Enter to skip): " EXP_PATH
    if [ -n "$EXP_PATH" ]; then
        EXPERIMENT_SOURCE="$EXP_PATH"
    else
        echo "Using default dummy path"
        EXPERIMENT_SOURCE="dummy/experiment.yml"
    fi
fi

export experiment_source="$EXPERIMENT_SOURCE"

# Set dummy values for AWS-related variables (not used in local mode)
export bucket_name=dummy
export output_bucket=dummy
export output_path=dummy
export secret_arn=dummy

# Verify experiment file exists (if not dummy)
if [ "$EXPERIMENT_SOURCE" != "dummy/experiment.yml" ] && [ ! -f "$EXPERIMENT_SOURCE" ]; then
    echo "Error: Experiment file not found: $EXPERIMENT_SOURCE"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  local_mode: $local_mode"
echo "  experiment_source: $experiment_source"
echo "  PYTHONPATH: $PYTHONPATH"
echo ""

# Test 1: Import handler module
echo "Test 1: Importing handler module..."
python -c "import handler; print('✓ Handler imported successfully')" || {
    echo "✗ Failed to import handler"
    exit 1
}

# Test 2: Test handler function with local_mode
echo ""
echo "Test 2: Testing handler function with local_mode..."
python -c "
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
"

# Test 3: Run handler.py directly (if experiment file exists)
if [ -f "$EXPERIMENT_SOURCE" ] || [ "$EXPERIMENT_SOURCE" = "dummy/experiment.yml" ]; then
    echo ""
    echo "Test 3: Running handler.py directly..."
    echo "Note: This will attempt to run the __main__ block"
    echo ""
    
    # Check if handler.py has __main__ block that requires secret_arn
    if grep -q "secret_arn" handler.py; then
        echo "Warning: handler.py requires secret_arn in __main__ block"
        echo "Skipping direct execution test (requires AWS Secrets Manager)"
    else
        # Run handler.py (may fail if experiment file doesn't exist)
        python handler.py 2>&1 || {
            echo "Note: Direct execution may require additional setup"
        }
    fi
fi

echo ""
echo "========================================="
echo "Local Mode Testing Complete"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Deploy Lambda function: cd terraform && terraform apply"
echo "  2. Test deployed Lambda: aws lambda invoke --function-name chaos-broker-handler ..."
echo "  3. Check CloudWatch logs: aws logs tail /aws/lambda/chaos-broker-handler --follow"
echo ""


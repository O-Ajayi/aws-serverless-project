#!/bin/bash
# Test runner script for lambda handler tests
# This script ensures the virtual environment is activated before running tests

set -e  # Exit on error
set +H  # Disable history expansion

# Get the directory where this script is located
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

# Set PYTHONPATH to include project root for editable packages
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
export PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH"

# Verify packages are installed
echo "Verifying packages are installed..."
python -c "import experiment_bofa; import experiment_runner_lite; import experiment_broker_logging" 2>/dev/null || {
    echo "Warning: Some packages may not be found via editable install."
    echo "Continuing with PYTHONPATH workaround..."
}

# Run tests with any additional arguments passed to this script
echo "Running tests..."
python -m unittest test_handler_local_mode "$@"

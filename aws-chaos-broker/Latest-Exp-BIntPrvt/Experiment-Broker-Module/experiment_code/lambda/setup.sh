#!/bin/bash
# Setup script for lambda handler dependencies
# This script avoids bash history expansion issues by using single quotes and set +H

set -e  # Exit on error
set +H  # Disable history expansion to avoid ! errors

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "========================================="
echo "Lambda Handler Setup Script"
echo "========================================="
echo ""

# Check if virtual environment exists and has pip
if [ ! -d "chaos-venv" ] || [ ! -f "chaos-venv/bin/pip" ]; then
    echo "Creating virtual environment..."
    # Remove old venv if it exists but is broken
    if [ -d "chaos-venv" ]; then
        echo "Removing broken virtual environment..."
        rm -rf chaos-venv
    fi
    python3 -m venv chaos-venv --prompt chaos-venv
    echo "Virtual environment created."
else
    echo "Virtual environment already exists."
fi

# Activate virtual environment
echo "Activating virtual environment..."
source chaos-venv/bin/activate

# Ensure pip is installed and up to date
echo ""
echo "Ensuring pip is installed and up to date..."
python3 -m ensurepip --upgrade 2>/dev/null || true
python3 -m pip install --upgrade pip setuptools wheel

# Install dependencies
echo ""
echo "Installing dependencies from requirements.txt..."
pip install -r requirements.txt

# Install local packages
echo ""
echo "Installing local packages..."

CODE_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)

# Install experiment_bofa
if [ -d "$CODE_ROOT/experiment_bofa" ]; then
    echo "Installing experiment_bofa..."
    cd "$CODE_ROOT/experiment_bofa"
    if [ ! -f "setup.py" ]; then
        echo "  Creating minimal setup.py for experiment_bofa..."
        cat > setup.py << 'SETUP_EOF'
from setuptools import setup, find_packages
setup(
    name="experiment_bofa",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[]
)
SETUP_EOF
    fi
    pip install -e . --no-build-isolation 2>/dev/null || pip install -e . || echo "⚠ Warning: experiment_bofa installation failed"
else
    echo "⚠ Warning: experiment_bofa directory not found"
fi

# Install experiment_runner_lite
if [ -d "$PROJECT_ROOT/experiment_runner_lite" ]; then
    echo "Installing experiment_runner_lite..."
    cd "$PROJECT_ROOT/experiment_runner_lite"
    if [ ! -f "setup.py" ]; then
        echo "  Creating minimal setup.py for experiment_runner_lite..."
        cat > setup.py << 'SETUP_EOF'
from setuptools import setup, find_packages
setup(
    name="experiment_runner_lite",
    version="0.1.0",
    packages=find_packages(),
    install_requires=["boto3"]
)
SETUP_EOF
    fi
    pip install -e . --no-build-isolation 2>/dev/null || pip install -e . || echo "⚠ Warning: experiment_runner_lite installation failed"
else
    echo "⚠ Warning: experiment_runner_lite directory not found"
fi

# Install experiment_broker_logging
if [ -d "$PROJECT_ROOT/Experiment-Broker-Logging-Module" ]; then
    echo "Installing experiment_broker_logging..."
    cd "$PROJECT_ROOT/Experiment-Broker-Logging-Module"
    if [ ! -f "setup.py" ]; then
        echo "  Creating minimal setup.py for experiment_broker_logging..."
        cat > setup.py << 'SETUP_EOF'
from setuptools import setup, find_packages
setup(
    name="experiment_broker_logging",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[]
)
SETUP_EOF
    fi
    pip install -e . --no-build-isolation 2>/dev/null || pip install -e . || echo "⚠ Warning: experiment_broker_logging installation failed"
else
    echo "⚠ Warning: Experiment-Broker-Logging-Module directory not found"
fi

# Go back to lambda directory
cd "$SCRIPT_DIR"

# Set PYTHONPATH for verification (helps with editable installs)
export PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH"

# Verify installation
echo ""
echo "Verifying installation..."
python -c "import handler; print('✓ handler imported successfully')" || echo "✗ Failed to import handler"
python -c "import experiment_bofa; print('✓ experiment_bofa imported successfully')" || echo "✗ Failed to import experiment_bofa"
PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH" python -c "import experiment_runner_lite; print('✓ experiment_runner_lite imported successfully')" || echo "✗ Failed to import experiment_runner_lite (may need PYTHONPATH)"
python -c "import experiment_broker_logging; print('✓ experiment_broker_logging imported successfully')" || echo "✗ Failed to import experiment_broker_logging"
python -c "import boto3; print('✓ boto3 imported successfully')" || echo "✗ Failed to import boto3"

echo ""
echo "========================================="
echo "Setup complete!"
echo "========================================="
echo ""
echo "To activate the virtual environment manually:"
echo "  source chaos-venv/bin/activate"
echo ""
echo "To run tests:"
echo "  python -m unittest test_handler_local_mode -v"

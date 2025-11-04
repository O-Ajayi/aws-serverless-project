#!/bin/bash
# Setup script for lambda handler dependencies
# This script avoids bash history expansion issues by using single quotes and set +H

set -e  # Exit on error
set +H  # Disable history expansion to avoid ! errors

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

# Install local experimentvr package
echo ""
echo "Installing local experimentvr package..."
cd ..
if [ -f "setup.py" ]; then
    # Use pip install -e . instead of python setup.py develop (modern approach)
    pip install -e . --no-build-isolation
    echo "experimentvr package installed."
else
    echo "Warning: setup.py not found in parent directory."
    echo "Please ensure you're in the correct directory structure."
fi

# Go back to lambda directory
cd lambda

# Verify installation
echo ""
echo "Verifying installation..."
python -c "import handler; print('✓ handler imported successfully')" || echo "✗ Failed to import handler"
python -c "import experimentvr; print('✓ experimentvr imported successfully')" || echo "✗ Failed to import experimentvr"
python -c "import boto3; print('✓ boto3 imported successfully')" || echo "✗ Failed to import boto3"
python -c "import chaostoolkit; print('✓ chaostoolkit imported successfully')" || echo "✗ Failed to import chaostoolkit"

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

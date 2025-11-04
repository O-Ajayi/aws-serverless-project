# Lambda Handler - Setup and Testing Guide

This directory contains the AWS Lambda handler for running ChaosToolkit experiments, with support for local testing mode.

## Prerequisites

- Python 3.9 or higher
- pip and setuptools

## Setup Instructions

### 1. Create and Activate Virtual Environment

```bash
# From the lambda directory
python3 -m venv chaos-venv

# Activate virtual environment
# On macOS/Linux:
source chaos-venv/bin/activate

# On Windows:
chaos-venv\Scripts\activate
```

### 2. Install Dependencies

```bash
# Install all required packages
pip install -r requirements.txt
```

### 3. Install Local experimentvr Package

The handler depends on the local `experimentvr` package. You need to install it in development mode:

```bash
# From the experiment_code directory (parent of lambda)
cd ..
pip install -e .
```

This will install the `experimentvr` package in editable mode so changes to the package are immediately reflected.

Alternatively, if you want to install from the experimentvr subdirectory:

```bash
cd ../experimentvr
pip install -e .
```

### 4. Verify Installation

```bash
python -c "import handler; print('Handler imported successfully')"
python -c "import experimentvr; print('experimentvr imported successfully')"
```

## Running Tests

Once all dependencies are installed, you can run the tests:

```bash
# Run all tests
python -m unittest test_handler_local_mode

# Run with verbose output
python -m unittest test_handler_local_mode -v

# Run a specific test
python -m unittest test_handler_local_mode.TestHandlerLocalMode.test_local_mode_loads_from_file_system
```

## Running Locally

You can also run the handler locally using `dev_exec.py`:

```bash
python dev_exec.py
```

Make sure to update the `experiment_source` path in `dev_exec.py` to point to a valid experiment YAML file on your system.

## Troubleshooting

### ImportError: No module named 'boto3'

Make sure you've activated your virtual environment and installed requirements:
```bash
source chaos-venv/bin/activate
pip install -r requirements.txt
```

### ImportError: No module named 'experimentvr'

The local `experimentvr` package needs to be installed:
```bash
cd ../experimentvr
pip install -e .
```

Or from the experiment_code directory:
```bash
cd ..
pip install -e .
```

### ImportError: Failed to import test module

This usually means:
1. Dependencies are not installed - run `pip install -r requirements.txt`
2. experimentvr package is not installed - install it with `pip install -e .` from the experimentvr or experiment_code directory
3. Virtual environment is not activated - make sure to activate it first

## Requirements Overview

The `requirements.txt` includes:
- **boto3** - AWS SDK for Python
- **chaostoolkit** - Chaos engineering toolkit
- **chaostoolkit-aws** - AWS extension for ChaosToolkit
- **chaostoolkit-kubernetes** - Kubernetes extension for ChaosToolkit
- **logzero** - Logging library
- **opensearch-py** - OpenSearch client
- **pytest** and related packages - For testing

## Notes

- The `experimentvr` package is a local module and must be installed separately
- Tests use mocking, so no actual AWS credentials or services are needed
- Make sure to install the experimentvr package in development mode (`-e` flag) so code changes are reflected immediately

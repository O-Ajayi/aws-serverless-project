import io
import os
import sys
import re

import requests
import json
import logging
import traceback
import boto3
from pprint import pformat

from datetime import datetime

from experiment_bofa.s3.shared import get_object, create_presigned_url, put_object, get_object_with_type
from experiment_runner_lite import aws_client
from experiment_broker_logging.logging import logger, configure_logger
from experiment_runner_lite.experiment import run_experiment, load_experiment, load_experiment_from_object
from experiment_runner_lite.types import Strategy, Schedule

configure_logger(verbose=False)

# name the package: resiliency (chaostoolkit-resiliency)

# Constants
NON_AWS_MODE_SKIP_SECRETS_MANAGER_MSG = "Non-AWS mode: Skipping Secrets Manager update"

def get_brackets_replacement(value, replacement_map, default_replacement="unknown"):
    if isinstance(value, str):
        pattern = r'<<\s*(.+?)\s*>>'
        match = re.search(pattern, value, flags=0)

        if match:
            content = match.group(1).strip()
            logger.info(f"content: {content}")
            replacement = replacement_map.get(content, default_replacement)
            logger.info(f"replacement: {replacement}")
            return value.replace(match.group(0), replacement)

        return value
    return value

def apply_replacements(experiment_metadata, replacement_map):
    for key, value in experiment_metadata.items():
        replaced_text = get_brackets_replacement(value, replacement_map)
        if replaced_text is not None:
            experiment_metadata[key] = replaced_text
    return experiment_metadata

def get_task_info(region: str):
    # get basic info from metadata
    metadata_uri = os.environ.get('ECS_CONTAINER_METADATA_URI_V4')
    response = requests.get(f"{metadata_uri}")
    task_metadata = response.json()
    logger.info("task metadata:")
    logger.info(pformat(task_metadata))

    return task_metadata

def get_task_logs_arn(task_metadata, account_id: str):
    log_options = task_metadata['logoptions']
    log_group = log_options['awslogs-group']
    log_region = log_options['awslogs-region']
    log_stream = log_options['awslogs-stream']

    return f"{log_group}:{log_stream}"


def parse_execution_mode(local_mode_value):
    """
    Parse and normalize the local_mode flag to determine execution mode.
    
    Args:
        local_mode_value: The local_mode value from event (can be bool, str, or None)
        
    Returns:
        str: Execution mode - "aws", "local", or "openshift"
        
    The local_mode flag can be provided as a boolean or string (case-insensitive).
    This determines which execution path the handler takes:
      - "aws" (default): Loads experiments from S3, uses AWS services
      - "local": Loads experiments from local filesystem, skips AWS services
      - "openshift": Loads experiments from OpenShift storage, on-prem execution
    """
    # Normalize the input to a lowercase string
    if isinstance(local_mode_value, bool):
        mode_value = "true" if local_mode_value else "false"
    else:
        mode_value = str(local_mode_value).strip().lower() if local_mode_value else "false"

    # Determine execution mode based on normalized value
    if mode_value in {"false", "0", "no"}:
        return "aws"
    elif mode_value in {"openshift", "ocp", "onprem", "on-prem"}:
        return "openshift"
    elif mode_value in {"true", "1", "yes", "local"}:
        return "local"
    else:
        # Default: treat empty/null as AWS, everything else as local
        return "local" if mode_value not in {"", "none", "null"} else "aws"

def handler(event, context):
    """Runs an experiment specified by `experiment_source`.

    ### AWS (default) invocation example (`local_mode=false`)

    ```json
    {
      "local_mode": false,
      "experiment_source": "experiments/pod-chaos-termination.yml",
      "bucket_name": "experiment-bucket-111222333",
      "output_bucket": "experiment-bucket-111222333",
      "output_path": "results/",
      "configuration": {
        "aws_region": "us-east-1",
        "cluster_name": "chaos-broker-eks",
        "namespace": "default",
        "pod_label_selector": "app=nginx"
      }
    }
    ```

    ### Local filesystem invocation example (`local_mode=true`)

    ```json
    {
      "local_mode": true,
      "experiment_source": "/Users/you/projects/chaos/local_only/experiments/experiment.yaml",
      "configuration": {
        "cluster_name": "k3s-local",
        "namespace": "chaos-testing",
        "pod_label_selector": "app=nginx"
      }
    }
    ```

    ### OpenShift/on-prem invocation example (`local_mode="openshift"`)

    ```json
    {
      "local_mode": "openshift",
      "experiment_source": "experiments/pod-chaos-termination.yml",
      "openshift_storage_path": "/mnt/openshift/chaos-files",
      "on_prem_target": {
        "provider": "openshift",
        "cluster_name": "ocp-dev",
        "namespace": "chaos-testing",
        "api_server": "https://api.ocp-dev.example.com:6443"
      },
      "configuration": {
        "cluster_name": "ocp-dev",
        "namespace": "chaos-testing",
        "pod_label_selector": "app=nginx"
      }
    }
    ```
    """
    log_capture, report_capture = _capture_experiment_logs()

    experiment_source = event.get("experiment_source")
    experiment_state = event.get("state")
    output_config = event.get("output_config")

    # ============================================================================
    # LOCAL_MODE LABEL LOGIC: Parse and normalize the local_mode flag
    # ============================================================================
    # The local_mode flag can be provided as a boolean or string (case-insensitive).
    # This determines which execution path the handler takes:
    #   - "aws" (default): Loads experiments from S3, uses AWS services
    #   - "local": Loads experiments from local filesystem, skips AWS services
    #   - "openshift": Loads experiments from OpenShift storage, on-prem execution
    # ============================================================================
    execution_mode = parse_execution_mode(event.get("local_mode", False))

    # Set both local_mode_label (for logging/tracking) and local_mode (boolean flag)
    # local_mode_label preserves the actual execution mode string ("aws", "local", "openshift")
    # local_mode is a boolean indicating whether we're in non-AWS mode
    event["local_mode_label"] = execution_mode
    event["local_mode"] = execution_mode != "aws"

    if experiment_source:
        logger.info("VS Runner Lite attempting to load experiment: %s", experiment_source)

    # ============================================================================
    # EXECUTION MODE BRANCHES: Load experiment based on execution_mode
    # ============================================================================
    # Three distinct execution paths based on the local_mode_label:
    #   1. Local filesystem mode: Load from local file path
    #   2. OpenShift mode: Load from OpenShift storage path (on-prem)
    #   3. AWS mode (default): Load from S3 bucket
    # ============================================================================
    
    if execution_mode == "local":
        # ========================================================================
        # LOCAL FILESYSTEM MODE: Load experiment from local file system
        # ========================================================================
        # This mode is used for local development and testing. It loads the
        # experiment YAML directly from the local filesystem path specified in
        # experiment_source. All AWS services are skipped (skip_aws_services=True).
        # ========================================================================
        execution_provider = event.get("execution_provider", "local-filesystem")
        logger.info("Local filesystem mode enabled - provider=%s", execution_provider)

        if not os.path.isabs(experiment_source):
            experiment_source = os.path.abspath(experiment_source)

        if not os.path.exists(experiment_source):
            raise FileNotFoundError(f"Experiment file not found: {experiment_source}")

        logger.info("Loading experiment from local file: %s", experiment_source)
        experiment = load_experiment(experiment_source)
        event.update(
            {
                "execution_mode": "local",
                "execution_provider": execution_provider,
                "skip_aws_services": True,
            }
        )
    elif execution_mode == "openshift":
        # ========================================================================
        # OPENSHIFT MODE: Load experiment from OpenShift storage (on-prem)
        # ========================================================================
        # This mode is used for on-premise OpenShift clusters. It loads the
        # experiment YAML from OpenShift storage paths (e.g., persistent volumes).
        # All AWS services are skipped (skip_aws_services=True) as this runs
        # on-premises without AWS connectivity.
        # 
        # Experiment files are stored in persistent volume at:
        #   /app/local_only/experiments/
        # The experiment_source can be:
        #   - Absolute path: /app/local_only/experiments/experiment.yaml
        #   - Relative path: experiment.yaml (resolved to /app/local_only/experiments/experiment.yaml)
        # ========================================================================
        execution_provider = "openshift"
        storage_base = event.get("openshift_storage_path") or os.environ.get(
            "OPENSHIFT_STORAGE_PATH", "/app/local_only"
        )
        on_prem_target = event.get("on_prem_target", {})
        
        logger.info(
            "OpenShift mode enabled - storage_base=%s target=%s",
            storage_base or "(not provided)",
            on_prem_target or "not specified",
        )
        
        # Resolve experiment source path
        # If not absolute, join with storage_base/experiments directory
        if not os.path.isabs(experiment_source):
            # Default to experiments subdirectory
            experiments_dir = os.path.join(storage_base, "experiments")
            experiment_source = os.path.join(experiments_dir, experiment_source)
        else:
            # Already absolute, use as-is
            experiment_source = experiment_source
        
        # Ensure absolute path
        experiment_source = os.path.abspath(experiment_source)
        
        if not os.path.exists(experiment_source):
            raise FileNotFoundError(
                f"Experiment file not found for OpenShift mode: {experiment_source}"
            )
        
        logger.info("Loading experiment from OpenShift storage: %s", experiment_source)
        experiment = load_experiment(experiment_source)
        event.update(
            {
                "execution_mode": "openshift",
                "execution_provider": execution_provider,
                "on_prem_target": on_prem_target,
                "openshift_storage_path": storage_base,
                "skip_aws_services": True,
            }
        )
    else:
        # ========================================================================
        # AWS MODE (default): Load experiment from S3 bucket
        # ========================================================================
        # This is the default execution mode for AWS Lambda/ECS. It loads the
        # experiment YAML from an S3 bucket specified in event["bucket_name"].
        # AWS services are used throughout (skip_aws_services=False).
        # ========================================================================
        try:
            obj, content_type = get_object_with_type(
                bucket_name=event.get("bucket_name"),
                key=experiment_source,
                configuration=event.get("configuration", {})
            )
        except Exception as e:
            logger.exception("Unable to retrieve experiment %s: %s", experiment_source, e)
            raise

        experiment = load_experiment_from_object(obj=obj, content_type=content_type)
        event.update(
            {
                "execution_mode": "aws",
                "execution_provider": "aws",
                "skip_aws_services": False,
            }
        )

    # ============================================================================
    # EXPERIMENT EXECUTION: Run the loaded experiment
    # ============================================================================
    # Add local_mode to experiment configuration so activities can detect it
    if "configuration" not in experiment:
        experiment["configuration"] = {}
    experiment["configuration"]["local_mode"] = execution_mode in ("local", "openshift")
    experiment["configuration"]["execution_mode"] = execution_mode
    
    experiment_journal = run_experiment(experiment)
    if experiment_journal.get("status") in ["completed", "success"]:
        event.update({"state": "done"})
    else:
        event.update({"state": "failed"})

    # ============================================================================
    # AWS-SPECIFIC PROCESSING: ECS metadata and replacements (AWS mode only)
    # ============================================================================
    # Only process ECS metadata and apply dynamic replacements when running in
    # AWS mode. In local/OpenShift modes, these AWS-specific operations are skipped
    # to prevent errors and unnecessary AWS API calls.
    # ============================================================================
    if execution_mode == "aws":
        region = os.getenv("AWS_REGION", "unknown")
        account_id = os.getenv("account_id", "unknown")
        
        # Only get task metadata if running in ECS (metadata URI is available)
        metadata_uri = os.environ.get('ECS_CONTAINER_METADATA_URI_V4')
        if metadata_uri:
            try:
                task_metadata = get_task_info(region)
                
                # Create the dynamic replacement values
                replacement_map = {
                    "execution_id": os.getenv("execution_id", "unknown"),
                    "region": region,
                    "cloudwatch_log_stream": get_task_logs_arn(task_metadata, account_id),
                    "account_id": account_id,
                    "git_commit_hash": os.getenv("git_commit_hash", "unknown")
                }
                experiment_metadata = experiment_journal.get("experiment_metadata", {})
                _ = apply_replacements(experiment_metadata, replacement_map)
            except Exception as e:
                logger.warning(f"Unable to get ECS task metadata or apply replacements: {e}")
        else:
            logger.info("Not running in ECS, skipping task metadata retrieval")

    # ============================================================================
    # AWS-SPECIFIC OUTPUT: S3 upload (AWS mode only)
    # ============================================================================
    # Only upload experiment journal to S3 when running in AWS mode and output
    # configuration is provided. In local/OpenShift modes, S3 upload is skipped
    # as AWS services are not available or desired.
    # ============================================================================
    if execution_mode == "aws" and event.get("output_bucket") and event.get("output_path"):
        try:
            output_path = event["output_path"] + ("/" if event["output_path"].find("/") == -1 else "")
            experiment_name = "".join(experiment_source.split("/")[-1].split(".")[:-1])
            experiment_extension = experiment_source.split("/")[-1].split(".")[-1]
            timestamp = str(datetime.now().replace(second=0, microsecond=0)).replace(":", "-")

            key = output_path + experiment_name + timestamp + experiment_extension

            output_s3 = put_object(
                bucket_name=event["output_bucket"],
                key=key,
                contents=json.dumps(experiment_journal),
            )
            logger.info(f"Experiment journal uploaded to S3 as: s3://{event['output_bucket']}/{key}")
        except Exception:
            exc_str = traceback.format_exc()
            logger.error(f"Unable to upload experiment journal to S3: {exc_str}")
    elif execution_mode in {"local", "openshift"}:
        # ========================================================================
        # LOCAL/OPENSHIFT MODE OUTPUT: Save experiment journal to local file
        # ========================================================================
        try:
            # Determine the local_only directory path relative to this file
            script_dir = os.path.dirname(os.path.abspath(__file__))
            local_only_dir = os.path.join(script_dir, "local_only")
            journals_dir = os.path.join(local_only_dir, "journals")
            
            # Create journals directory if it doesn't exist
            os.makedirs(journals_dir, exist_ok=True)
            
            # Generate filename similar to S3 key format
            # Output is always JSON format, so use .json extension
            experiment_name = ""
            experiment_extension = ".json"
            
            # Extract experiment name from experiment_source if available
            if experiment_source:
                experiment_basename = os.path.basename(experiment_source)
                # Remove extension to get base name (we'll use .json for output)
                if "." in experiment_basename:
                    experiment_name = "".join(experiment_basename.rsplit(".", 1)[0])
                else:
                    experiment_name = experiment_basename
            
            # Use experiment title if name is not available
            if not experiment_name and experiment_journal.get("experiment", {}).get("title"):
                experiment_name = experiment_journal["experiment"]["title"]
                experiment_name = re.sub(r'[^\w\-_]', '_', experiment_name)  # Sanitize filename
            
            # Default name if still not available
            if not experiment_name:
                experiment_name = "experiment"
            
            # Create timestamp for filename (replace spaces and colons with dashes)
            timestamp = str(datetime.now().replace(second=0, microsecond=0)).replace(":", "-").replace(" ", "-")
            
            # Generate filename
            filename = f"{experiment_name}_{timestamp}{experiment_extension}"
            filepath = os.path.join(journals_dir, filename)
            
            # Write experiment journal to file
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(experiment_journal, f, indent=2, default=str)
            
            logger.info(f"Experiment journal saved to local file: {filepath}")
            
        except Exception as e:
            exc_str = traceback.format_exc()
            logger.warning(f"Unable to save experiment journal to local file: {exc_str}")
            logger.info("Non-AWS mode: Skipping local file output (continuing with execution)")

    event.update({"response": json.dumps(experiment_journal)})
    event.update({"report_capture": str(report_capture.getvalue())})

    return event


def _capture_experiment_logs():
    """Captures logs for ChaosToolkit experiments"""
    log_capture_string = io.StringIO()
    error_handler = logging.StreamHandler(log_capture_string)
    error_handler.setLevel(logging.ERROR)
    logger.addHandler(error_handler)

    report_capture_string = io.StringIO()
    info_handler = logging.StreamHandler(report_capture_string)
    info_handler.setLevel(logging.INFO)
    logger.addHandler(info_handler)

    return log_capture_string, report_capture_string

if __name__ == "__main__":
    print("TASK START")

    # ============================================================================
    # __MAIN__ BLOCK: Local execution mode setup
    # ============================================================================
    # This block handles local execution when running handler.py directly.
    # It parses environment variables to determine the execution mode:
    #   - local_mode=true: Local filesystem mode (no AWS services)
    #   - local_mode=openshift: OpenShift/on-prem mode (no AWS services)
    #   - local_mode=false or unset: AWS mode (requires AWS credentials/services)
    # ============================================================================

    variables = ["bucket_name", "experiment_source", "output_bucket", "output_path"]
    event = {}
    for var in variables:
        val = os.environ.get(var)
        if val is not None:
            event[var] = val

    local_mode_env = os.environ.get("local_mode", "false")
    execution_mode = parse_execution_mode(local_mode_env)

    if execution_mode == "local":
        # ========================================================================
        # LOCAL FILESYSTEM MODE: Skip AWS services
        # ========================================================================
        event["local_mode"] = True
        event["execution_mode"] = "local"
        event["execution_provider"] = os.environ.get("execution_provider", "local-filesystem")
        event["skip_aws_services"] = True
        logger.info("Local filesystem mode enabled via __main__ block")
        
        # AWS-specific code (secret_arn, secrets_client) is not initialized
        # to prevent errors when AWS credentials/services are not available
        
    elif execution_mode == "openshift":
        # ========================================================================
        # OPENSHIFT MODE: Skip AWS services
        # ========================================================================
        event["local_mode"] = "openshift"
        event["execution_mode"] = "openshift"
        event["execution_provider"] = "openshift"
        event["skip_aws_services"] = True
        event["openshift_storage_path"] = os.environ.get("openshift_storage_path") or os.environ.get("OPENSHIFT_STORAGE_PATH")
        on_prem_target = {
            "provider": "openshift",
            "cluster_name": os.environ.get("openshift_cluster_name"),
            "namespace": os.environ.get("openshift_namespace"),
            "api_server": os.environ.get("openshift_api_server"),
            "token": os.environ.get("openshift_token"),
        }
        event["on_prem_target"] = {k: v for k, v in on_prem_target.items() if v}
        logger.info(
            "OpenShift mode enabled via __main__ block - storage_base=%s target=%s",
            event.get("openshift_storage_path"),
            event.get("on_prem_target", {}),
        )
        
        # AWS-specific code (secret_arn, secrets_client) is not initialized
        # to prevent errors when AWS credentials/services are not available
        
    else:
        # ========================================================================
        # AWS MODE: Initialize AWS services (Secrets Manager)
        # ========================================================================
        # AWS mode requires AWS credentials and services. Initialize secret_arn
        # and secrets_client here (only in AWS mode) to update experiment results
        # in AWS Secrets Manager after execution.
        # ========================================================================
        missing = [var for var in variables if var not in event]
        if missing:
            raise KeyError(f"Missing required environment variables for AWS execution: {missing}")
        event["local_mode"] = False
        event["execution_mode"] = "aws"
        event["execution_provider"] = "aws"
        event["skip_aws_services"] = False
        logger.info("AWS mode enabled - execution_mode set to 'aws'")
        
        # Initialize AWS Secrets Manager client only in AWS mode
        secret_arn = os.environ['secret_arn']
        secrets_client = aws_client('secretsmanager')
        secret_response = secrets_client.get_secret_value(SecretId=secret_arn)
        params = json.loads(secret_response['secretstring'])
    
    print(event)

    print("HANDLER START")

    try:
        result = handler(event, None)
        print("HANDLER COMPLETE")
        result_data = {
            "state": "done",
            "data": result,
        }
    except Exception as e:
        print("HANDLER FAIL")
        # ========================================================================
        # ERROR HANDLING: Update AWS Secrets Manager (AWS mode only)
        # ========================================================================
        failure_data = {
            "state": "failed",
            "error": str(e),
            "details": "Handler processing failed during execution",
        }
        # Only update secret if running in AWS mode (secrets_client is initialized)
        if event.get("execution_mode") == "aws":
            update_response = secrets_client.update_secret(
                SecretId = secret_arn,
                SecretString = json.dumps(failure_data)
            )
        else:
            logger.info(NON_AWS_MODE_SKIP_SECRETS_MANAGER_MSG)
        raise

    try:
        # ========================================================================
        # SUCCESS HANDLING: Update AWS Secrets Manager (AWS mode only)
        # ========================================================================
        # Only update secret if running in AWS mode (secrets_client is initialized)
        if event.get("execution_mode") == "aws":
            update_response = secrets_client.update_secret(
                SecretId = secret_arn,
                SecretString = json.dumps(result_data)
            )
            print("TASK COMPLETE")
        else:
            logger.info(NON_AWS_MODE_SKIP_SECRETS_MANAGER_MSG)
            print("TASK COMPLETE (local mode - no Secrets Manager update)")
    except Exception as e:
        print("TASK FAIL")
        failure_data = {
            "state": "failed",
            "error": str(e),
            "details": "task processing failed during execution",
        }
        # Only update secret if running in AWS mode (secrets_client is initialized)
        if event.get("execution_mode") == "aws":
            update_response = secrets_client.update_secret(
                SecretId = secret_arn,
                SecretString = json.dumps(failure_data)
            )
        else:
            logger.info(NON_AWS_MODE_SKIP_SECRETS_MANAGER_MSG)
        raise

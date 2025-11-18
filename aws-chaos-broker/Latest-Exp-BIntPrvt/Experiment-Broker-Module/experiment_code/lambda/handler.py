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

    mode_raw = event.get("local_mode", False)
    if isinstance(mode_raw, bool):
        mode_value = "true" if mode_raw else "false"
    else:
        mode_value = str(mode_raw).strip().lower()

    if mode_value in {"false", "0", "no"}:
        execution_mode = "aws"
    elif mode_value in {"openshift", "ocp", "onprem", "on-prem"}:
        execution_mode = "openshift"
    elif mode_value in {"true", "1", "yes", "local"}:
        execution_mode = "local"
    else:
        execution_mode = "local" if mode_value not in {"", "none", "null"} else "aws"

    event["local_mode_label"] = execution_mode
    event["local_mode"] = execution_mode != "aws"

    if experiment_source:
        logger.info("VS Runner Lite attempting to load experiment: %s", experiment_source)

    if execution_mode == "local":
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
        execution_provider = "openshift"
        storage_base = event.get("openshift_storage_path") or os.environ.get(
            "OPENSHIFT_STORAGE_PATH"
        )
        on_prem_target = event.get("on_prem_target", {})

        logger.info(
            "OpenShift mode enabled - storage_base=%s target=%s",
            storage_base or "(not provided)",
            on_prem_target or "not specified",
        )

        if storage_base and not os.path.isabs(experiment_source):
            experiment_source = os.path.join(storage_base, experiment_source)

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
        # AWS Lambda/ECS mode: load from S3
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

    experiment_journal = run_experiment(experiment)
    if experiment_journal.get("status") in ["completed", "success"]:
        event.update({"state": "done"})
    else:
        event.update({"state": "failed"})

    # Only process ECS metadata and replacements if not in local mode
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

    # Only upload to S3 if running in AWS mode and output config is provided
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
        logger.info("Non-AWS mode: Skipping S3 output upload")

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

    secret_arn = os.environ['secret_arn']
    secrets_client = aws_client('secretsmanager')
    secret_response = secrets_client.get_secret_value(SecretId=secret_arn)
    params = json.loads(secret_response['secretstring'])

    variables = ["bucket_name", "experiment_source", "output_bucket", "output_path"]
    event = {}
    for var in variables:
        val = os.environ.get(var)
        if val is not None:
            event[var] = val

    local_mode_env = os.environ.get("local_mode", "false")
    local_mode_label = (
        local_mode_env.lower()
        if isinstance(local_mode_env, str)
        else ("true" if local_mode_env else "false")
    )

    if local_mode_label in {"true", "1", "yes", "local"}:
        event["local_mode"] = True
        event["execution_mode"] = "local"
        event["execution_provider"] = os.environ.get("execution_provider", "local-filesystem")
        event["skip_aws_services"] = True
        logger.info("Local filesystem mode enabled via __main__ block")
    elif local_mode_label in {"openshift", "ocp", "onprem", "on-prem"}:
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
    else:
        missing = [var for var in variables if var not in event]
        if missing:
            raise KeyError(f"Missing required environment variables for AWS execution: {missing}")
        event["local_mode"] = False
        event["execution_mode"] = "aws"
        event["execution_provider"] = "aws"
        event["skip_aws_services"] = False
        logger.info("AWS mode enabled - execution_mode set to 'aws'")
    
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
        failure_data = {
            "state": "failed",
            "error": "str(e)",
            "details": "Handler processing failed during execution",
        }
        update_response = secrets_client.update_secret(
            SecretId = secret_arn,
            SecretString = json.dumps(failure_data)
        )
        raise

    try:
        #print(f" dumped result json \n", json.dumps(result_data, indent=4))
        update_response = secrets_client.update_secret(
            SecretId = secret_arn,
            SecretString = json.dumps(result_data)
        )
        print("TASK COMPLETE")
    except Exception as e:
        print("TASK FAIL")
        failure_data = {
            "state": "failed",
            "error": "str(e)",
            "details": "task processing failed during execution",
        }
        update_response = secrets_client.update_secret(
            SecretId = secret_arn,
            SecretString = json.dumps(failure_data)
        )
        raise

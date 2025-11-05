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
    """Runs an experiment by experiment_source". 
    
    Provide the following event data to invoke the function: 
    { 
        "experiment_source": "authorizations/tc001.yml", 
        "bucket_name": "chaos-testing-bucket", 
        ...(additional values for running experiment: AZ, Region, Environment, etc.) 
    } 
    
    For local testing:
    {
        "local_mode": true,
        "experiment_source": "/path/to/experiment.yml",  # or relative path
        ...(additional values for running experiment: AZ, Region, Environment, etc.)
    }
    """
    log_capture, report_capture = _capture_experiment_logs()

    experiment_source = event.get("experiment_source")
    experiment_state = event.get("state")
    output_config = event.get("output_config")
    local_mode = event.get("local_mode", False)

    if experiment_source:
        logger.info("VS Runner Lite attempting to load experiment: %s", experiment_source)

    # Load experiment from local file or S3
    if local_mode:
        # Local mode: load from file system
        if not os.path.isabs(experiment_source):
            # If relative path, try to resolve from current directory
            experiment_source = os.path.abspath(experiment_source)
        
        if not os.path.exists(experiment_source):
            raise FileNotFoundError(f"Experiment file not found: {experiment_source}")
        
        logger.info("Loading experiment from local file: %s", experiment_source)
        experiment = load_experiment(experiment_source)
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

    experiment_journal = run_experiment(experiment)
    if (
        experiment_journal.get("status") in ["completed", "success"]
    ):
        event.update({"state": "done"})
    else:
        event.update({"state": "failed"})

    # Only process ECS metadata and replacements if not in local mode
    if not local_mode:
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

    # Only upload to S3 if not in local mode and output config is provided
    if not local_mode and event.get("output_bucket") and event.get("output_path"):
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
    elif local_mode:
        logger.info("Local mode: Skipping S3 output upload")

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
    event = {v:os.environ[v] for v in variables}
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

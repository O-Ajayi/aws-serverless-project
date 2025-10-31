import io
import logging
import sys
import os
import json
import boto3
import traceback

from datetime import datetime

from experimentvr.opensearch.shared import upload_experiment_journal
from botocore.config import Config
from experimentvr.s3.shared import get_object, create_presigned_url, put_object
from chaoslib.experiment import run_experiment
from chaoslib.loader import load_experiment
from chaostoolkit.logging import configure_logger
from logzero import logger


configure_logger()


# name the package: resiliency (chaostoolkit-resiliency)


def handler(event, context):
    """Runs an experiment by `experiment_source`.

    Provide the following event data to invoke the function:

    {
      "experiment_source": "authorizations/tc001.yml",
      "bucket_name": "chaos-testing-bucket",
      ...(additional values for running experiment: AZ, Region, Environment, etc.)
    }
    """
    log_capture, report_capture = __capture_experiment_logs()

    experiment_source = event.get("experiment_source")
    experiment_state = event.get("state")
    output_config = event.get("output_config")
    if experiment_source:
        logger.info("ChaosToolkit attempting to load experiment: %s", experiment_source)

    try:
        get_object(
            bucket_name=event.get("bucket_name"),
            filename=experiment_source,
            configuration=event.get("configuration", {}),
        )
    except Exception as e:
        logger.exception("Unable to retrieve experiment %s: %s", experiment_source, e)
        raise

    experiment = load_experiment(
        create_presigned_url(event.get("bucket_name"), experiment_source)
    )

    experiment_journal = run_experiment(experiment)

    print("Journal contents: " + str(experiment_journal))
    if (
        experiment_journal.get("status") == "success"
        or experiment_journal.get("status") == "completed"
    ):
        event.update({"state": "done"})
    else:
        event.update({"state": "failed"})

    if "OPENSEARCH" in output_config.keys():
        try:
            upload_experiment_journal(
                journal=experiment_journal, output_config=output_config["OPENSEARCH"]
            )
            logger.info(f"Experiment journal uploaded to Opensearch")
        except Exception:
            exc_str = traceback.format_exc()
            logger.error(
                f"Unable to upload experiment journal to Opensearch: {exc_str}"
            )

    if "S3" in output_config.keys():
        try:
            key = output_config["S3"]["path"] + str(
                datetime.now().replace(second=0, microsecond=0)
            ).replace(" ", "-")
            output_s3 = put_object(
                bucket_name=output_config["S3"]["bucket_name"],
                key=key,
                contents=json.dumps(experiment_journal),
            )
            logger.info(f"Experiment journal uploaded to S3 as: {key} ")
        except Exception:
            exc_str = traceback.format_exc()
            logger.error(f"Unable to upload experiment journal to S3: {exc_str}")

    event.update({"response": json.dumps(experiment_journal)})
    event.update({"report_capture": str(report_capture.getvalue())})

    session = boto3.Session()
    dynamodb = session.resource("dynamodb")

    response = dynamodb.Table("experiment_pipeline_alpha_reporting").put_item(
        Item={"ISO8601": datetime.now().isoformat(), "event": event}
    )

    return event


def __capture_experiment_logs():
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

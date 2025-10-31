import sys
import logging
import boto3


logging.basicConfig(level=logging.ERROR)


def get_cloudwatch_metric_alarm_status(cloudwatch_alarm_name):
    """Get a str of cloudwatch status from a given Cloudwatch alarm name."""

    session = boto3.Session()
    cloudwatch = session.client("cloudwatch", "us-east-1")

    cloudwatch_alarm_status = cloudwatch.describe_alarms(
        AlarmNames=[cloudwatch_alarm_name]
    )
    return_value = cloudwatch_alarm_status["MetricAlarms"][0]["StateValue"]

    return return_value

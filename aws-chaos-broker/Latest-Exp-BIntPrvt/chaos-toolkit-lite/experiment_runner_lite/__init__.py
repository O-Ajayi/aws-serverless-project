import os
import boto3

from experiment_runner_lite.types import Configuration
from experiment_runner_lite.exceptions import InvalidActivity
from experiment_runner_lite.logging import logger

__all__ = ["aws_client", "aws_resource"]

def _handle_params(configuration: Configuration) -> dict[str, str]:
    params = {}

    profile_name = configuration.get("aws_profile_name", None)
    region = configuration.get("aws_region", None)

    if not region:
        region = os.getenv("AWS_REGION", None)

    if not region:
        region = os.getenv("AWS_DEFAULT_REGION", None)

    if not region:
        raise InvalidActivity(
            "AWS region is required. Not in configuration or configured in environment. variables 'AWS_REGION' or 'AWS_D"
        )
 
    params["aws_access_key_id"] = configuration.get("aws_access_key_id", None)
    params["aws_secret_access_key"] = configuration.get("aws_secret_access_key", None)
    params["aws_session_token"] = configuration.get("aws_session_token", None)
    params["region_name"] = region

    if boto3.DEFAULT_SESSION is None:
        logger.debug(
            "No default boto3 session found. Setting up default session..."
        )
        boto3.setup_default_session(profile_name=profile_name, **params)

    return params

def _handle_sts_credentials(configuration: Configuration, params: dict) -> dict[str, str]:
    default_session_name = "VRRunnerLite"
    assume_role_arn = configuration.get("aws_assume_role_arn", None)
    assume_role_session_name = configuration.get("aws_assume_role_session_name", None)

    if not assume_role_session_name:
        logger.debug(f"No session name provided. Using default session name '{default_session_name}'")
        assume_role_session_name = default_session_name

    sts_client = boto3.client("sts", **params)

    params = {
        "RoleArn": assume_role_arn,
        "RoleSessionName": assume_role_session_name,
    }

    response = sts_client.assume_role(**params)
    credentials = response["Credentials"]

    params = {
        "aws_access_key_id": credentials["AccessKeyId"],
        "aws_secret_access_key": credentials["SecretAccessKey"],
        "aws_session_token": credentials["SessionToken"],
        "region_name": params["region_name"]
    }

    return params


def aws_client(service: str, configuration: Configuration = {}):
    """ 
    Returns an AWS client for the specified service. 
    """

    params = _handle_params(configuration)

    if not configuration.get("aws_assume_role_arn"):
        logger.debug(f"Creating client for service '{service}' using profile: {configuration.get('aws_profile')}")
        return boto3.client(service, **params)
    else:
        logger.debug(f"Getting credentials by assuming role: {configuration.get('aws_assume_role_arn')}")
        params = _handle_sts_credentials(configuration, params)
        logger.debug(f"Creating client for service '{service}' with assumed role.")


def aws_resource(service: str, configuration: Configuration = {}):
    """ 
    Returns an AWS resource for the specified service. 
    """

    params = _handle_params(configuration)

    if not configuration.get("aws_assume_role_arn"):
        logger.debug(f"Creating resource for service '{service}' using profile: {configuration.get('aws_profile_name', 'default')}")
        return boto3.resource(service, **params)
    else:
        logger.debug(f"Setting credentials by assuming role: {configuration.get('aws_assume_role_arn')}")
        params = _handle_sts_credentials(params, configuration)
        logger.debug(f"Creating resource for service '{service}' with assumed role.")
        return boto3.resource(service, **params)
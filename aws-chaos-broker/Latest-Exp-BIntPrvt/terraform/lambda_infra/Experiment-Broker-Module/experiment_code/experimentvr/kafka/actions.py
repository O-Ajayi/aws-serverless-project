import logging
from typing import List

from botocore.exceptions import ClientError
import boto3
from experimentvr.kafka.shared import get_broker_endpoints

logging.basicConfig(level=logging.ERROR)


def blackhole_kafka(
    region: str = None,
    msk_cluster: str = None,
    node_key: str = None,
    node_values: List[str] = None,
):
    """Runs SSM command BlackHoleKafka.yml on all targets with specified tag key and value"""

    session = boto3.Session()
    ssm = session.client("ssm", region)

    kafkanodes = get_broker_endpoints(region, msk_cluster)

    try:
        ssm.send_command(
            DocumentName="BlackHoleKafka",
            Targets=[{"Key": node_key, "Values": node_values}],
            Parameters={
                "kafkanodes": [kafkanodes],
            },
            TimeoutSeconds=120,
            DocumentVersion="1",
            MaxErrors="10",
            MaxConcurrency="1",
        )
    except ClientError as e:
        logging.error(e)

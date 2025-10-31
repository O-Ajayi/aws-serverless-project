from chaosaws import aws_client
from chaoslib.types import Configuration


def get_vpc_ids(configuration: Configuration):
    """
    Returns a list of VPC Ids available in AWS Account configuration.
    """
    ec2 = aws_client("ec2", configuration=configuration)
    return [vpc["VpcId"] for vpc in ec2.describe_vpcs()["Vpcs"]]

from botocore.exceptions import ClientError
from chaosaws import aws_client
from experimentvr.az.shared import (
    apply_new_nacl,
    get_subnets_in_az,
    get_subnets_nacl_associations,
)
from experimentvr.state import (
    load_rollback_config,
    save_rollback_config,
    delete_rollback_config,
)
from experimentvr.vpc.shared import get_vpc_ids
from chaoslib.types import Configuration

from logzero import logger

__all__ = ["disable_az", "reenable_az"]


def disable_az(
    availability_zone: str,
    state_file_name: str = "disable_az.json",
    configuration: Configuration = None,
):
    """Disables an AZ by creating a blackhole NACL and attaching to the VPC."""
    if load_rollback_config(state_file_name, configuration=configuration):
        logger.info("Previous state found, rolling back first.")
        reenable_az(state_file_name, configuration=configuration)
    else:
        logger.info("No existing (previous) state found, continuing.")

    rollback_nacl = {}
    blackhole_nacl_ids = []
    for vpc_id in get_vpc_ids(configuration=configuration):
        try:
            subnets = get_subnets_in_az(
                availability_zone=availability_zone,
                vpc_id=vpc_id,
                configuration=configuration,
            )
            nacl_associations = get_subnets_nacl_associations(
                subnets=list(subnets), configuration=configuration
            )
            blackhole_nacl_id = __create_blackhole_nacl(
                vpc_id=vpc_id, configuration=configuration
            )
            blackhole_nacl_ids.append(blackhole_nacl_id)
            rollback_nacl = {
                **rollback_nacl,
                **apply_new_nacl(
                    nacl_associations=nacl_associations,
                    new_nacl_id=blackhole_nacl_id,
                    configuration=configuration,
                ),
            }
        except ClientError as e:
            # Log ClientError but continue so that state is saved
            logger.error(e)

    # Save NACL Associations to rollback config for future rollback / re-enabling.
    save_rollback_config(
        rollback_config={
            "rollback_nacl_association": rollback_nacl,
            "blackhole_nacl_ids": blackhole_nacl_ids,
        },
        filename=state_file_name,
        configuration=configuration,
    )


def reenable_az(
    state_file_name: str = "disable_az.json", configuration: Configuration = None
):
    """Re-enables a previously disabled AZ (based on the state in S3)."""
    if rollback_config := load_rollback_config(
        state_file_name, configuration=configuration
    ):
        ec2 = aws_client("ec2", configuration=configuration)

        logger.info("Restoring NACL associations...")
        for nacl_association_id, nacl_id in rollback_config[
            "rollback_nacl_associations"
        ].items():
            ec2.replace_network_acl_association(
                AssociationId=nacl_association_id, NetworkAclId=nacl_id
            )

        for blackhole_nacl_id in rollback_config["blackhole_nacl_ids"]:
            logger.info("Deleting NACL: %s", blackhole_nacl_id)
            ec2.delete_network_acl(NetworkAclId=blackhole_nacl_id)

        # Cleanup
        delete_rollback_config(filename=state_file_name, configuration=configuration)

    else:
        logger.warning("No previous state found, cannot re-enable AZ.")


def __create_blackhole_nacl(vpc_id: str, configuration: Configuration = None):
    ec2client = aws_client("ec2", configuration=configuration)
    nacl_id = ec2client.create_network_acl(VpcId=vpc_id)["NetworkAcl"]["NetworkAclId"]

    try:
        ec2client.create_tags(
            Resources=[nacl_id], Tags=[{"Key": "Name", "Value": "Blackhole"}]
        )
    except ClientError as e:
        logger.error(e)

    # Egress
    ec2client.create_network_acl_entry(
        CidrBlock="0.0.0.0/0",
        Egress=True,
        PortRange={"From": 0, "To": 65535},
        NetworkAclId=nacl_id,
        Protocol="-1",
        RuleAction="deny",
        RuleNumber=100,
    )

    # Ingress
    ec2client.create_network_acl_entry(
        CidrBlock="0.0.0.0/0",
        Egress=False,
        PortRange={"From": 0, "To": 65535},
        NetworkAclId=nacl_id,
        Protocol="-1",
        RuleAction="deny",
        RuleNumber=100,
    )

    logger.info("Blackhole NACL created in %s: %s", vpc_id, nacl_id)
    return nacl_id

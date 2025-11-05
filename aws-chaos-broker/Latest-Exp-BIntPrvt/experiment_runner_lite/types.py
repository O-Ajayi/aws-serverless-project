from typing import Dict, Any, Union
import enum

__all__ = [
    "Action",
    "Experiment",
    "Probe",
    "Activity",
    "Secrets",
    "Configuration",
    "AWSResponse",
    "Discovery",
    "DiscoveryActivities",
    "Strategy",
    "Schedule",
    "Schedules"
]

Action = Dict[str, Any]
Experiment = Dict[str, Any]
Probe = Dict[str, Any]
Activity = Union[Probe, Action]
Secrets = Dict[str, str]
Configuration = Dict[str, Any]
"""
Custom dictionary type for Experiment Broker.

Parameters:
    state_bucket (str): The name of the S3 bucket to use for state
    aws_region_name (Optional[str]): The region to use when creating
    aws_access_key_id (Optional[str]): The access key for your AWS
    aws_secret_access_key (Optional[str]): The secret key for your
    aws_session_token (Optional[str]): The session key for your AWS
    aws_profile_name (Optional[str]): The name of the profile to
    aws_assume_role_arn (Optional[str]): The Amazon Resource Name
"""
AWSResponse = Dict[str, Any]
"""
Generic type for hinting at AdResponse from adsuit service.
"""

Discovery = Dict[str, Any]
DiscoveredActivities = Dict[str, Any]


class Strategy(enum.Enum):
    BEFORE_METHOD = "before-method-only"
    AFTER_METHOD = "after-method-only"
    DURING_METHOD = "during-method-only"
    DEFAULT = "default"
    CONTINUOUS = "continuous"
    SKIP = "skip"

    @staticmethod
    def from_string(value: str) -> "Strategy":
        if value == "default":
            return Strategy.DEFAULT
        elif value == "before-method-only":
            return Strategy.BEFORE_METHOD
        elif value == "after-method-only":
            return Strategy.AFTER_METHOD
        elif value == "during-method-only":
            return Strategy.DURING_METHOD
        elif value == "continuous":
            return Strategy.CONTINUOUS
        elif value == "skip":
            return Strategy.SKIP


class Schedules:
    def __init__(
        self,
        continuous_hypothesis_frequency: float = 1.0,
        fail_fast: bool = False,
        fail_fast_ratio: float = 0,
    ):
        self.continuous_hypothesis_frequency = continuous_hypothesis_frequency
        self.fail_fast = fail_fast
        self.fail_fast_ratio = fail_fast_ratio


# Alias for backwards compatibility
Schedule = Schedules
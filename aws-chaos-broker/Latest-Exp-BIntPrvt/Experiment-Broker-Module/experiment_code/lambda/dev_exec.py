from handler import handler
from dataclasses import dataclass
import os
import sys


@dataclass
class context:
    function_name: str = "test"
    aws_request_id: str = "88888888-4444-4444-4444-121212121212"
    invoked_function_arn: str = "arn:aws:lambda:eu-west-1:123456789101:function:test"


# Local mode: test with a local experiment file
# Use absolute path or relative path from where you run this script
event_dict = {
    "local_mode": True,  # Enable local mode
    "experiment_source": "../../../cdk/lambda_infra/experiments/tc-010-1.yml",  # Path to local experiment
    # Note: In local mode, you don't need bucket_name or output_config
    # unless you want to test S3/OpenSearch uploads explicitly
    "configuration": {
        "aws_region": "us-east-1",
    },
}

print("Running in LOCAL MODE")
print("=" * 50)
print(f"Experiment file: {event_dict['experiment_source']}")

# Resolve the absolute path for clarity
abs_path = os.path.abspath(event_dict["experiment_source"])
print(f"Absolute path: {abs_path}")
print(f"File exists: {os.path.exists(abs_path)}")
print("=" * 50)

handler(event=event_dict, context=context)

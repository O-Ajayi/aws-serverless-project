#!/usr/bin/env python3

import aws_cdk as cdk

from ExperimentFoundationLambda.experiment_foundation_lambda import (
    ExperimentFoundationLambdaStack,
)

app = cdk.App()
ExperimentFoundationLambdaStack(app, "experiment-foundation-lambda")
app.synth()

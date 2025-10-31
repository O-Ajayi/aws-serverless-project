import code
import json
import os
import time
import zipfile
import random
import yaml

import aws_cdk as core

from zipfile import ZipFile

from aws_cdk import (
    aws_iam as iam,
    aws_s3 as s3,
    aws_s3_deployment as s3deploy,
    aws_lambda as lambda_,
    aws_kms as kms,
    aws_ssm as ssm,
    aws_stepfunctions as stepfunctions,
)


class ExperimentFoundationLambdaStack(core.Stack):
    def createIAMRole(self, name, service_principal_list):
        composite_principal = iam.CompositePrincipal(
            iam.ServicePrincipal(service_principal_list[0])
        )
        if len(service_principal_list) > 1:
            for service_principal in service_principal_list[1:]:
                composite_principal.add_principals(
                    iam.ServicePrincipal(service_principal)
                )
        role = iam.Role(
            self, name, assumed_by=composite_principal, path=None, role_name=name
        )
        return role

    def createKMSKey(self, name, description):
        key = kms.Key(
            self,
            name,
            description=description,
            pending_window=core.Duration.days(14),
            enable_key_rotation=True,
        )
        return key

    def createExperimentLambdaIAMPolicy(self, random_bucket_suffix):
        experiment_lambda_policy = iam.ManagedPolicy(
            self,
            "experiment_lambda_policy",
            managed_policy_name="experiment_lambda_policy",
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=["ssm:SendCommand"],
                    resources=["*"],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=["lambda:InvokeFunction"],
                    resources=[
                        f"arn:aws:lambda:*:{core.Stack.of(self).account}:function:*",
                    ],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=["s3:GetObject", "s3:Listbucket", "s3:PutObject"],
                    resources=[
                        "arn:aws:s3:::experiment-experiment-bucket"
                        + random_bucket_suffix,
                        "arn:aws:s3:::experiment-experiment-bucket"
                        + random_bucket_suffix
                        + "/*",
                        "arn:aws:s3:::resiliencyvr-package-build-bucket-demo"
                        + random_bucket_suffix,
                        "arn:aws:s3:::resiliencyvr-package-build-bucket-demo"
                        + random_bucket_suffix
                        + "/*",
                    ],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=["ec2:DescribeInstances"],
                    resources=["*"],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "ec2:RunInstances",
                        "ec2:TerminateInstances",
                        "ec2:StopInstances",
                        "ec2:StartInstances",
                    ],
                    resources=["*"],
                ),
            ],
        )

        return experiment_lambda_policy

    def uploadLambdaCode(self, random_bucket_suffix):
        os.system(
            "pip3 install --upgrade -r ./Experiment-Broker-Module/experiment_code/lambda/requirements.txt -t ./Experiment-Broker-Module/experiment_code/lambda"
        )

        def zipdir(path, ziph):
            length = len(path)

            for root, dirs, files in os.walk(path):
                directory = root[length:]
                for file in files:
                    ziph.write(os.path.join(root, file), os.path.join(directory, file))

        with zipfile.ZipFile("experiment_code.zip", "w", zipfile.ZIP_DEFLATED) as zipf:
            zipdir("./Experiment-Broker-Module/experiment_code/lambda/", zipf)

        ZipFile("experiment_code_zipped.zip", mode="w").write("experiment_code.zip")

        lambda_code_bucket = s3.Bucket(
            self,
            "experiment_lambda_code_bucket" + random_bucket_suffix,
            bucket_name="experiment-lambda-code-bucket" + random_bucket_suffix,
            access_control=s3.BucketAccessControl.PRIVATE,
            removal_policy=core.RemovalPolicy.DESTROY,
            auto_delete_objects=True,
        )

        code_upload = s3deploy.BucketDeployment(
            self,
            "LambdaCodeSource",
            sources=[s3deploy.Source.asset("experiment_code_zipped.zip")],
            destination_bucket=lambda_code_bucket,
        )

        return {"lambda_code_bucket": lambda_code_bucket, "code_upload": code_upload}

    def createFunction(self, experiment_lambda_role, lambda_code_bucket, code_upload):
        lambda_function = lambda_.Function(
            self,
            "lambda_function",
            function_name="ExperimentLambdaFunction",
            role=experiment_lambda_role,
            runtime=lambda_.Runtime.PYTHON_3_9,
            handler="handler.handler",
            code=lambda_.Code.from_bucket(
                bucket=lambda_code_bucket, key="experiment_code.zip"
            ),
            memory_size=1024,
            timeout=core.Duration.seconds(60),
            current_version_options=lambda_.VersionOptions(
                code_sha256=str(random.randint(100000, 999999))
            ),
            environment={
                "CodeVersionString": str(time.time()),
            },
        )

        lambda_function.node.add_dependency(code_upload)

        return lambda_function

    def uploadSSMDocument(self):
        for filename in os.listdir("ssm/"):
            f = os.path.join("ssm/", filename)
            # checking if it is a file
            if os.path.isfile(f):
                with open(f) as file:
                    try:
                        ssm_doc = yaml.safe_load(file)
                    except yaml.YAMLError as e:
                        print(e)

                    document_name = filename.split(".")[0]

                    ssm_document = ssm.CfnDocument(
                        self,
                        document_name,
                        name=document_name,
                        content=ssm_doc,
                        document_format="YAML",
                        document_type="Command",
                    )

        return ssm_document

    def uploadExperiments(self, random_bucket_suffix):
        experiment_bucket = s3.Bucket(
            self,
            "experiment-experiment-bucket-" + random_bucket_suffix,
            bucket_name="experiment-experiment-bucket" + random_bucket_suffix,
            access_control=s3.BucketAccessControl.PRIVATE,
            removal_policy=core.RemovalPolicy.DESTROY,
            auto_delete_objects=True,
        )

        experiment_upload = s3deploy.BucketDeployment(
            self,
            "ExperimentFiles",
            sources=[s3deploy.Source.asset("./experiments")],
            destination_bucket=experiment_bucket,
            content_type="application/x-yaml",
        )

        return experiment_bucket, experiment_upload

    def create_step_function(self, experiment_lambda_role):
        with open("./state_machine.json") as f:
            data = json.load(f)
            string_data = json.dumps(data)

            cfn_state_machine = stepfunctions.CfnStateMachine(
                self,
                "state_machine",
                role_arn=experiment_lambda_role.role_arn,
                definition_string=string_data,
                state_machine_name="Experiment_broker",
            )
            return cfn_state_machine

    def __init__(self, scope, id):
        super().__init__(scope, id)
        # try:
        #     random_bucket_suffix = os.getlogin()
        # except:
        #     random_bucket_suffix = str(random.randint(100000, 999999))

        random_bucket_suffix = "alpha"

        s3_key = ExperimentFoundationLambdaStack.createKMSKey(
            self, "s3_key", "Customer managed KMS key to encrypt S3 resources"
        )

        composite_principal = iam.CompositePrincipal(
            iam.ServicePrincipal("lambda.amazonaws.com")
        )
        composite_principal.add_principals(iam.ServicePrincipal("states.amazonaws.com"))
        experiment_lambda_role = iam.Role(
            self,
            "experiment_lambda_role",
            assumed_by=composite_principal,
            path=None,
            role_name="experiment_lambda_role",
        )
        experiment_lambda_policy = (
            ExperimentFoundationLambdaStack.createExperimentLambdaIAMPolicy(
                self, random_bucket_suffix
            )
        )

        experiment_lambda_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name(
                "service-role/AWSLambdaBasicExecutionRole"
            )
        )

        experiment_lambda_policy.attach_to_role(experiment_lambda_role)

        code_upload_resources = ExperimentFoundationLambdaStack.uploadLambdaCode(
            self, random_bucket_suffix
        )
        code_upload = code_upload_resources["code_upload"]
        lambda_code_bucket = code_upload_resources["lambda_code_bucket"]

        experiment_resources = ExperimentFoundationLambdaStack.uploadExperiments(
            self, random_bucket_suffix
        )

        lambda_function = ExperimentFoundationLambdaStack.createFunction(
            self, experiment_lambda_role, lambda_code_bucket, code_upload
        )

        ssm_document = ExperimentFoundationLambdaStack.uploadSSMDocument(self)
        ExperimentFoundationLambdaStack.create_step_function(
            self, experiment_lambda_role
        )

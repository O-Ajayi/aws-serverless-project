import os

import aws_cdk as core

from aws_cdk import (
    aws_iam as iam,
    aws_s3 as s3,
    aws_kms as kms,
    aws_codeartifact as codeartifact,
    aws_codebuild as codebuild,
    aws_codepipeline as codepipeline,
    pipelines as pipelines,
    aws_codepipeline_actions as codepipeline_actions,
    Stack,
    SecretValue,
)

# Import the user database on unix based systems
if os.name == "posix":
    import pwd


class ResiliencyFoundationPipelinesStack(Stack):
    def createCodeArtifactory(self, domain_name, repo_name):
        cfn_domain_permissions_policy = iam.PolicyDocument(
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=["codeartifact:PublishPackageVersion"],
                    principals=[iam.AnyPrincipal()],
                    resources=["*"],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "codeartifact:DescribePackageVersion",
                        "codeartifact:DescribeRepository",
                        "codeartifact:GetPackageVersionReadme",
                        "codeartifact:GetRepositoryEndpoint",
                        "codeartifact:ListPackages",
                        "codeartifact:ListPackageVersions",
                        "codeartifact:ListPackageVersionAssets",
                        "codeartifact:ListPackageVersionDependencies",
                        "codeartifact:ReadFromRepository",
                        "codeartifact:GetAuthorizationToken",
                    ],
                    principals=[iam.AnyPrincipal()],
                    resources=["*"],
                ),
            ]
        )

        encryption_key = kms.Key(
            self, "res-ca-dev-repo-key-demo", description="res-ca-dev repository key"
        )

        cfn_domain_res_ca_devckd = codeartifact.CfnDomain(
            self,
            "MyCfnDomain",
            domain_name=domain_name,
            permissions_policy_document=cfn_domain_permissions_policy,
        )

        cfn_repository_pypistore = codeartifact.CfnRepository(
            self,
            "cfn_repository_pypistore",
            domain_name=cfn_domain_res_ca_devckd.domain_name,
            repository_name="pypi-store",
            external_connections=["public:pypi"],
        )

        cfn_repository_pypistore.add_depends_on(cfn_domain_res_ca_devckd)

        cfn_repository_res_ca_dev = codeartifact.CfnRepository(
            self,
            "cfn_repository_res_ca_dev",
            domain_name=cfn_domain_res_ca_devckd.domain_name,
            repository_name=repo_name,
            upstreams=[cfn_repository_pypistore.repository_name],
        )

        cfn_repository_res_ca_dev.add_depends_on(cfn_domain_res_ca_devckd)
        cfn_repository_res_ca_dev.add_depends_on(cfn_repository_pypistore)

        return {
            "cfn_domain_res_ca_devckd": cfn_domain_res_ca_devckd,
            "cfn_repository_res_ca_dev": cfn_repository_res_ca_dev,
        }

    def createCodePipelineBucket(self, random_bucket_suffix):
        code_pipeline_bucket = s3.Bucket(
            self,
            "code_pipeline_bucket",
            bucket_name="resiliencyvr-package-build-bucket-demo" + random_bucket_suffix,
            access_control=s3.BucketAccessControl.PRIVATE,
            removal_policy=core.RemovalPolicy.DESTROY,
            auto_delete_objects=True,
        )
        return code_pipeline_bucket

    def createCodePipelineIAMPolicy(
        self, codepipeline_bucket, codestar_connections_github_arn
    ):
        codepipeline_policy = iam.ManagedPolicy(
            self,
            "codepipeline_policy",
            managed_policy_name="codepipeline_policy",
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "s3:GetObject",
                        "s3:GetObjectVersion",
                        "s3:GetBucketVersioning",
                        "s3:PutObjectAcl",
                        "s3:PutObject",
                    ],
                    resources=[
                        codepipeline_bucket.bucket_arn,
                        codepipeline_bucket.bucket_arn + "/*",
                    ],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=["codestar-connections:UseConnection"],
                    resources=[codestar_connections_github_arn],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "codebuild:BatchGetBuilds",
                        "codebuild:StartBuild",
                    ],
                    resources=[
                        f"arn:aws:codebuild:{core.Stack.of(self).region}:{core.Stack.of(self).account}:project/resiliencyvr-package-codebuild-demo"
                    ],
                ),
            ],
        )

        return codepipeline_policy

    def createCodeBuildPackageIAMPolicy(
        self,
        codeartifact_repository_res_ca_dev_arn,
        codeartifact_domain_res_ca_dev_domain_arn,
        codepipeline_bucket,
    ):
        resiliencyvr_codebuild_package_policy_demo = iam.ManagedPolicy(
            self,
            "resiliencyvr_codebuild_package_policy_demo",
            managed_policy_name="resiliencyvr_codebuild_package_policy_demo",
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents",
                    ],
                    resources=["*"],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "codeartifact:GetAuthorizationToken",
                        "codeartifact:GetRepositoryEndpoint",
                    ],
                    resources=[
                        codeartifact_repository_res_ca_dev_arn,
                        codeartifact_domain_res_ca_dev_domain_arn + "/*",
                        codeartifact_domain_res_ca_dev_domain_arn,
                    ],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=["sts:GetServiceBearerToken"],
                    resources=["*"],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "s3:GetObject",
                        "s3:GetObjectVersion",
                        "s3:GetBucketVersioning",
                        "s3:PutObjectAcl",
                        "s3:PutObject",
                    ],
                    resources=[
                        codepipeline_bucket.bucket_arn,
                        codepipeline_bucket.bucket_arn + "/*",
                    ],
                ),
            ],
        )

        return resiliencyvr_codebuild_package_policy_demo

    def createCodeBuildLambdaIAMPolicy(
        self,
        codeartifact_repository_res_ca_dev_arn,
        codeartifact_domain_res_ca_dev_domain_arn,
        codepipeline_bucket,
    ):
        resiliencyvr_codebuild_lambda_policy_demo = iam.ManagedPolicy(
            self,
            "resiliencyvr_codebuild_lambda_policy_demo",
            managed_policy_name="resiliencyvr_codebuild_lambda_policy_demo",
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents",
                        "cloudformation:DescribeStacks",
                        "sts:GetServiceBearerToken",
                        "ssm:GetParameter",
                        "codepipeline:GetPipeline",
                        "codepipeline:GetPipelineState",
                    ],
                    resources=["*"],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "codeartifact:GetAuthorizationToken",
                        "codeartifact:GetRepositoryEndpoint",
                    ],
                    resources=[
                        codeartifact_repository_res_ca_dev_arn,
                        codeartifact_domain_res_ca_dev_domain_arn + "/*",
                        codeartifact_domain_res_ca_dev_domain_arn,
                    ],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "s3:GetObject",
                        "s3:GetObjectVersion",
                        "s3:GetBucketVersioning",
                        "s3:PutObjectAcl",
                        "s3:PutObject",
                    ],
                    resources=[
                        codepipeline_bucket.bucket_arn,
                        codepipeline_bucket.bucket_arn + "/*",
                    ],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=["sts:AssumeRole", "iam:PassRole"],
                    resources=[
                        f"arn:aws:iam::{core.Stack.of(self).account}:role/cdk-readOnlyRole",
                        f"arn:aws:iam::{core.Stack.of(self).account}:role/cdk-*-deploy-role-*",
                        f"arn:aws:iam::{core.Stack.of(self).account}:role/cdk-*-file-publishing-*",
                    ],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "lambda:ListAliases",
                        "lambda:ListCodeSigningConfigs",
                        "lambda:ListEventSourceMappings",
                        "lambda:ListFunctionEventInvokeConfigs",
                        "lambda:ListFunctions",
                        "lambda:ListFunctionsByCodeSigningConfig",
                        "lambda:ListFunctionUrlConfigs",
                        "lambda:ListLayers",
                        "lambda:ListLayerVersions",
                        "lambda:ListProvisionedConcurrencyConfigs",
                        "lambda:ListTags",
                    ],
                    resources=["*"],
                ),
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "lambda:CreateFunction",
                        "lambda:GetFunction",
                        "lambda:GetFunctionCodeSigningConfig",
                        "lambda:GetCodeSigningConfig",
                        "lambda:DeleteFunction",
                    ],
                    resources=[
                        f"arn:aws:lambda:{core.Stack.of(self).region}:{core.Stack.of(self).account}:function:ExperimentLambdaFunction"
                    ],
                ),
            ],
        )

        return resiliencyvr_codebuild_lambda_policy_demo

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

    def createResiliencyVRCodeBuildPipelineProject(
        self,
        codebuild_package_role,
        codepipeline_bucket,
        domain_name,
        owner,
        repo_name,
        user_name,
        github_token,
    ):
        resiliencyvr_project = codebuild.PipelineProject(
            self,
            "resiliencyvr_codebuild_project_demo",
            project_name="resiliencyvr-package-codebuild-demo",
            description="Builds the resiliencyvr package",
            role=codebuild_package_role,
            timeout=core.Duration.minutes(5),
            environment=codebuild.BuildEnvironment(
                compute_type=codebuild.ComputeType.SMALL,
                build_image=codebuild.LinuxBuildImage.STANDARD_5_0,
                environment_variables={
                    "DOMAIN_NAME": codebuild.BuildEnvironmentVariable(
                        value=domain_name
                    ),
                    "OWNER": codebuild.BuildEnvironmentVariable(value=owner),
                    "REPO_NAME": codebuild.BuildEnvironmentVariable(value=repo_name),
                    "USER_NAME": codebuild.BuildEnvironmentVariable(value=user_name)
                    # "GITHUB_TOKEN": codebuild.BuildEnvironmentVariable(value=github_token)
                },
            ),
            logging=codebuild.LoggingOptions(
                s3=codebuild.S3LoggingOptions(
                    bucket=codepipeline_bucket, prefix="build-log"
                )
            ),
            build_spec=codebuild.BuildSpec.from_source_filename(
                "pipeline_infra/buildspec-resiliencyvr.yml"
            ),
        )
        return resiliencyvr_project

    def createLambdaCodeBuildPipelineProject(
        self,
        codebuild_lambda_role,
        domain_name,
        owner,
        repo_name,
        user_name,
        github_token,
    ):
        lambda_deploy_project = codebuild.PipelineProject(
            self,
            "cdk_deploy_demo",
            role=codebuild_lambda_role,
            build_spec=codebuild.BuildSpec.from_object(
                {
                    "version": "0.2",
                    "phases": {
                        "build": {
                            "commands": [
                                "aws codeartifact login --tool pip --domain $DOMAIN_NAME --domain-owner $OWNER --repository $REPO_NAME",
                                "npm install -g aws-cdk",  # Installs the cdk cli on Codebuild
                                "pip install -r lambda_infra/requirements.txt",  # Instructs Codebuild to install required packages
                                "pip install aws-cdk-lib",
                                "cdk --version",
                                "pwd ",
                                "ls -all",
                                "cd lambda_infra",
                                "npx cdk deploy",
                            ]
                        }
                    },
                }
            ),
            environment=codebuild.BuildEnvironment(
                compute_type=codebuild.ComputeType.SMALL,
                build_image=codebuild.LinuxBuildImage.STANDARD_5_0,
                environment_variables={
                    "DOMAIN_NAME": codebuild.BuildEnvironmentVariable(
                        value=domain_name
                    ),
                    "OWNER": codebuild.BuildEnvironmentVariable(value=owner),
                    "REPO_NAME": codebuild.BuildEnvironmentVariable(value=repo_name),
                    "USER_NAME": codebuild.BuildEnvironmentVariable(value=user_name),
                    # "GITHUB_TOKEN": codebuild.BuildEnvironmentVariable(value=github_token)
                },
            ),
        )
        return lambda_deploy_project

    def createResiliencyVRPipeline(self, resiliencyvr_codebuild_pipeline_project):
        resiliencyvr_pipeline = codepipeline.Pipeline(
            self, "resiliencyvr_pipeline_demo"
        )

        source_output = codepipeline.Artifact(artifact_name="source_output")
        source_action = codepipeline_actions.GitHubSourceAction(
            action_name="Github_Source",
            output=source_output,
            # owner="VerticalRelevance",
            owner="mhiggins-vr",
            repo="Experiment-pipeline",
            branch="master",
            oauth_token=SecretValue.secrets_manager(
                "github/personal/mhiggins", json_field="my-github-token"
            ),
            run_order=1,
        )
        source_stage = resiliencyvr_pipeline.add_stage(stage_name="Source")
        source_stage.add_action(source_action)

        build_action = codepipeline_actions.CodeBuildAction(
            action_name="Build",
            type=codepipeline_actions.CodeBuildActionType.BUILD,
            project=resiliencyvr_codebuild_pipeline_project,
            input=source_output,
            run_order=2,
        )
        build_stage = resiliencyvr_pipeline.add_stage(stage_name="Build")
        build_stage.add_action(build_action)

    def createLambdaPipeline(self, lambda_deploy_project):
        lambda_pipeline = codepipeline.Pipeline(self, "lambda_pipeline")

        source_output = codepipeline.Artifact(artifact_name="source_output")
        source_action = codepipeline_actions.GitHubSourceAction(
            action_name="Github_Source",
            output=source_output,
            # owner="VerticalRelevance",
            owner="mhiggins-vr",
            repo="Experiment-pipeline",
            branch="master",
            oauth_token=SecretValue.secrets_manager(
                "github/personal/mhiggins", json_field="my-github-token"
            ),
            run_order=1,
        )
        source_stage = lambda_pipeline.add_stage(stage_name="Source")
        source_stage.add_action(source_action)

        deploy_action = codepipeline_actions.CodeBuildAction(
            action_name="Deploy",
            type=codepipeline_actions.CodeBuildActionType.BUILD,
            project=lambda_deploy_project,
            input=source_output,
            run_order=2,
        )
        deploy_stage = lambda_pipeline.add_stage(stage_name="Deploy")
        deploy_stage.add_action(deploy_action)

    def __init__(self, scope, id):
        super().__init__(scope, id)

        domain_name = "res-ca-devckd"
        owner = self.account
        repo_name = "res-ca-dev"
        user_name = "mhiggins-vr"
        github_token = None
        # github_token = SecretValue.secrets_manager(
        #     "github/personal/mhiggins", json_field="my-github-token"
        # )

        # if os.name == "posix":
        #     random_bucket_suffix = pwd.getpwuid(os.geteuid()).pw_name
        # else:
        #     random_bucket_suffix = os.getlogin()

        random_bucket_suffix = "alpha"

        codepipeline_role = ResiliencyFoundationPipelinesStack.createIAMRole(
            self,
            "resiliencyvr-package-build-pipeline-role-demo",
            ["codepipeline.amazonaws.com", "codebuild.amazonaws.com"],
        )
        codebuild_package_role = ResiliencyFoundationPipelinesStack.createIAMRole(
            self,
            "resiliencyvr_codebuild_package_role-demo",
            ["codebuild.amazonaws.com"],
        )
        codebuild_lambda_role = ResiliencyFoundationPipelinesStack.createIAMRole(
            self,
            "resiliencyvr_codebuild_lambda_role-demo",
            ["codebuild.amazonaws.com"],
        )

        codeartifact_resources = (
            ResiliencyFoundationPipelinesStack.createCodeArtifactory(
                self, domain_name, repo_name
            )
        )
        cfn_domain_res_ca_devckd = codeartifact_resources["cfn_domain_res_ca_devckd"]
        cfn_repository_res_ca_dev = codeartifact_resources["cfn_repository_res_ca_dev"]

        codepipeline_bucket = (
            ResiliencyFoundationPipelinesStack.createCodePipelineBucket(
                self, random_bucket_suffix
            )
        )
        codestar_connections_github_arn = (
            "arn:aws:codestar-connections:region:account-id:connection/connection-id"
        )
        codeartifact_domain_res_ca_dev_domain_arn = cfn_domain_res_ca_devckd.attr_arn
        codeartifact_repository_res_ca_dev_arn = cfn_repository_res_ca_dev.attr_arn

        codepipeline_policy = (
            ResiliencyFoundationPipelinesStack.createCodePipelineIAMPolicy(
                self, codepipeline_bucket, codestar_connections_github_arn
            )
        )
        codepipeline_policy.attach_to_role(codepipeline_role)

        codebuild_package_policy = (
            ResiliencyFoundationPipelinesStack.createCodeBuildPackageIAMPolicy(
                self,
                codeartifact_repository_res_ca_dev_arn,
                codeartifact_domain_res_ca_dev_domain_arn,
                codepipeline_bucket,
            )
        )
        codebuild_package_policy.attach_to_role(codebuild_package_role)

        codebuild_lambda_policy = (
            ResiliencyFoundationPipelinesStack.createCodeBuildLambdaIAMPolicy(
                self,
                codeartifact_repository_res_ca_dev_arn,
                codeartifact_domain_res_ca_dev_domain_arn,
                codepipeline_bucket,
            )
        )
        codebuild_lambda_policy.attach_to_role(codebuild_lambda_role)

        resiliencyvr_codebuild_pipeline_project = ResiliencyFoundationPipelinesStack.createResiliencyVRCodeBuildPipelineProject(
            self,
            codebuild_package_role,
            codepipeline_bucket,
            domain_name,
            owner,
            repo_name,
            user_name,
            github_token,
        )
        lambda_codebuild_pipeline_project = (
            ResiliencyFoundationPipelinesStack.createLambdaCodeBuildPipelineProject(
                self,
                codebuild_lambda_role,
                domain_name,
                owner,
                repo_name,
                user_name,
                github_token,
            )
        )
        ResiliencyFoundationPipelinesStack.createResiliencyVRPipeline(
            self, resiliencyvr_codebuild_pipeline_project
        )
        ResiliencyFoundationPipelinesStack.createLambdaPipeline(
            self, lambda_codebuild_pipeline_project
        )

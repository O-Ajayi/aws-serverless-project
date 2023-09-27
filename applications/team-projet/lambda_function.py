import boto3

app_id = "ENTER YOUR APP ID"
branch_name = "ENTER YOUR BRANCH NAME"

amplify = boto3.client("amplify")

def lambda_handler(event, context):
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    object_key = event["Records"][0]["s3"]["object"]["key"]
    
    amplify.start_deployment(
        appId=app_id,
        branchName=branch_name,
        sourceUrl=f"s3://{bucket}/{object_key}"
    )
    
    print("This is Richard")
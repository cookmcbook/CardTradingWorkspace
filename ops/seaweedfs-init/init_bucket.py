import os
import time

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

endpoint = os.environ["S3_ENDPOINT"]
bucket = os.environ["S3_BUCKET"]
client = boto3.client(
    "s3",
    endpoint_url=endpoint,
    region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
    config=Config(s3={"addressing_style": "path"}),
)

for attempt in range(60):
    try:
        try:
            client.head_bucket(Bucket=bucket)
            print("S3 bucket is ready.", flush=True)
        except ClientError as error:
            status = error.response.get("ResponseMetadata", {}).get("HTTPStatusCode")
            if status != 404:
                raise
            client.create_bucket(Bucket=bucket)
            print("Created S3 bucket.", flush=True)
        break
    except BotoCoreError:
        if attempt == 59:
            raise RuntimeError("SeaweedFS S3 endpoint did not become ready.")
        time.sleep(2)

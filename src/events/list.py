import json
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("Events")


def handler(event, context):
    result = table.scan()
    return {"statusCode": 200, "body": json.dumps(result["Items"])}

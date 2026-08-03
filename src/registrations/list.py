import json
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("Registrations")


def handler(event, context):
    event_id = event.get("pathParameters", {}).get("eventId")
    if not event_id:
        return {"statusCode": 400, "body": json.dumps({"error": "Missing eventId"})}

    result = table.query(
        IndexName="eventId-index",
        KeyConditionExpression=Key("eventId").eq(event_id)
    )

    return {"statusCode": 200, "body": json.dumps(result["Items"])}

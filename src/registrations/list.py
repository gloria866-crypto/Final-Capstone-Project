import json
import boto3
from decimal import Decimal
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("Registrations")


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def handler(event, context):
    event_id = event.get("pathParameters", {}).get("eventId")
    if not event_id:
        return {"statusCode": 400, "body": json.dumps({"error": "Missing eventId"})}

    result = table.query(
        IndexName="eventId-index",
        KeyConditionExpression=Key("eventId").eq(event_id)
    )

    return {"statusCode": 200, "body": json.dumps(result["Items"], cls=DecimalEncoder)}

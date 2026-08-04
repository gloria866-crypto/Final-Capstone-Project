import json
import boto3
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("Events")


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def handler(event, context):
    event_id = event.get("pathParameters", {}).get("eventId")
    if not event_id:
        return {"statusCode": 400, "body": json.dumps({"error": "Missing eventId"})}

    result = table.get_item(Key={"eventId": event_id})
    item = result.get("Item")

    if not item:
        return {"statusCode": 404, "body": json.dumps({"error": "Event not found"})}

    return {"statusCode": 200, "body": json.dumps(item, cls=DecimalEncoder)}

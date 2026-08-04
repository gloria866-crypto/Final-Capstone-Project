import json
import boto3
import uuid
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("Events")


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)

REQUIRED_FIELDS = ["name", "date", "location", "capacity"]


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": json.dumps({"error": "Invalid JSON"})}

    missing = [f for f in REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return {"statusCode": 400, "body": json.dumps({"error": f"Missing required fields: {', '.join(missing)}"})}

    if not isinstance(body["capacity"], int) or body["capacity"] <= 0:
        return {"statusCode": 400, "body": json.dumps({"error": "capacity must be a positive integer"})}

    item = {
        "eventId": str(uuid.uuid4()),
        "name": body["name"],
        "date": body["date"],
        "location": body["location"],
        "capacity": body["capacity"],
        "ticketsSold": 0,
        "createdAt": datetime.utcnow().isoformat(),
    }

    table.put_item(Item=item)
    return {"statusCode": 201, "body": json.dumps(item, cls=DecimalEncoder)}

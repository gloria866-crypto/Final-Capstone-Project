import json
import boto3
import uuid
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("events")


def handler(event, context):
    body = json.loads(event["body"])
    item = {
        "eventId": str(uuid.uuid4()),
        "name": body["name"],
        "date": body["date"],
        "capacity": body["capacity"],
        "createdAt": datetime.utcnow().isoformat(),
    }
    table.put_item(Item=item)
    return {"statusCode": 201, "body": json.dumps(item)}

import json
import boto3
import uuid
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("registrations")


def handler(event, context):
    body = json.loads(event["body"])
    item = {
        "registrationId": str(uuid.uuid4()),
        "eventId": body["eventId"],
        "attendeeName": body["attendeeName"],
        "attendeeEmail": body["attendeeEmail"],
        "createdAt": datetime.utcnow().isoformat(),
    }
    table.put_item(Item=item)
    return {"statusCode": 201, "body": json.dumps(item)}

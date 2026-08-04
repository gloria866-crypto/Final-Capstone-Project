import json
import boto3
import uuid
from datetime import datetime
from decimal import Decimal
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
events_table = dynamodb.Table("Events")
registrations_table = dynamodb.Table("Registrations")


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)

REQUIRED_FIELDS = ["eventId", "attendeeName", "attendeeEmail"]


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": json.dumps({"error": "Invalid JSON"})}

    missing = [f for f in REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return {"statusCode": 400, "body": json.dumps({"error": f"Missing required fields: {', '.join(missing)}"})}

    result = events_table.get_item(Key={"eventId": body["eventId"]})
    event_item = result.get("Item")
    if not event_item:
        return {"statusCode": 404, "body": json.dumps({"error": "Event not found"})}

    if event_item["ticketsSold"] >= event_item["capacity"]:
        return {"statusCode": 409, "body": json.dumps({"error": "Event is fully booked"})}

    try:
        events_table.update_item(
            Key={"eventId": body["eventId"]},
            UpdateExpression="SET ticketsSold = ticketsSold + :inc",
            ConditionExpression="ticketsSold < #cap",
            ExpressionAttributeNames={"#cap": "capacity"},
            ExpressionAttributeValues={":inc": 1},
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return {"statusCode": 409, "body": json.dumps({"error": "Event is fully booked"})}
        raise

    item = {
        "registrationId": str(uuid.uuid4()),
        "eventId": body["eventId"],
        "attendeeName": body["attendeeName"],
        "attendeeEmail": body["attendeeEmail"],
        "createdAt": datetime.utcnow().isoformat(),
    }
    registrations_table.put_item(Item=item)

    return {"statusCode": 201, "body": json.dumps(item, cls=DecimalEncoder)}

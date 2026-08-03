import json
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("Events")


def handler(event, context):
    event_id = event.get("pathParameters", {}).get("eventId")
    if not event_id:
        return {"statusCode": 400, "body": json.dumps({"error": "Missing eventId"})}

    result = table.get_item(Key={"eventId": event_id})
    item = result.get("Item")

    if not item:
        return {"statusCode": 404, "body": json.dumps({"error": "Event not found"})}

    return {"statusCode": 200, "body": json.dumps(item)}

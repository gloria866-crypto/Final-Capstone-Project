import json
import boto3

dynamodb = boto3.resource("dynamodb")
registrations_table = dynamodb.Table("Registrations")
events_table = dynamodb.Table("Events")


def handler(event, context):
    registration_id = event.get("pathParameters", {}).get("id")
    if not registration_id:
        return {"statusCode": 400, "body": json.dumps({"error": "Missing registration id"})}

    result = registrations_table.get_item(Key={"registrationId": registration_id})
    item = result.get("Item")
    if not item:
        return {"statusCode": 404, "body": json.dumps({"error": "Registration not found"})}

    registrations_table.delete_item(Key={"registrationId": registration_id})

    events_table.update_item(
        Key={"eventId": item["eventId"]},
        UpdateExpression="SET ticketsSold = ticketsSold - :dec",
        ConditionExpression="ticketsSold > :zero",
        ExpressionAttributeValues={":dec": 1, ":zero": 0},
    )

    return {"statusCode": 200, "body": json.dumps({"message": "Registration cancelled"})}

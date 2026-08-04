terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_dynamodb_table" "events" {
  name         = "Events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "eventId"

  attribute {
    name = "eventId"
    type = "S"
  }
}

# IAM role shared by all Lambda functions
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "attach_create_event" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.create_event.arn
}

resource "aws_iam_role_policy_attachment" "attach_list_events" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.list_events.arn
}

resource "aws_iam_role_policy_attachment" "attach_get_event" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.get_event.arn
}

resource "aws_iam_role_policy_attachment" "attach_register_attendee" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.register_attendee.arn
}

resource "aws_iam_role_policy_attachment" "attach_list_registrations" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.list_registrations.arn
}

# createEvent — needs PutItem on Events
resource "aws_iam_policy" "create_event" {
  name = "create_event_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "dynamodb:PutItem"
      Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/Events"
    }]
  })
}

# listEvents — needs Scan on Events
resource "aws_iam_policy" "list_events" {
  name = "list_events_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "dynamodb:Scan"
      Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/Events"
    }]
  })
}

# getEvent — needs GetItem on Events
resource "aws_iam_policy" "get_event" {
  name = "get_event_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "dynamodb:GetItem"
      Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/Events"
    }]
  })
}

# registerAttendee — needs GetItem + UpdateItem on Events, PutItem on Registrations
resource "aws_iam_policy" "register_attendee" {
  name = "register_attendee_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/Events"
      },
      {
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/Registrations"
      }
    ]
  })
}

# listRegistrations — needs Query on Registrations table and its GSI
resource "aws_iam_policy" "list_registrations" {
  name = "list_registrations_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "dynamodb:Query"
      Resource = [
        "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/Registrations",
        "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/Registrations/index/eventId-index"
      ]
    }]
  })
}

# Lambda functions
data "archive_file" "create_event" {
  type        = "zip"
  source_file = "${path.module}/../src/events/create.py"
  output_path = "${path.module}/zips/create_event.zip"
}

data "archive_file" "list_events" {
  type        = "zip"
  source_file = "${path.module}/../src/events/list.py"
  output_path = "${path.module}/zips/list_events.zip"
}

data "archive_file" "get_event" {
  type        = "zip"
  source_file = "${path.module}/../src/events/get.py"
  output_path = "${path.module}/zips/get_event.zip"
}

data "archive_file" "register_attendee" {
  type        = "zip"
  source_file = "${path.module}/../src/registrations/create.py"
  output_path = "${path.module}/zips/register_attendee.zip"
}

data "archive_file" "list_registrations" {
  type        = "zip"
  source_file = "${path.module}/../src/registrations/list.py"
  output_path = "${path.module}/zips/list_registrations.zip"
}

resource "aws_lambda_function" "create_event" {
  function_name    = "createEvent"
  filename         = data.archive_file.create_event.output_path
  source_code_hash = data.archive_file.create_event.output_base64sha256
  handler          = "create.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "list_events" {
  function_name    = "listEvents"
  filename         = data.archive_file.list_events.output_path
  source_code_hash = data.archive_file.list_events.output_base64sha256
  handler          = "list.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "get_event" {
  function_name    = "getEvent"
  filename         = data.archive_file.get_event.output_path
  source_code_hash = data.archive_file.get_event.output_base64sha256
  handler          = "get.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "register_attendee" {
  function_name    = "registerAttendee"
  filename         = data.archive_file.register_attendee.output_path
  source_code_hash = data.archive_file.register_attendee.output_base64sha256
  handler          = "create.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "list_registrations" {
  function_name    = "listRegistrations"
  filename         = data.archive_file.list_registrations.output_path
  source_code_hash = data.archive_file.list_registrations.output_base64sha256
  handler          = "list.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
}

resource "aws_dynamodb_table" "registrations" {
  name         = "Registrations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "registrationId"

  attribute {
    name = "registrationId"
    type = "S"
  }

  attribute {
    name = "eventId"
    type = "S"
  }

  global_secondary_index {
    name            = "eventId-index"
    hash_key        = "eventId"
    projection_type = "ALL"
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "EventsAPI"
}

# /events
resource "aws_api_gateway_resource" "events" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "events"
}

# /events/{id}
resource "aws_api_gateway_resource" "event_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.events.id
  path_part   = "{eventId}"
}

# /events/{id}/register
resource "aws_api_gateway_resource" "register" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.event_id.id
  path_part   = "register"
}

# /events/{id}/registrations
resource "aws_api_gateway_resource" "registrations" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.event_id.id
  path_part   = "registrations"
}

locals {
  routes = {
    post_events       = { method = "POST", resource_id = aws_api_gateway_resource.events.id, lambda = aws_lambda_function.create_event }
    get_events        = { method = "GET", resource_id = aws_api_gateway_resource.events.id, lambda = aws_lambda_function.list_events }
    get_event         = { method = "GET", resource_id = aws_api_gateway_resource.event_id.id, lambda = aws_lambda_function.get_event }
    post_register     = { method = "POST", resource_id = aws_api_gateway_resource.register.id, lambda = aws_lambda_function.register_attendee }
    get_registrations = { method = "GET", resource_id = aws_api_gateway_resource.registrations.id, lambda = aws_lambda_function.list_registrations }
  }
}

resource "aws_api_gateway_method" "methods" {
  for_each      = local.routes
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = each.value.resource_id
  http_method   = each.value.method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integrations" {
  for_each                = local.routes
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = each.value.resource_id
  http_method             = each.value.method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.lambda.invoke_arn
  depends_on              = [aws_api_gateway_method.methods]
}

resource "aws_lambda_permission" "apigw" {
  for_each      = local.routes
  statement_id  = "AllowAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on  = [aws_api_gateway_integration.integrations]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.events,
      aws_api_gateway_resource.event_id,
      aws_api_gateway_resource.register,
      aws_api_gateway_resource.registrations,
      aws_api_gateway_method.methods,
      aws_api_gateway_integration.integrations,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = "prod"
}

output "api_url" {
  value = aws_api_gateway_stage.stage.invoke_url
}

# SNS topic for CloudWatch alarm notifications
resource "aws_sns_topic" "alarms" {
  name = "cloudwatch-alarms-topic"
}

resource "aws_sns_topic_subscription" "alarms_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = "yaaappaih2@gmail.com"
}

# CloudWatch alarms
locals {
  lambda_functions = {
    create_event       = aws_lambda_function.create_event.function_name
    list_events        = aws_lambda_function.list_events.function_name
    get_event          = aws_lambda_function.get_event.function_name
    register_attendee  = aws_lambda_function.register_attendee.function_name
    list_registrations = aws_lambda_function.list_registrations.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each            = local.lambda_functions
  alarm_name          = "${each.value}-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = each.value }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  alarm_name          = "apigw-5xx-errors"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  dimensions = {
    ApiName  = aws_api_gateway_rest_api.api.name
    Stage    = aws_api_gateway_stage.stage.stage_name
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

resource "aws_budgets_budget" "monthly" {
  name         = "monthly-budget"
  budget_type  = "COST"
  limit_amount = "5"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["yaaappaih2@gmail.com"]
  }
}

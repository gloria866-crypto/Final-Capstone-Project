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

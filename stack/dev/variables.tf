variable "app" { type = string }

variable "env" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = null
}

locals {
  # Acá se definen los nombres de los recursos
  name_prefix = "${var.app}-${var.env}-${terraform.workspace}"

  table_name  = "${local.name_prefix}-items"
  lambda_name = "${local.name_prefix}-writer"

  tags = {
    app = var.app
    env = var.env
    ws  = terraform.workspace
  }
}

variable "telegram_token_secret_arn" {
  type        = string
  sensitive   = true
  description = "ARN of the Secrets Manager secret with the Telegram bot token"
}

variable "telegram_default_chat_id" {
  type        = string
  description = "Optional default chat id for CLI tests"
  default     = "6656805658"
}
variable "app" { type = string }

variable "env" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "sa-east-1"
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

variable "telegram_token_param_name" {
  type        = string
  sensitive   = true
  description = "SSM SecureString parameter name for the Telegram bot token (e.g., /telegram/bot-token)"
}

variable "telegram_default_chat_id" {
  type        = string
  description = "Optional default chat id for CLI tests"
}
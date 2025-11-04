variable "name" {
  type = string
}

variable "aws_region" { type = string }

data "aws_caller_identity" "current" {}

variable "runtime" {
  type    = string
  default = "nodejs20.x"
}

variable "handler" {
  type    = string
  default = "index.handler"
}

variable "source_dir" {
  type = string
} # e.g., "../../../app/lambdas/writer"

variable "table_name" {
  type = string
}

variable "table_arn" {
  type = string
}

variable "telegram_token_param_name" {
  type        = string
  sensitive   = true
  description = "SSM SecureString parameter name for the Telegram bot token (e.g., /telegram/bot-token)"
}

variable "telegram_default_chat_id" {
  type        = string
  description = "Optional chat id used when invoking from CLI"
  default     = "6656805658"
}
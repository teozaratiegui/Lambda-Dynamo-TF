variable "name" {
  type = string
}

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

variable "telegram_token_secret_arn" {
  type        = string
  sensitive   = true
  description = "Secrets Manager ARN for the Telegram bot token"
}

variable "telegram_default_chat_id" {
  type        = string
  description = "Optional chat id used when invoking from CLI"
  default     = "6656805658"
}
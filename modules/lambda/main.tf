# Rol que asume la Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Indica que la Lambda puede asumir este rol
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


# Mínimos permisos para que la lambda pueda escribir en la tabla DynamoDB y loguear en CloudWatch
data "aws_iam_policy_document" "inline" {
  statement {
    actions   = ["dynamodb:UpdateItem", "dynamodb:PutItem"]
    resources = [var.table_arn]
  }
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  # Permiso para leer el secreto del token de Telegram
  statement {
    sid       = "ReadTelegramTokenFromSSM"
    actions   = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.telegram_token_param_name}"
    ]
  }

}

# Asociamos la política inline al rol de la lambda
resource "aws_iam_role_policy" "inline" {
  name   = "${var.name}-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.inline.json
}


# Empaquetamos el código fuente de la Lambda en un archivo .zip
data "archive_file" "zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/${var.name}.zip"
}


resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = aws_iam_role.lambda_role.arn
  handler       = var.handler
  runtime       = var.runtime
  filename      = data.archive_file.zip.output_path
  timeout = 10

  # Agrego esto para  forzar la actualización cuando cambie el código fuente
  source_code_hash = data.archive_file.zip.output_base64sha256

  # Paso el nombre de la tabla DynamoDB como variable de entorno
  environment {
    variables = {
      TABLE_NAME                = var.table_name
      TELEGRAM_TOKEN_PARAM      = var.telegram_token_param_name   # <-- rename key here
      TELEGRAM_DEFAULT_CHAT_ID  = var.telegram_default_chat_id
    }
  }

  publish = true # Publica una nueva versión cada vez que cambia el código, favorece rollbacks y aliases
}


# Opcional: Permite que la Lambda sea invocada desde la consola de AWS
resource "aws_lambda_permission" "allow_console" {
  statement_id  = "AllowExecutionFromConsole"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "*"
}

# Grupo de logs en CloudWatch para la Lambda, evitamos que se apilen indefinidamente
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 14
}

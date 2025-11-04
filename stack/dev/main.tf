module "ddb" {
  source       = "../../modules/dynamodb"
  table_name   = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  pitr         = true
  tags         = local.tags
}


module "writer" {
  source     = "../../modules/lambda"
  name       = local.lambda_name
  source_dir = "../../app-test/lambdas/writer"


  # Lambda config
  runtime = "nodejs20.x"
  handler = "index.handler"


  # Wire to DynamoDB
  table_name = module.ddb.table_name
  table_arn  = module.ddb.table_arn

  telegram_token_secret_arn = var.telegram_token_secret_arn # from tfvars or env
  telegram_default_chat_id  = var.telegram_default_chat_id  # optional
}
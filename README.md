# Terraform AWS Lambda + DynamoDB + Telegram Bot

This repository contains Terraform configuration to deploy an AWS Lambda function that writes to a DynamoDB table and sends notifications via a Telegram bot.  
It’s organized for clarity and modular reuse.

---

# Requirements

- Terraform ≥ 1.5 and AWS CLI installed
- Logged in to an AWS account with permissions for **Lambda, IAM, DynamoDB, Secrets Manager**
- Create your Telegram bot token in aws SSM parameter store:
  ```bash
  aws ssm put-parameter --name "/telegram/bot-token" --type "SecureString"  --value "<YOUR_TELEGRAM_BOT_TOKEN>"  --region sa-east-1

- Have your telegram chat id

---

# Deployment (from /stack/dev)

## Workspace
terraform workspace new <workspace_name>

## Initialize Terraform (first time only)
terraform init

## Plan
terraform plan

## Apply with environment variables (PowerShell)

- $env:TF_VAR_telegram_token_param_name = "<telegram_token_param_name>"
- $env:TF_VAR_telegram_default_chat_id  = "<telegram_chat>"
- terraform apply

# Test

- Get the lambda arn: aws lambda get-function --function-name demo-autoinc-dev-<workspace_name>-writer --query 'Configuration.FunctionArn'  --output text

- Save the json message: '{"text":"Prueba pasar token a parameter store y no secrets"}' | Out-File -FilePath payload.json -Encoding ascii -NoNewline

- Store the lambda arn:  $Fn = "<lambda_arn>"

- Executing the Lambda: aws lambda invoke --function-name $Fn --payload fileb://payload.json --cli-binary-format raw-in-base64-out outputfile.txt

- Check for logs: aws logs tail /aws/lambda/<lambda_name> --since 1h --follow --region sa-east-1

# Cleanup

terraform destroy



// index.js — CommonJS syntax for Node.js 20.x in Lambda
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, UpdateCommand, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

// DynamoDB
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));

// Secrets Manager
const sm = new SecretsManagerClient({});
const SECRET_ARN = process.env.TELEGRAM_TOKEN_SECRET_ARN; // ← set in Terraform (ARN, not the token)
let TELEGRAM_TOKEN_CACHE = null;

async function getTelegramToken() {
  if (TELEGRAM_TOKEN_CACHE) return TELEGRAM_TOKEN_CACHE;
  if (!SECRET_ARN) throw new Error("Missing TELEGRAM_TOKEN_SECRET_ARN env var");

  const res = await sm.send(new GetSecretValueCommand({ SecretId: SECRET_ARN }));
  let token = res.SecretString;

  // Handle case where the secret was stored as JSON: { "token": "xxxx" }
  try {
    const maybeJson = JSON.parse(token);
    if (maybeJson && typeof maybeJson === "object" && maybeJson.token) {
      token = maybeJson.token;
    }
  } catch { /* plain string, ignore */ }

  if (!token) throw new Error("Telegram token secret is empty or invalid");
  TELEGRAM_TOKEN_CACHE = token; // memoize for this execution environment
  return token;
}

// Env
const TABLE_NAME = process.env.TABLE_NAME;
const DEFAULT_CHAT_ID = process.env.TELEGRAM_DEFAULT_CHAT_ID || ""; // optional fallback for CLI

async function sendTelegramMessage(chatId, message) {
  if (!chatId) throw new Error("Missing chatId to send Telegram message");
  const TELEGRAM_TOKEN = await getTelegramToken();

  const url = `https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ chat_id: String(chatId), text: message }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Telegram send failed: ${res.status} ${res.statusText} ${body}`);
  }
}

// Parse event in both modes: CLI or API Gateway/Lambda URL (Telegram webhook)
function parseEvent(event) {
  // If event is a string, try to JSON.parse it
  let e = event;
  if (typeof e === "string") {
    try { e = JSON.parse(e); } catch { /* keep as string */ }
  }

  // API Gateway / Lambda URL proxy: body contains Telegram message JSON
  if (e && typeof e === "object" && "body" in e && typeof e.body === "string") {
    try {
      const body = JSON.parse(e.body);
      const text = body?.message?.text ?? "";
      const chatId = body?.message?.chat?.id ?? "";
      return { text, chatId, mode: "webhook" };
    } catch {
      // fallthrough
    }
  }

  // CLI mode: event is already the payload object
  const text = (e && typeof e === "object" && "text" in e) ? e.text : (typeof e === "string" ? e : "");
  return { text, chatId: DEFAULT_CHAT_ID, mode: "cli" };
}

exports.handler = async (event) => {
  if (!TABLE_NAME) throw new Error("Missing TABLE_NAME env var");

  const { text, chatId, mode } = parseEvent(event);
  const messageText = text || "(no text)";

  // 1) increment counter at id=0
  const inc = await ddb.send(new UpdateCommand({
    TableName: TABLE_NAME,
    Key: { id: 0 },
    UpdateExpression: "ADD #c :one",
    ExpressionAttributeNames: { "#c": "counter" },
    ExpressionAttributeValues: { ":one": 1 },
    ReturnValues: "UPDATED_NEW",
  }));
  const newId = Number(inc.Attributes?.counter);

  // 2) write the new item
  const item = { id: newId, text: messageText, createdAt: new Date().toISOString() };
  await ddb.send(new PutCommand({ TableName: TABLE_NAME, Item: item }));

  // 3) Telegram reply (if chatId present)
  if (chatId) {
    const reply = mode === "webhook"
      ? `✅ Guardado (#${newId}): ${messageText}`
      : `✅ CLI guardado (#${newId}): ${messageText}`;
    await sendTelegramMessage(chatId, reply);
  }

  return item; // visible in CLI outputfile.json
};

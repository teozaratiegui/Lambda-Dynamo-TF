// index.js (CommonJS)
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, UpdateCommand, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { SSMClient, GetParameterCommand } = require("@aws-sdk/client-ssm");

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const ssm = new SSMClient({});

const TABLE_NAME = process.env.TABLE_NAME;
const PARAM_NAME = process.env.TELEGRAM_TOKEN_PARAM;           // <-- see #2
const DEFAULT_CHAT_ID = process.env.TELEGRAM_DEFAULT_CHAT_ID || "";

let TELEGRAM_TOKEN_CACHE = null;
async function getTelegramToken() {
  if (TELEGRAM_TOKEN_CACHE) return TELEGRAM_TOKEN_CACHE;
  if (!PARAM_NAME) throw new Error("Missing TELEGRAM_TOKEN_PARAM env var");

  const res = await ssm.send(new GetParameterCommand({ Name: PARAM_NAME, WithDecryption: true }));
  let token = res.Parameter?.Value;
  try { const j = JSON.parse(token); if (j?.token) token = j.token; } catch {}
  if (!token) throw new Error("Telegram token parameter is empty/invalid");
  TELEGRAM_TOKEN_CACHE = token;
  return token;
}

async function sendTelegramMessage(chatId, message) {
  if (!chatId) throw new Error("Missing chatId");
  const token = await getTelegramToken();
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ chat_id: String(chatId), text: message }),
  });
  if (!res.ok) throw new Error(`Telegram send failed: ${res.status} ${res.statusText} ${await res.text().catch(()=> "")}`);
}

function parseEvent(event) {
  let e = event;
  if (typeof e === "string") { try { e = JSON.parse(e); } catch {} }
  if (e && typeof e === "object" && typeof e.body === "string") {
    try {
      const body = JSON.parse(e.body);
      return {
        text: body?.message?.text ?? "",
        chatId: body?.message?.chat?.id ?? "",
        mode: "webhook",
      };
    } catch {}
  }
  const text = (e && typeof e === "object" && "text" in e) ? e.text : (typeof e === "string" ? e : "");
  return { text, chatId: DEFAULT_CHAT_ID, mode: "cli" };
}

exports.handler = async (event) => {
  if (!TABLE_NAME) throw new Error("Missing TABLE_NAME env var");

  const { text, chatId, mode } = parseEvent(event);
  const messageText = text || "(no text)";

  const inc = await ddb.send(new UpdateCommand({
    TableName: TABLE_NAME,
    Key: { id: 0 },
    UpdateExpression: "ADD #c :one",
    ExpressionAttributeNames: { "#c": "counter" },
    ExpressionAttributeValues: { ":one": 1 },
    ReturnValues: "UPDATED_NEW",
  }));
  const newId = Number(inc.Attributes?.counter);

  const item = { id: newId, text: messageText, createdAt: new Date().toISOString() };
  await ddb.send(new PutCommand({ TableName: TABLE_NAME, Item: item }));

  if (chatId) {
    const reply = mode === "webhook" ? `✅ Guardado (#${newId}): ${messageText}` : `✅ CLI guardado (#${newId}): ${messageText}`;
    await sendTelegramMessage(chatId, reply);
  }

  return item;
};

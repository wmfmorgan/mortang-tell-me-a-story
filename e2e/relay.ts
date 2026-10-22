const mailpit = "http://127.0.0.1:57324";
const pollMs = 250;
const deadlineMs = 30_000;
const emailPattern = /^e2e-[a-z0-9]+-c[1-9]-[0-9]+@example\.test$/;
const localApi = new Set(["http://127.0.0.1:57321", "http://localhost:57321"]);
const appOrigins = ["http://127.0.0.1:3000", "http://localhost:3000"];
const verifyPattern = /https?:\/\/[^\s"'<>]+\/auth\/v1\/verify\?[^\s"'<>]+/;

type MailSummary = { ID?: unknown; id?: unknown };
type MailSearch = { messages?: MailSummary[] | null };
type MailMessage = {
  Text?: unknown;
  text?: unknown;
  HTML?: unknown;
  html?: unknown;
};

Deno.serve(
  { hostname: "127.0.0.1", port: 57390 },
  (request) => handle(request),
);

async function handle(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;
  let status = 404;
  let body = "not found";
  let contentType = "text/plain; charset=utf-8";
  try {
    if (request.method !== "GET") {
      status = 405;
      body = "method";
    } else if (path === "/health") {
      status = 200;
      body = "ok";
    } else if (path === "/magic-link") {
      const result = await magicLink(url.searchParams.get("email") ?? "");
      status = result.status;
      body = result.body;
      contentType = result.contentType;
    }
  } catch {
    status = 500;
    body = "error";
    contentType = "text/plain; charset=utf-8";
  }
  console.log(`${request.method} ${path} ${status}`);
  return new Response(body, {
    status,
    headers: {
      "Access-Control-Allow-Origin": "http://127.0.0.1:3000",
      "Vary": "Origin",
      "Content-Type": contentType,
    },
  });
}

async function magicLink(email: string): Promise<{
  status: number;
  body: string;
  contentType: string;
}> {
  if (!emailPattern.test(email)) {
    return {
      status: 400,
      body: "bad email",
      contentType: "text/plain; charset=utf-8",
    };
  }
  const found = await pollInbox(email);
  if (found.status !== 200 || !found.id) {
    return {
      status: found.status,
      body: found.status === 409 ? "conflict" : "deadline",
      contentType: "text/plain; charset=utf-8",
    };
  }
  const message = await readMessage(found.id);
  if (!message) {
    return {
      status: 502,
      body: "no message",
      contentType: "text/plain; charset=utf-8",
    };
  }
  const verifyUrl = firstVerifyUrl(message);
  if (!verifyUrl) {
    return {
      status: 502,
      body: "no verify url",
      contentType: "text/plain; charset=utf-8",
    };
  }
  if (!verifyUrlAllowed(verifyUrl)) {
    return {
      status: 500,
      body: "refused verify url",
      contentType: "text/plain; charset=utf-8",
    };
  }
  const location = await callbackLocation(verifyUrl);
  if (!location) {
    return {
      status: 502,
      body: "no app location",
      contentType: "text/plain; charset=utf-8",
    };
  }
  return {
    status: 200,
    body: JSON.stringify({ location }),
    contentType: "application/json",
  };
}

async function pollInbox(
  email: string,
): Promise<{ status: number; id?: string }> {
  const deadline = Date.now() + deadlineMs;
  while (true) {
    const messages = await searchInbox(email);
    if (messages === "conflict") return { status: 409 };
    if (messages.length === 1) {
      const id = messageId(messages[0]);
      if (id) return { status: 200, id };
    }
    const remaining = deadline - Date.now();
    if (remaining <= 0) return { status: 504 };
    await delay(Math.min(pollMs, remaining));
  }
}

async function searchInbox(email: string): Promise<MailSummary[] | "conflict"> {
  const target = new URL("/api/v1/search", mailpit);
  target.searchParams.set("query", `to:${email}`);
  try {
    const response = await fetch(target);
    if (!response.ok) return [];
    const decoded = await response.json();
    const messages = messagesOf(decoded);
    if (messages.length > 1) return "conflict";
    return messages;
  } catch {
    return [];
  }
}

function messagesOf(decoded: unknown): MailSummary[] {
  if (!decoded || typeof decoded !== "object") return [];
  const messages = (decoded as MailSearch).messages;
  return Array.isArray(messages) ? messages : [];
}

function messageId(message: MailSummary): string | null {
  const id = message.ID ?? message.id;
  return typeof id === "string" && id.length > 0 ? id : null;
}

async function readMessage(id: string): Promise<MailMessage | null> {
  try {
    const response = await fetch(
      `${mailpit}/api/v1/message/${encodeURIComponent(id)}`,
    );
    if (!response.ok) return null;
    const decoded = await response.json();
    if (!decoded || typeof decoded !== "object") return null;
    return decoded as MailMessage;
  } catch {
    return null;
  }
}

function firstVerifyUrl(message: MailMessage): string | null {
  const text = stringField(message.Text, message.text);
  const fromText = verifyPattern.exec(decodeAmp(text));
  if (fromText) return fromText[0];
  const html = stringField(message.HTML, message.html);
  const fromHtml = verifyPattern.exec(decodeAmp(html));
  return fromHtml ? fromHtml[0] : null;
}

function stringField(primary: unknown, fallback: unknown): string {
  if (typeof primary === "string") return primary;
  if (typeof fallback === "string") return fallback;
  return "";
}

function decodeAmp(value: string): string {
  return value.replaceAll("&amp;", "&");
}

function verifyUrlAllowed(verifyUrl: string): boolean {
  if (
    verifyUrl.includes("supabase.co") ||
    verifyUrl.includes("lchytafmnuefrgkguynt")
  ) {
    return false;
  }
  try {
    return localApi.has(new URL(verifyUrl).origin);
  } catch {
    return false;
  }
}

async function callbackLocation(verifyUrl: string): Promise<string | null> {
  try {
    const response = await fetch(verifyUrl, { redirect: "manual" });
    if (response.status < 300 || response.status >= 400) return null;
    const location = response.headers.get("location");
    if (!location) return null;
    const allowed = appOrigins.some((origin) => location.startsWith(origin));
    return allowed ? location : null;
  } catch {
    return null;
  }
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

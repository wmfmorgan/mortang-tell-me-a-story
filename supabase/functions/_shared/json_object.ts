import { errorResponse } from "./cors.ts";

export type JsonObject = Record<string, unknown>;

export async function readJsonObject(
  req: Request,
): Promise<JsonObject | Response> {
  try {
    const parsed = await req.json();
    if (isJsonObject(parsed)) return parsed;
  } catch (error) {
    if (!(error instanceof SyntaxError)) throw error;
  }
  return invalidJson();
}

function isJsonObject(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function invalidJson(): Response {
  return errorResponse("VALIDATION", "Invalid JSON body", 400);
}

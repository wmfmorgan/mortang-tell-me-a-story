export function jsonPost(
  url: string,
  body?: string,
  authorization: string | null = "Bearer test-token",
): Request {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (authorization !== null) headers.set("Authorization", authorization);
  return new Request(url, { method: "POST", headers, body });
}

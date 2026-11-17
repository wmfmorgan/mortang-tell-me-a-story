import { assertEquals } from "jsr:@std/assert@1";

const errorResponseMessage = /errorResponse\([^;]*\.message\b/s;

// Path, reason, and exact cast count. A higher or lower count fails, so the list only shrinks.
const objectCastAllowlist: ReadonlyArray<{
  path: string;
  reason: string;
  count: number;
}> = [
  {
    path: "create-branch-family/index.ts",
    count: 1,
    reason:
      "handleManage's client is cast with as unknown as { rpc: BranchRpc }. Left in place on purpose.",
  },
  {
    path: "create-root-family/index.ts",
    count: 1,
    reason:
      "create_family's row is read as { id?: string } after the RPC returns. Not a request body.",
  },
  {
    path: "resend-invite/index.ts",
    count: 1,
    reason:
      "resend_invite's row is read as { token, email, family_name, expires_at }. Not a request body.",
  },
  {
    path: "send-invite-email/index.ts",
    count: 1,
    reason:
      "The families embed is read as { name?: string } after the invite query. Not a request body.",
  },
  {
    path: "validate-invite-token/index.ts",
    count: 3,
    reason:
      "Invite embeds are read as { name, display_name } and { deleted_at } after an object check. Not a request body.",
  },
];

function isSource(name: string): boolean {
  return name.endsWith(".ts") && !name.endsWith("_test.ts");
}

async function sourceFiles(dir: URL, prefix: string): Promise<string[]> {
  const paths: string[] = [];
  for await (const entry of Deno.readDir(dir)) {
    const rel = prefix.length > 0 ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory) {
      const child = new URL(`${entry.name}/`, dir);
      paths.push(...await sourceFiles(child, rel));
      continue;
    }
    if (entry.isFile && isSource(entry.name)) paths.push(rel);
  }
  return paths;
}

function castCount(source: string): number {
  return source.match(/\bas\s*\{/g)?.length ?? 0;
}

function castCountHit(
  path: string,
  source: string,
  allowlist: ReadonlyArray<{ path: string; count: number }>,
): string | null {
  const actual = castCount(source);
  const allowed = allowlist.find((entry) => entry.path === path);
  if (!allowed) {
    return actual === 0 ? null : `${path}: inline object cast ${actual}`;
  }
  if (actual === allowed.count) return null;
  if (actual > allowed.count) {
    return `${path}: inline object cast ${actual} > ${allowed.count}`;
  }
  return `${path}: allowlist count ${allowed.count} > actual ${actual}`;
}

Deno.test(
  "function sources have no inline object cast and errorResponse does not take .message",
  async () => {
    const root = new URL("..", import.meta.url);
    const paths = (await sourceFiles(root, "")).sort();
    const hits: string[] = [];
    const seen = new Set<string>();
    for (const path of paths) {
      seen.add(path);
      const source = await Deno.readTextFile(new URL(path, root));
      const castHit = castCountHit(path, source, objectCastAllowlist);
      if (castHit) hits.push(castHit);
      if (errorResponseMessage.test(source)) {
        hits.push(`${path}: errorResponse .message`);
      }
    }
    for (const entry of objectCastAllowlist) {
      if (!seen.has(entry.path)) hits.push(`${entry.path}: allowlist has no file`);
    }
    assertEquals(hits, []);
  },
);

Deno.test("an extra inline object cast in an allowlisted file fails", () => {
  const path = "send-invite-email/index.ts";
  const source = "parsed as { invite_id?: string };\nkeep as { name?: string };";
  const hit = castCountHit(path, source, [{ path, count: 1 }]);
  assertEquals(hit, `${path}: inline object cast 2 > 1`);
});

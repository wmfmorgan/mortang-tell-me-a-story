import { assertEquals } from "jsr:@std/assert@1";

const inlineObjectCast = /\bas\s*\{/;
const errorResponseMessage = /errorResponse\([^;]*\.message\b/s;

// Path plus reason. A stale entry fails this test, so the list only shrinks.
const objectCastAllowlist: ReadonlyArray<{ path: string; reason: string }> = [
  {
    path: "create-branch-family/index.ts",
    reason:
      "handleManage's client is cast with as unknown as { rpc: BranchRpc }. Left in place on purpose.",
  },
  {
    path: "create-root-family/index.ts",
    reason:
      "create_family's row is read as { id?: string } after the RPC returns. Not a request body.",
  },
  {
    path: "resend-invite/index.ts",
    reason:
      "resend_invite's row is read as { token, email, family_name, expires_at }. Not a request body.",
  },
  {
    path: "send-invite-email/index.ts",
    reason:
      "The families embed is read as { name?: string } after the invite query. Not a request body.",
  },
  {
    path: "validate-invite-token/index.ts",
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

Deno.test(
  "function sources have no inline object cast and errorResponse does not take .message",
  async () => {
    const root = new URL("..", import.meta.url);
    const paths = (await sourceFiles(root, "")).sort();
    const hits: string[] = [];
    const castPaths = new Set<string>();
    for (const path of paths) {
      const source = await Deno.readTextFile(new URL(path, root));
      if (inlineObjectCast.test(source)) castPaths.add(path);
      if (errorResponseMessage.test(source)) {
        hits.push(`${path}: errorResponse .message`);
      }
    }
    for (const path of castPaths) {
      if (!objectCastAllowlist.some((entry) => entry.path === path)) {
        hits.push(`${path}: inline object cast`);
      }
    }
    for (const entry of objectCastAllowlist) {
      if (!castPaths.has(entry.path)) {
        hits.push(`${entry.path}: allowlist has no hit`);
      }
    }
    assertEquals(hits, []);
  },
);

import { assertEquals } from "jsr:@std/assert@1";

const parsedCast = "parsed as {";
const rawMessageArg =
  /errorResponse\(\s*(?:"[^"]*"|'[^']*'|`[^`]*`|[A-Za-z_][\w.]*)\s*,\s*error\.message\b/;

function isSource(name: string): boolean {
  return name.endsWith(".ts") && !name.endsWith("_test.ts");
}

async function indexSource(root: URL, name: string): Promise<string | null> {
  const path = `${name}/index.ts`;
  try {
    await Deno.stat(new URL(path, root));
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return null;
    throw error;
  }
  return path;
}

async function sourceFiles(): Promise<string[]> {
  const root = new URL("..", import.meta.url);
  const paths: string[] = [];
  for await (const entry of Deno.readDir(root)) {
    if (entry.name === "_shared" && entry.isDirectory) {
      for await (const shared of Deno.readDir(new URL("_shared/", root))) {
        if (shared.isFile && isSource(shared.name)) {
          paths.push(`_shared/${shared.name}`);
        }
      }
      continue;
    }
    if (!entry.isDirectory) continue;
    const index = await indexSource(root, entry.name);
    if (index) paths.push(index);
  }
  paths.sort();
  return paths;
}

function findings(path: string, source: string): string[] {
  const hits: string[] = [];
  if (source.includes(parsedCast)) hits.push(parsedCast);
  if (rawMessageArg.test(source)) hits.push("errorResponse error.message");
  return hits.map((hit) => `${path}: ${hit}`);
}

Deno.test("edge functions do not cast parsed JSON or return raw database text", async () => {
  const root = new URL("..", import.meta.url);
  const hits: string[] = [];
  for (const path of await sourceFiles()) {
    const source = await Deno.readTextFile(new URL(path, root));
    hits.push(...findings(path, source));
  }
  assertEquals(hits, []);
});

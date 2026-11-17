import { assertEquals } from "jsr:@std/assert@1";

import config from "../../config.toml" with { type: "text" };

function declaredFunctions(toml: string): string[] {
  return [...toml.matchAll(/^\[functions\.([^\]\s]+)\]/gm)].map((match) =>
    match[1]
  );
}

async function functionFolders(): Promise<string[]> {
  const names: string[] = [];
  for await (const entry of Deno.readDir(new URL("..", import.meta.url))) {
    if (!entry.isDirectory || entry.name === "_shared") continue;
    names.push(entry.name);
  }
  names.sort();
  return names;
}

Deno.test("every function folder is declared in config.toml", async () => {
  const missing = (await functionFolders()).filter((name) =>
    !declaredFunctions(config).includes(name)
  );
  assertEquals(
    missing,
    [],
    `missing [functions.<name>] for: ${missing.join(", ")}`,
  );
});

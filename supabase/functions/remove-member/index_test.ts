import { assertEquals } from "jsr:@std/assert@1";

import { removeMember } from "./index.ts";

Deno.test("remove-member calls remove_member and keeps the story link in SQL", async () => {
  let fn = "";
  let args: Record<string, string> = {};
  const res = await removeMember(
    {
      rpc: (name, rpcArgs) => {
        fn = name;
        args = rpcArgs;
        return Promise.resolve({ error: null });
      },
    },
    {
      family_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      user_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    },
  );
  const json = await res.json();
  assertEquals(res.status, 200);
  assertEquals(json.ok, true);
  assertEquals(fn, "remove_member");
  assertEquals(args.fid, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
  assertEquals(args.target, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb");
});

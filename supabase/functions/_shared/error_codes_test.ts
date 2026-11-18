import { assertEquals } from "jsr:@std/assert@1";

import { ERROR_CODES } from "./error_codes.ts";

Deno.test("ERROR_CODES lists the five wire codes in order", () => {
  assertEquals([...ERROR_CODES], [
    "NOT_FOUND",
    "FORBIDDEN",
    "VALIDATION",
    "INVITE_INVALID",
    "AUTH_REQUIRED",
  ]);
});

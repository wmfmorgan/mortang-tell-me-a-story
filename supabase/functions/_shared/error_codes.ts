export const ERROR_CODES = ["NOT_FOUND", "FORBIDDEN", "VALIDATION", "INVITE_INVALID", "AUTH_REQUIRED"] as const;
export type ErrorCode = typeof ERROR_CODES[number];

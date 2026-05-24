import type { RequestHandler } from "msw";

// Handlers base — cada test file adiciona handlers específicos via server.use()
export const handlers: RequestHandler[] = [];

import express, { type Express } from "express";
import {
  hostHeaderValidation,
  localhostHostValidation,
} from "@modelcontextprotocol/sdk/server/middleware/hostHeaderValidation.js";
import type { OracleMcpConfig } from "./config.js";

/**
 * Same behavior as {@link createMcpExpressApp} from the MCP SDK, but with a
 * configurable JSON body size (SDK defaults to body-parser's 100kb limit).
 */
export function createOracleMcpExpressApp(cfg: OracleMcpConfig): Express {
  const host = cfg.mcpHttp.host;
  const allowedHosts = cfg.mcpHttp.allowedHosts;
  const jsonLimit = cfg.mcpHttp.maxRequestBody ?? "32mb";

  const app = express();
  app.use(express.json({ limit: jsonLimit }));

  if (allowedHosts !== undefined && allowedHosts.length > 0) {
    app.use(hostHeaderValidation(allowedHosts));
  } else {
    const localhostHosts = ["127.0.0.1", "localhost", "::1"];
    if (localhostHosts.includes(host)) {
      app.use(localhostHostValidation());
    } else if (host === "0.0.0.0" || host === "::") {
      // eslint-disable-next-line no-console
      console.warn(
        `Warning: Server is binding to ${host} without DNS rebinding protection. ` +
          "Set oracle.mcpHttp.allowedHosts or use authentication."
      );
    }
  }

  return app;
}

import { createMcpExpressApp } from "@modelcontextprotocol/sdk/server/express.js";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import type { Request, Response } from "express";
import { loadOracleMcpConfig } from "./config.js";
import { createPool, probeOracleDb } from "./oracle.js";
import {
  formatOracleError,
  jsonSafe,
  registerOracleTools,
} from "./tools.js";

function jsonRpc405(res: Response): void {
  res.writeHead(405).end(
    JSON.stringify({
      jsonrpc: "2.0",
      error: {
        code: -32000,
        message: "Method not allowed.",
      },
      id: null,
    })
  );
}

async function main(): Promise<void> {
  const mcpCfg = loadOracleMcpConfig();
  const pool = await createPool(mcpCfg);
  const { host, port, path: mcpPath } = mcpCfg.mcpHttp;

  const bindAll = host === "0.0.0.0" || host === "::";
  const app = bindAll ? createMcpExpressApp({ host }) : createMcpExpressApp();

  app.get("/health", (_req: Request, res: Response) => {
    res.json({ ok: true });
  });

  app.get("/ready", async (_req: Request, res: Response) => {
    try {
      const out = await probeOracleDb(pool);
      res.status(200).json({
        ok: true,
        query: "SELECT * FROM dual",
        rowCount: out.rows.length,
        rows: jsonSafe(out.rows),
      });
    } catch (err) {
      res.status(503).json({
        ok: false,
        error: formatOracleError(err),
      });
    }
  });

  app.post(mcpPath, async (req: Request, res: Response) => {
    const server = new McpServer({ name: "oracle-mcp", version: "1.0.0" });
    registerOracleTools(server, pool, mcpCfg);
    try {
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: undefined,
      });
      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
      res.on("close", () => {
        void transport.close();
        void server.close();
      });
    } catch (error) {
      console.error("Error handling MCP request:", error);
      if (!res.headersSent) {
        res.status(500).json({
          jsonrpc: "2.0",
          error: {
            code: -32603,
            message: "Internal server error",
          },
          id: null,
        });
      }
    }
  });

  app.get(mcpPath, (_req: Request, res: Response) => {
    jsonRpc405(res);
  });

  app.delete(mcpPath, (_req: Request, res: Response) => {
    jsonRpc405(res);
  });

  const httpServer = app.listen(port, host, () => {
    console.error(
      `oracle-mcp listening on http://${host}:${port} (MCP: POST ${mcpPath}, ready: GET /ready)`
    );
  });

  const shutdown = async (): Promise<void> => {
    await new Promise<void>((resolve, reject) => {
      httpServer.close((err) => (err ? reject(err) : resolve()));
    });
    await pool.close(0);
  };

  process.on("SIGINT", () => {
    void shutdown().then(() => process.exit(0));
  });
  process.on("SIGTERM", () => {
    void shutdown().then(() => process.exit(0));
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

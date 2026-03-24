# oracle-mcp

Model Context Protocol server for Oracle Database over **Streamable HTTP** (Express). Use it from [Cursor](https://cursor.com) to run SQL and inspect schema via tools: `execute_sql`, `list_tables`, `describe_table`.

## Prerequisites

- Node.js 18+
- Oracle Instant Client if you use `oracle.libDir` (thick mode)
- [`development.config.json`](development.config.json) in the **oracle-mcp** directory with `oracle.connection` and optional `oracle.mcpHttp`

## Configuration

### `development.config.json`

- **`oracle.connection`** — `user`, `password`, `connectString` (or `connectString1`), optional pool fields
- **`oracle.libDir`** — Instant Client directory (optional)
- **`oracle.maxRows`** — default row cap for tools (optional, default `10000`)
- **`oracle.mcpHttp`** (optional) — HTTP listen options:
  - **`host`** — default `127.0.0.1` (use `0.0.0.0` only on trusted networks; see security below)
  - **`port`** — default `3111`
  - **`path`** — MCP endpoint path, default `/mcp` (with or without leading `/`)

## Run the server

**Production-style** (compile then run):

```bash
cd oracle-mcp
npm install
npm run build
npm start
```

**Development** (TypeScript directly, restarts on `src/**/*.ts` changes — no `build`):

```bash
cd oracle-mcp
npm install
npm run dev
```

Logs show the listen URL, MCP path, and `/ready` hint.

Stop with **Ctrl+C** (pool and HTTP server are closed).

## Verify the server

### 1. Process only (no database)

```bash
curl -s http://127.0.0.1:3111/health
```

Expect: `{"ok":true}` (adjust host/port if you changed `oracle.mcpHttp`).

### 2. Database (same path as MCP `execute_sql`)

Uses the shared connection pool and `executeStatement` with `SELECT * FROM dual`:

```bash
curl -s -i http://127.0.0.1:3111/ready
```

- **200** — `ok`, `query`, `rowCount`, `rows` (JSON-safe)
- **503** — `ok: false`, `error` (Oracle/network/config issue)

This is not the MCP wire format; it proves Oracle is reachable the same way tools do. Full MCP is validated in Cursor (below).

## Configure Cursor

1. **Start** `oracle-mcp` (`npm start`) before using MCP in Cursor.
2. Open **Cursor Settings → MCP** (or edit **`.cursor/mcp.json`** in the project or user config).
3. Add a **Streamable HTTP** (or URL-based) server pointing at your MCP endpoint, for example:

```json
{
  "mcpServers": {
    "oracle-dev": {
      "type": "streamableHttp",
      "url": "http://127.0.0.1:3111/mcp"
    }
  }
}
```

If your Cursor version uses a different shape (e.g. only `url` without `type`), use the UI or docs for that build. **No auth** in this setup — omit `headers`.

4. **Restart Cursor** (or reload MCP) after changing config.

## Verify MCP in Cursor

1. MCP panel: server **connected**, tools listed: **`execute_sql`**, **`list_tables`**, **`describe_table`**.
2. In **Agent** mode (tools enabled), ask explicitly, e.g.:  
   *Using the Oracle MCP `execute_sql` tool, run `SELECT * FROM dual`.*

If the server fails to start, check terminal output, then **`/ready`** and **`/health`**.

## Security

- **No authentication** — dev-only.
- Binding **`0.0.0.0`** exposes the service on all interfaces; the SDK may log a DNS-rebinding warning. Prefer **`127.0.0.1`** or use a reverse proxy + TLS + auth for anything beyond local dev.

## Scripts

| Script        | Description              |
|---------------|--------------------------|
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start`     | Run the HTTP server (`dist/`) |
| `npm run dev`   | Run `src/index.ts` with hot reload (process restart on save) |

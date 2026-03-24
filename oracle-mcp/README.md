# oracle-mcp

Model Context Protocol (stdio) server for Oracle Database. Use it from [Cursor](https://cursor.com) to run SQL and inspect schema via tools: `execute_sql`, `list_tables`, `describe_table`.

## Prerequisites

- Node.js 18+
- Oracle Instant Client on the machine (thick mode), unless you rely on the driver’s thin mode and your network/DB version supports it.
- Build once: `npm install` and `npm run build`.
- **`development.config.json`** in the `oracle-mcp` folder (next to `package.json`) with an `oracle` section (see below).

## Configuration (`development.config.json`)

Place [`development.config.json`](development.config.json) in the **oracle-mcp** package directory. The server reads **`oracle.libDir`**, **`oracle.connection`**, and optional **`oracle.maxRows`**.

Example `oracle` block:

```json
{
  "oracle": {
    "libDir": "C:\\oracle\\instantclient_11_2",
    "maxRows": 10000,
    "connection": {
      "user": "your_user",
      "password": "your_password",
      "connectString": "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=host)(PORT=1521))(CONNECT_DATA=(SID=your_sid)))",
      "poolMin": 2,
      "poolMax": 10,
      "poolIncrement": 1,
      "poolTimeout": 60
    }
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `oracle.connection.user` | yes | Database user |
| `oracle.connection.password` | yes | Password |
| `oracle.connection.connectString` | yes* | TNS-style or Easy Connect string |
| `oracle.connection.connectString1` | yes* | Alternative name; used if `connectString` is omitted |
| `oracle.libDir` | no | Instant Client directory; if set, thick mode is enabled |
| `oracle.connection.poolMin` / `poolMax` / `poolIncrement` / `poolTimeout` | no | Defaults: 2, 10, 1, 60 (seconds) |
| `oracle.maxRows` | no | Default row cap for tools when `maxRows` is omitted on `execute_sql`; default `10000` |

## Cursor MCP configuration

After `npm run build`, point Cursor at the compiled entry. No Oracle-related environment variables are required if `development.config.json` is in place.

```json
{
  "mcpServers": {
    "oracle-dev": {
      "command": "node",
      "args": ["C:/Repos/github/ai-dev/oracle-mcp/dist/index.js"],
      "cwd": "C:/Repos/github/ai-dev/oracle-mcp"
    }
  }
}
```

`cwd` is optional if the config file path is resolved from the server’s location (`dist/` → parent folder); the server resolves `development.config.json` relative to the **package root** (directory containing `dist/`), not the process `cwd`. So you can omit `cwd` when `args` uses an absolute path to `dist/index.js`.

Restart Cursor (or reload MCP) after changes.

## Tools

- **`execute_sql`** — One statement per call; optional `binds` (object for named binds or array for positional) and optional `maxRows` for queries.
- **`list_tables`** — Queries `ALL_TABLES` with optional `owner` and `table_name_pattern` (`%` / `_` wildcards).
- **`describe_table`** — Column list from `ALL_TAB_COLUMNS` and PK columns from `ALL_CONSTRAINTS` / `ALL_CONS_COLUMNS`.

## Scripts

- `npm run build` — Compile TypeScript to `dist/`
- `npm start` — Run the server on stdio (normally started by Cursor, not manually for interactive use)

## Manual sanity check

```bash
cd oracle-mcp
npm start
```

The process waits on stdin; that is expected. Stop with Ctrl+C. Prefer validating from Cursor’s MCP panel once configured.

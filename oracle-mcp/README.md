# oracle-mcp

Model Context Protocol (stdio) server for Oracle Database. Use it from [Cursor](https://cursor.com) to run SQL and inspect schema via tools: `execute_sql`, `list_tables`, `describe_table`.

## Prerequisites

- Node.js 18+
- Oracle Instant Client on the machine (thick mode), unless you rely on the driver’s thin mode and your network/DB version supports it.
- Build once: `npm install` and `npm run build`.

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ORACLE_USER` | yes | Database user |
| `ORACLE_PASSWORD` | yes | Password |
| `ORACLE_CONNECT_STRING` | yes | Connect descriptor or Easy Connect string (single line in JSON env is easiest) |
| `ORACLE_CLIENT_LIB_DIR` | no | Instant Client directory; if set, thick mode is enabled via `initOracleClient` |
| `ORACLE_POOL_MIN` | no | Default `2` |
| `ORACLE_POOL_MAX` | no | Default `10` |
| `ORACLE_POOL_INCREMENT` | no | Default `1` |
| `ORACLE_POOL_TIMEOUT` | no | Pool timeout in seconds, default `60` |
| `ORACLE_MAX_ROWS` | no | Default row cap for `execute_sql` / listing tools when `maxRows` is omitted, default `10000` |

## Cursor MCP configuration

After `npm run build`, add a server (user-level or project `.cursor/mcp.json`). Example:

```json
{
  "mcpServers": {
    "oracle-dev": {
      "command": "node",
      "args": ["C:/Repos/github/ai-dev/oracle-mcp/dist/index.js"],
      "env": {
        "ORACLE_USER": "your_user",
        "ORACLE_PASSWORD": "your_password",
        "ORACLE_CONNECT_STRING": "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=your-host)(PORT=1521))(CONNECT_DATA=(SID=your_sid)))",
        "ORACLE_CLIENT_LIB_DIR": "C:\\oracle\\instantclient_11_2",
        "ORACLE_POOL_MAX": "10",
        "ORACLE_MAX_ROWS": "10000"
      }
    }
  }
}
```

Use forward slashes in `args` paths when possible. Escape backslashes in JSON for Windows paths under `env`.

Restart Cursor (or reload MCP) after changes.

## Tools

- **`execute_sql`** — One statement per call; optional `binds` (object for named binds or array for positional) and optional `maxRows` for queries.
- **`list_tables`** — Queries `ALL_TABLES` with optional `owner` and `table_name_pattern` (`%` / `_` wildcards).
- **`describe_table`** — Column list from `ALL_TAB_COLUMNS` and PK columns from `ALL_CONSTRAINTS` / `ALL_CONS_COLUMNS`.

## Scripts

- `npm run build` — Compile TypeScript to `dist/`
- `npm start` — Run the server on stdio (normally started by Cursor, not manually for interactive use)

## Manual sanity check

With env vars set in the shell:

```bash
npm start
```

The process waits on stdin; that is expected. Stop with Ctrl+C. Prefer validating from Cursor’s MCP panel once configured.

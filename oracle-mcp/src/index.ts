import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import type oracledb from "oracledb";
import { loadOracleMcpConfig } from "./config.js";
import { createPool, executeStatement } from "./oracle.js";

function formatOracleError(err: unknown): string {
  if (err && typeof err === "object" && "errorNum" in err) {
    const e = err as { message?: string; errorNum?: number };
    return `${e.message ?? String(err)} (ORA-${e.errorNum})`;
  }
  if (err instanceof Error) return err.message;
  return String(err);
}

function jsonSafe(value: unknown): unknown {
  if (value === null || value === undefined) return value;
  if (typeof value === "bigint") return value.toString();
  if (value instanceof Date) return value.toISOString();
  if (typeof Buffer !== "undefined" && Buffer.isBuffer(value)) {
    return { __type: "buffer", base64: value.toString("base64") };
  }
  if (Array.isArray(value)) return value.map(jsonSafe);
  if (typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([k, v]) => [k, jsonSafe(v)])
    );
  }
  return value;
}

function stringifyPayload(data: unknown): string {
  return JSON.stringify(jsonSafe(data), null, 2);
}

async function main(): Promise<void> {
  const mcpCfg = loadOracleMcpConfig();
  const pool = await createPool(mcpCfg);

  const server = new McpServer({ name: "oracle-mcp", version: "1.0.0" });

  server.registerTool(
    "execute_sql",
    {
      description:
        "Execute one SQL statement (SELECT, DML, DDL, or PL/SQL). Use a single statement per call. For named binds, use :name in SQL and pass a binds object.",
      inputSchema: {
        sql: z.string(),
        binds: z
          .union([z.record(z.string(), z.unknown()), z.array(z.unknown())])
          .optional(),
        maxRows: z.number().int().positive().max(1_000_000).optional(),
      },
    },
    async ({ sql, binds, maxRows }) => {
      try {
        const limit = maxRows ?? mcpCfg.defaultMaxRows;
        const out = await executeStatement(
          pool,
          sql,
          binds as oracledb.BindParameters | undefined,
          limit
        );
        const body = {
          metaData: out.metaData,
          rows: out.rows,
          rowCount: out.rows.length,
          rowsAffected: out.rowsAffected,
          lastRowid: out.lastRowid,
        };
        return {
          content: [{ type: "text", text: stringifyPayload(body) }],
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: formatOracleError(err) }],
          isError: true,
        };
      }
    }
  );

  server.registerTool(
    "list_tables",
    {
      description:
        "List tables from ALL_TABLES with optional owner and table_name LIKE pattern (Oracle wildcard % and _).",
      inputSchema: {
        owner: z.string().optional(),
        table_name_pattern: z.string().optional(),
      },
    },
    async ({ owner, table_name_pattern: pattern }) => {
      try {
        const binds: Record<string, string> = {};
        let sql =
          "SELECT owner, table_name, tablespace_name, num_rows FROM all_tables WHERE 1=1";
        if (owner !== undefined && owner !== "") {
          sql += " AND owner = :owner";
          binds.owner = owner;
        }
        if (pattern !== undefined && pattern !== "") {
          sql += " AND UPPER(table_name) LIKE UPPER(:pat) ESCAPE '\\'";
          binds.pat = pattern;
        }
        sql += " ORDER BY owner, table_name";
        const out = await executeStatement(
          pool,
          sql,
          binds,
          mcpCfg.defaultMaxRows
        );
        return {
          content: [{ type: "text", text: stringifyPayload(out.rows) }],
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: formatOracleError(err) }],
          isError: true,
        };
      }
    }
  );

  server.registerTool(
    "describe_table",
    {
      description:
        "Describe columns and primary-key columns for a table via ALL_TAB_COLUMNS and ALL_CONSTRAINTS.",
      inputSchema: {
        owner: z.string(),
        table_name: z.string(),
      },
    },
    async ({ owner, table_name }) => {
      try {
        const colSql = `
SELECT column_id, column_name, data_type, data_length, data_precision, data_scale,
       nullable, data_default
FROM all_tab_columns
WHERE owner = :owner AND table_name = :table_name
ORDER BY column_id`;
        const pkSql = `
SELECT acc.column_name, acc.position
FROM all_constraints ac
JOIN all_cons_columns acc
  ON ac.owner = acc.owner AND ac.constraint_name = acc.constraint_name
WHERE ac.owner = :owner
  AND ac.table_name = :table_name
  AND ac.constraint_type = 'P'
ORDER BY acc.position`;
        const binds = { owner, table_name };
        const [cols, pks] = await Promise.all([
          executeStatement(pool, colSql, binds, mcpCfg.defaultMaxRows),
          executeStatement(pool, pkSql, binds, mcpCfg.defaultMaxRows),
        ]);
        return {
          content: [
            {
              type: "text",
              text: stringifyPayload({
                columns: cols.rows,
                primaryKeyColumns: pks.rows,
              }),
            },
          ],
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: formatOracleError(err) }],
          isError: true,
        };
      }
    }
  );

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

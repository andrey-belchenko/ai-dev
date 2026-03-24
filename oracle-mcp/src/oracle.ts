import oracledb from "oracledb";
import type { OracleMcpConfig } from "./config.js";

let thickInitialized = false;

export function initThickMode(libDir: string): void {
  if (thickInitialized) return;
  oracledb.initOracleClient({ libDir });
  thickInitialized = true;
}

export async function createPool(cfg: OracleMcpConfig): Promise<oracledb.Pool> {
  if (cfg.libDir) {
    initThickMode(cfg.libDir);
  }
  return oracledb.createPool({
    user: cfg.user,
    password: cfg.password,
    connectString: cfg.connectString,
    poolMin: cfg.poolMin,
    poolMax: cfg.poolMax,
    poolIncrement: cfg.poolIncrement,
    poolTimeout: cfg.poolTimeout,
  });
}

export type ExecuteOutcome = {
  metaData?: oracledb.Metadata<unknown>[];
  rows: unknown[];
  rowsAffected?: number;
  lastRowid?: string;
};

export async function executeStatement(
  pool: oracledb.Pool,
  sql: string,
  binds: oracledb.BindParameters | undefined,
  maxRows: number
): Promise<ExecuteOutcome> {
  const conn = await pool.getConnection();
  try {
    const result = await conn.execute(sql, binds ?? {}, {
      outFormat: oracledb.OUT_FORMAT_OBJECT,
      maxRows,
      autoCommit: true,
    });
    return {
      metaData: result.metaData as oracledb.Metadata<unknown>[] | undefined,
      rows: (result.rows as unknown[]) ?? [],
      rowsAffected: result.rowsAffected,
      lastRowid: result.lastRowid != null ? String(result.lastRowid) : undefined,
    };
  } finally {
    await conn.close();
  }
}

const PROBE_SQL = "SELECT * FROM dual";

/** Same pool and execute path as MCP `execute_sql`; use for HTTP `/ready`. */
export async function probeOracleDb(
  pool: oracledb.Pool
): Promise<ExecuteOutcome> {
  return executeStatement(pool, PROBE_SQL, {}, 1);
}

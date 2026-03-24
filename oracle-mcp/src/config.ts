import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export type OracleMcpHttpConfig = {
  host: string;
  port: number;
  path: string;
};

export type OracleMcpConfig = {
  user: string;
  password: string;
  connectString: string;
  libDir: string | undefined;
  poolMin: number;
  poolMax: number;
  poolIncrement: number;
  poolTimeout: number;
  defaultMaxRows: number;
  mcpHttp: OracleMcpHttpConfig;
};

type DevConfigJson = {
  oracle?: {
    libDir?: string;
    maxRows?: number;
    mcpHttp?: {
      host?: string;
      port?: number;
      path?: string;
    };
    connection?: {
      user?: string;
      password?: string;
      connectString?: string;
      connectString1?: string;
      poolMin?: number;
      poolMax?: number;
      poolIncrement?: number;
      poolTimeout?: number;
    };
  };
};

function normalizeMcpPath(raw: string | undefined): string {
  if (raw === undefined || raw === "") return "/mcp";
  const t = raw.trim();
  if (t === "") return "/mcp";
  return t.startsWith("/") ? t : `/${t}`;
}

/** `development.config.json` next to the package root (sibling of `dist/`). */
export function defaultDevelopmentConfigPath(): string {
  return join(__dirname, "..", "development.config.json");
}

export function loadOracleMcpConfig(
  configPath: string = defaultDevelopmentConfigPath()
): OracleMcpConfig {
  const resolved = resolve(configPath);
  if (!existsSync(resolved)) {
    throw new Error(
      `Config file not found: ${resolved}. Create oracle-mcp/development.config.json with an "oracle" section.`
    );
  }
  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(resolved, "utf8"));
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`Invalid JSON in ${resolved}: ${msg}`);
  }
  const oracle = (raw as DevConfigJson).oracle;
  if (!oracle?.connection) {
    throw new Error(`Missing "oracle.connection" in ${resolved}`);
  }
  const c = oracle.connection;
  const connectString = c.connectString ?? c.connectString1;
  if (!c.user || !c.password || !connectString) {
    throw new Error(
      `oracle.connection must include user, password, and connectString (or connectString1) in ${resolved}`
    );
  }
  const libDir = oracle.libDir?.trim() || undefined;
  const mh = oracle.mcpHttp;
  const mcpHttp: OracleMcpHttpConfig = {
    host: mh?.host?.trim() || "127.0.0.1",
    port:
      typeof mh?.port === "number" && Number.isFinite(mh.port)
        ? mh.port
        : 3111,
    path: normalizeMcpPath(mh?.path),
  };
  return {
    user: c.user,
    password: c.password,
    connectString,
    libDir,
    poolMin: c.poolMin ?? 2,
    poolMax: c.poolMax ?? 10,
    poolIncrement: c.poolIncrement ?? 1,
    poolTimeout: c.poolTimeout ?? 60,
    defaultMaxRows: oracle.maxRows ?? 10_000,
    mcpHttp,
  };
}

function requireEnv(name: string): string {
  const v = process.env[name];
  if (v === undefined || v === "") {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return v;
}

function parseIntEnv(name: string, defaultValue: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return defaultValue;
  const n = Number.parseInt(raw, 10);
  if (Number.isNaN(n)) {
    throw new Error(`Invalid integer for ${name}: ${raw}`);
  }
  return n;
}

export type OracleEnvConfig = {
  user: string;
  password: string;
  connectString: string;
  libDir: string | undefined;
  poolMin: number;
  poolMax: number;
  poolIncrement: number;
  poolTimeout: number;
  defaultMaxRows: number;
};

export function loadOracleEnvConfig(): OracleEnvConfig {
  return {
    user: requireEnv("ORACLE_USER"),
    password: requireEnv("ORACLE_PASSWORD"),
    connectString: requireEnv("ORACLE_CONNECT_STRING"),
    libDir: process.env.ORACLE_CLIENT_LIB_DIR?.trim() || undefined,
    poolMin: parseIntEnv("ORACLE_POOL_MIN", 2),
    poolMax: parseIntEnv("ORACLE_POOL_MAX", 10),
    poolIncrement: parseIntEnv("ORACLE_POOL_INCREMENT", 1),
    poolTimeout: parseIntEnv("ORACLE_POOL_TIMEOUT", 60),
    defaultMaxRows: parseIntEnv("ORACLE_MAX_ROWS", 10_000),
  };
}

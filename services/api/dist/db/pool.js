import { Pool } from "pg";
import { env } from "../config/env.js";
export const pool = new Pool({
    connectionString: env.databaseUrl,
    max: 20,
    min: 2,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    statement_timeout: 30_000,
    query_timeout: 30_000,
});
// Pool event handlers
pool.on("error", (err) => {
    console.error("[pool] Unexpected idle client error:", err.message);
});
export async function gracefulShutdownDB() {
    console.log(`\n[pool] draining connections...`);
    try {
        await pool.end();
        console.log("[pool] All connections closed.");
    }
    catch (err) {
        console.error("[pool] Error during shutdown:", err);
    }
}

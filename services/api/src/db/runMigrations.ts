import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "./pool.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function ensureMigrationTable(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version    TEXT        PRIMARY KEY,
      name       TEXT        NOT NULL DEFAULT '',
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function getAppliedMigrations(): Promise<Set<string>> {
  const result = await pool.query("SELECT version FROM schema_migrations ORDER BY version");
  return new Set(result.rows.map((row: { version: string }) => row.version));
}

async function run(): Promise<void> {
  console.log("Starting database migration...");
  console.log(`Database: ${process.env.DATABASE_URL?.replace(/:[^@]+@/, ":***@")}`);

  await ensureMigrationTable();
  const applied = await getAppliedMigrations();

  const migrationsDir = path.join(__dirname, "migrations");
  const migrationFiles = (await readdir(migrationsDir))
    .filter((file) => file.endsWith(".sql"))
    .sort();

  let appliedCount = 0;
  let skippedCount = 0;

  for (const migrationFile of migrationFiles) {
    const version = migrationFile.replace(/\.sql$/, "");

    if (applied.has(version)) {
      console.log(`  ⏭  ${migrationFile} (already applied)`);
      skippedCount += 1;
      continue;
    }

    const sqlPath = path.join(migrationsDir, migrationFile);
    const sql = await readFile(sqlPath, "utf8");

    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(sql);
      await client.query(
        "INSERT INTO schema_migrations (version, name) VALUES ($1, $2)",
        [version, migrationFile]
      );
      await client.query("COMMIT");
      console.log(`  ✅ ${migrationFile} applied successfully`);
      appliedCount += 1;
    } catch (error) {
      await client.query("ROLLBACK");
      console.error(`  ❌ ${migrationFile} FAILED — rolled back`);
      throw error;
    } finally {
      client.release();
    }
  }

  console.log(`\nMigration complete: ${appliedCount} applied, ${skippedCount} skipped.`);
  await pool.end();
}

run().catch(async (error) => {
  console.error("\nMigration failed:", error.message);
  await pool.end();
  process.exit(1);
});

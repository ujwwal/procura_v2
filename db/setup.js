const fs = require("node:fs");
const path = require("node:path");
const { Pool, Client } = require("pg");
require("dotenv").config();

if (!process.env.DATABASE_URL) {
  console.error("DATABASE_URL is required. Set it in .env or your environment.");
  process.exit(1);
}

async function ensureDatabase() {
  const dbUrl = process.env.DATABASE_URL;
  try {
    const testPool = new Pool({ connectionString: dbUrl });
    const testClient = await testPool.connect();
    testClient.release();
    await testPool.end();
  } catch (err) {
    if (err.code === "3D000") {
      try {
        const parsed = new URL(dbUrl);
        const targetDb = parsed.pathname.replace(/^\//, "");
        parsed.pathname = "/postgres";
        const adminClient = new Client({ connectionString: parsed.toString() });
        await adminClient.connect();
        console.log(`Database "${targetDb}" does not exist. Creating it...`);
        await adminClient.query(`CREATE DATABASE "${targetDb.replace(/"/g, '""')}"`);
        await adminClient.end();
        console.log(`Database "${targetDb}" created successfully.`);
      } catch (createErr) {
        console.warn(`Could not automatically create database: ${createErr.message}`);
        throw err;
      }
    } else {
      throw err;
    }
  }
}

async function setup() {
  await ensureDatabase();
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(fs.readFileSync(path.join(__dirname, "schema.sql"), "utf8"));
    await client.query(fs.readFileSync(path.join(__dirname, "seed.sql"), "utf8"));
    await client.query('CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW())');
    if (!(await client.query("SELECT 1 FROM schema_migrations WHERE version='workflows-v1'")).rowCount) {
      await client.query(fs.readFileSync(path.join(__dirname, 'workflows.sql'), 'utf8'));
      await client.query("INSERT INTO schema_migrations(version) VALUES ('workflows-v1')");
    }
    await client.query(fs.readFileSync(path.join(__dirname, 'workflow-seed.sql'), 'utf8'));
    await client.query('COMMIT');
    console.log("Database schema and seed data are ready.");
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

setup().catch((error) => {
  console.error("Database setup error:", error.message);
  process.exit(1);
});


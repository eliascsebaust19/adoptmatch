/** Single-process SQLite persistence. Production requires a durable, private disk.
 * Node 22.13+ supplies node:sqlite; no native dependency download is needed.
 * Use one API process per database file. Multi-instance deployments need a shared DB.
 */
const { DatabaseSync } = require('node:sqlite');
const fs = require('node:fs');
const path = require('node:path');

let filename = process.env.DATABASE_PATH || ':memory:';
if (filename !== ':memory:') {
  filename = path.resolve(filename);
  fs.mkdirSync(path.dirname(filename), { recursive: true });
} else if (process.env.NODE_ENV === 'production') {
  throw new Error('DATABASE_PATH must name a persistent private disk in production.');
}
const db = new DatabaseSync(filename);
if (filename !== ':memory:') fs.chmodSync(filename, 0o600);
db.exec('PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');
if (filename !== ':memory:') db.exec('PRAGMA journal_mode = WAL;');
db.exec(`
  CREATE TABLE IF NOT EXISTS records (
    namespace TEXT NOT NULL, id TEXT NOT NULL, position INTEGER NOT NULL,
    data TEXT NOT NULL, PRIMARY KEY (namespace, id)
  );
  CREATE INDEX IF NOT EXISTS records_order ON records(namespace, position);
  CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS subscription_grants (
    tran_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, granted_at TEXT NOT NULL
  );
`);
let depth = 0;
function transaction(fn) {
  if (depth) return fn();
  db.exec('BEGIN IMMEDIATE'); depth++;
  try { const result = fn(); db.exec('COMMIT'); return result; }
  catch (error) { db.exec('ROLLBACK'); throw error; }
  finally { depth--; }
}
module.exports = { db, transaction, filename };

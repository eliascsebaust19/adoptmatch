const fs = require('fs');
const path = require('path');
const { getPool, initDB, isMemory } = require('../config/db');

async function runSeed() {
  console.log('🌱 Initializing AdoptMatch Seed Data...');
  await initDB();

  if (isMemory()) {
    console.log('✅ In-memory demo data already loaded and ready!');
    process.exit(0);
  }

  try {
    const pool = getPool();
    const seedSqlPath = path.join(__dirname, '../seed.sql');
    const sqlContent = fs.readFileSync(seedSqlPath, 'utf8');

    // Split SQL statements by semicolon
    const statements = sqlContent
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    for (const stmt of statements) {
      if (stmt.toLowerCase().startsWith('use ')) continue;
      await pool.query(stmt);
    }

    console.log('🎉 MySQL database successfully populated with realistic seed data!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Error executing seed SQL:', err);
    process.exit(1);
  }
}

runSeed();

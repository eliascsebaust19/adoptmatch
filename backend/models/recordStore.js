const { db, transaction } = require('./database');

/** Durable records with the same small interface used by the existing controllers. */
module.exports = function createRecordStore(namespace, seeds = []) {
  const decode = (row) => row ? JSON.parse(row.data) : null;
  const find = (id) => decode(db.prepare('SELECT data FROM records WHERE namespace = ? AND id = ?').get(namespace, String(id)));
  const all = () => db.prepare('SELECT data FROM records WHERE namespace = ? ORDER BY position').all(namespace).map(decode);
  const write = (id, value, position) => {
    db.prepare(`INSERT INTO records(namespace, id, position, data) VALUES (?, ?, ?, ?)
      ON CONFLICT(namespace, id) DO UPDATE SET data = excluded.data`)
      .run(namespace, String(id), position, JSON.stringify(value));
    return value;
  };
  const nextPosition = () => Number(db.prepare('SELECT COALESCE(MAX(position), 0) + 1 AS pos FROM records WHERE namespace = ?').get(namespace).pos);
  transaction(() => {
    if (db.prepare('SELECT key FROM metadata WHERE key = ?').get(`seeded:${namespace}`)) return;
    seeds.forEach((value, index) => write(value.id ?? value.tranId, value, index + 1));
    db.prepare('INSERT INTO metadata(key, value) VALUES (?, ?)').run(`seeded:${namespace}`, new Date().toISOString());
  });
  return {
    all, find,
    insert(value, { prepend = false } = {}) {
      return transaction(() => {
        const id = value.id ?? value.tranId;
        if (!id || find(id)) throw new Error(`Duplicate or missing record id in ${namespace}`);
        if (prepend) db.prepare('UPDATE records SET position = position + 1 WHERE namespace = ?').run(namespace);
        return write(id, value, prepend ? 1 : nextPosition());
      });
    },
    update(id, changes) {
      return transaction(() => {
        const current = find(id);
        if (!current) return null;
        return write(id, { ...current, ...changes, id: current.id ?? String(id) },
          db.prepare('SELECT position FROM records WHERE namespace = ? AND id = ?').get(namespace, String(id)).position);
      });
    },
    remove(id) {
      const current = find(id);
      db.prepare('DELETE FROM records WHERE namespace = ? AND id = ?').run(namespace, String(id));
      return current;
    },
  };
};

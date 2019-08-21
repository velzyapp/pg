const assert = require("assert");

class Query{
  constructor(args){
    assert(args.db, "No DB means nothing for you!")
    this.db = args.db;
    this.tableName = args.tableName;
  }
  async save(document) {
    assert.ok(this.tableName, "Need a table name");
    assert.ok(document, "There's no document here genius...");

    const sql = "select * from velzy.save($1, $2)";
    const result = await this.db.oneOrNone(sql, [this.tableName, document]);
    return result.res;
  }

  async startsWith(key, term){
    const sql = "select * from velzy.starts_with($1, $2, $3)";
    const result = await this.db.any(sql, [this.tableName, key, term]);

    return result.map(r => {
      const out = r.body;
      out.created_at = out.created_at || r.created_at;
      return out;
    })
  }
  async endsWith(key, term){
    const sql = "select * from velzy.ends_with($1, $2, $3)";
    const result = await this.db.any(sql, [this.tableName, key, term]);

    return result.map(r => {
      const out = r.body;
      out.created_at = out.created_at || r.created_at;
      return out;
    })
  }

  async modify(id, mod){
    const sql = "select * from velzy.modify($1, $2, $3)"
    const result = await this.db.oneOrNone(sql, [this.tableName, id, mod]);
    return result.res;
  }

  async delete(id) {
    const sql = "select * from velzy.delete($1, $2)";
    const result = await this.db.one(sql, [this.tableName, id]);
    return {
      id: 1,
      deleted: true
    };
  }

  async get(id) {
    const sql = "select * from velzy.get($1, $2)";
    const result = await this.db.one(sql, [this.tableName, parseInt(id)]);
    return result.res;

  }

  async find(criteria) {
    const sql = "select * from velzy.find($1, $2)";
    const result =  await this.db.any(sql, [this.tableName, criteria]);

    return result.map(r => {
      const out = r.body;
      out.created_at = out.created_at || r.created_at;
      return out;
    })
  }
  async query(criteria=null, limit = 100, page = 0, orderBy = 'id', orderDir = 'asc') {
    const sql = "select * from velzy.query($1, $2, $3, $4, $5, $6)";
    const result =  await this.db.any(sql, [this.tableName, criteria, limit, page, orderBy, orderDir]);

    return result.map(r => {
      const out = r.body;
      out.created_at = out.created_at || r.created_at;
      return out;
    })
  }

  async fuzzy(key, term) {
    const sql = "select * from velzy.fuzzy($1, $2, $3)";
    const result =  await this.db.any(sql, [this.tableName, key, term]);

    return result.map(r => {
      const out = r.body;
      out.created_at = out.created_at || r.created_at;
      return out;
    })
  }

  async find_one(criteria) {
    const sql = "select * from velzy.find_one($1, $2)";
    const result = await  this.db.oneOrNone(sql, [this.tableName, criteria]);
    result.body.created_at = result.body.created_at || result.created_at
    return result.body;
  }

  async list(tableName) {
    const sql = `select id, body, created_at, updated_at from velzy.${tableName} order by created_at DESC limit 100`;
    const result = await this.db.any(sql, this.tableName);
    return result.result.map(r => {
      return r.body
    })
  }

  async search(term) {
    const sql = "select * from velzy.search($1, $2)";
    const res = await this.db.any(sql, [this.tableName, term])

    return res.map(r => {
      return r.result
    })
  }
}

module.exports = Query;

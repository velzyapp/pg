const pgp = require('pg-promise')({});
const db = pgp(process.env.DATABASE_URL);
const Listener = require("./lib/listener");
const Query = require("./lib/query");


class Velzy {
  constructor() {
    const handler = {
      get(target, key) {
        if (key in target) {
          return target[key]
        } else {
          return new Query({ tableName: key, db: db });
        }
      }
    }
    var proxy = new Proxy(this, handler);
    return proxy;
  }
  async initListener() {
    this.listener = new Listener(db);
    try {
      await this.listener.connect(db);
      return { success: true, message: "Listening for velzy.received" }
    } catch (err) {
      throw new Error("Can't connect listener: ", err.message)
    }

  }
  wireEvent(emitter) {
    //sigh
    const self = this;
    //this fires when a record is updated in PG
    this.listener.on("velzy.received", async args => {
      //this can be an add/update/delete OR a table creation
      if (args.action === "table_created") {
        console.log("Looks like we just created a table!", args.tableName);
        emitter.emit("velzy.table-created", {
          table: args.tableName
        });
      } else {
        //products:update:1
        console.log("A record was just saved...", args);
        const sql = `select velzy.get($1, $2)`;
        const record = await db.oneOrNone(sql, [args.tableName, args.id]);

        emitter.emit("velzy.changeset", {
          tableName: args.tableName,
          action: args.action,
          id: args.id,
          record: record.get
        });
      }
    });
  }

  async run(sql, params = []) {
    return await db.any(sql, params);
  }
  async first(sql, params = []) {
    return await db.oneOrNone(sql, params);
  }

  async tableList() {
    const sql = "select * from velzy.table_list();"
    return db.any(sql);
  }
  close() {
    db.$pool.end();
  }
}


module.exports = new Velzy();

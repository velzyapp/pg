const EventEmitter = require("events").EventEmitter;
//helpful utility
const sleep = (ms) => new Promise(res => setTimeout(res, ms));

class Listener extends EventEmitter {
  constructor(db) {

    super();
    this.db = db;
    this.retries = 10;
    this.client = null;
  }
  retryConnection() {

    if (this.retries > 0) {
      console.error(`DB Connection has been lost; waiting 5 seconds and then trying again. Will try another ${this.retries} times before giving up`);
      sleep(5000).then(() => this.connect);
      this.retries += 1;
    }

  }

  async connect() {
    try {
      //dedicated connection for the reactor
      const connection = await this.db.connect({ direct: true, onConnectionLost: this.retryConnection });
      const client = connection.client;
      const self = this;
      //set the notifications
      client.on("notification", async notification => {
        const splits = notification.payload.split(":");
        self.emit("velzy.received", {
          tableName: splits[0],
          action: splits[1],
          id: splits[2]
        })
      });

      //set the listen command for the connection
      await connection.none("LISTEN $1~", "velzy.change");

    } catch (err) {
      console.error(err)
      throw new Error("Can't connect to the DB: ", err.message);
    }
  }

}

module.exports = Listener;

const Schema = require("../lib/schema");

describe.only("GraphQL stuff", () => {
  it("Prints from regular JSON", async () => {
    const schema = await Schema.build();
    console.log(schema);
  });
})

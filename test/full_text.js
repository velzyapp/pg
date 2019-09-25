describe("Full text search", async () => {
  before(async () => {
    await Velzy.run("drop table if exists customers");
    await Velzy.save("customers", { first: "Steve", last: "Chuckles", email: "thing@example.com", description: "Super cheesy poof thingy pop" });
  });

  it("searches based on caseless first name", async () => {
    const results = await Velzy.search("customers", "steve")
    assert.equal(1, results.length)
  });

  it("searches based on caseless last name", async () => {
    const results = await Velzy.search("customers", "chuckles")
    assert.equal(1, results.length)
  });
  it("splits the email so we can query by domain", async () => {
    const results = await Velzy.search("customers", "example")
    assert(results.length > 0)
  });
})

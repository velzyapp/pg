describe("The basics", async () => {
  before(async () => {
    await Velzy.run("drop table if exists velzy.orders");
    await Velzy.orders.save({ number: "1001", total: 10.00, email: "jill@test.com", items: [{sku: "test", price: 10.00, quantity: 1, name: "Test Product"}] });
  });

  it("finds the order by number - many results", async () => {
    const docs = await Velzy.orders.find({number: "1001"});
    assert(docs.length > 0, "No docs returned")
    assert.equal("1001", docs[0].number);
  });

  it("finds single order by number", async () => {
    const docs = await Velzy.orders.find_one({number: "1001"});
    assert.equal("1001", docs.number);
  });

  it("does a fuzzy search on email", async () => {
    const docs = await Velzy.orders.fuzzy("number", "10");
    assert(docs.length > 0, "No docs returned")
  });

})

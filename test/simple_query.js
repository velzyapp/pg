describe("The basics", async () => {
  before(async () => {
    await Velzy.run("drop table if exists orders");
    await Velzy.save("orders", { number: "1001", total: 10.00, email: "jill@test.com", items: [{ sku: "test", price: 10.00, quantity: 1, name: "Test Product" }] });
    await Velzy.save("orders", { number: "1002", total: 10.00, email: "bob@test.com", items: [{ sku: "test", price: 10.00, quantity: 1, name: "Test Product" }] });
    await Velzy.save("orders", { number: "1003", total: 10.00, email: "crane@test.com", items: [{ sku: "test", price: 10.00, quantity: 1, name: "Test Product" }] });
  });

  it("finds the order by number - many results", async () => {
    const docs = await Velzy.query("orders",{ where: {number: "1001" }});
    assert.equal(1, docs.length);
    assert.equal("1001", docs[0].body.number);
  });

  it("finds single order by number", async () => {
    const docs = await Velzy.find_one("orders",{ number: "1001" });
    assert.equal("1001", docs.body.number);
  });

  it("does a fuzzy search on email", async () => {
    const docs = await Velzy.contains("orders","number", "10");
    assert(docs.length > 0, "No docs returned")
  });

  it("limits based on page size", async () => {
    const docs = await Velzy.query("orders",{pageSize: 1});
    assert(docs.length === 1, "No docs returned")
  })
  it("sorts ascending based on ID by default", async () => {
    const docs = await Velzy.query("orders",{orderDir: 'asc'});
    assert(docs.length === 3, "No docs returned")
    assert.equal(docs[0].id, 1)
    assert.equal(docs[1].id, 2)
    assert.equal(docs[2].id, 3)
  })
  it("sorts descending based on ID", async () => {
    const docs = await Velzy.query("orders",{orderDir: 'desc'});
    assert(docs.length === 3, "No docs returned")
    assert.equal(docs[0].id, 3)
    assert.equal(docs[1].id, 2)
    assert.equal(docs[2].id, 1)
  })
  it("filters using where", async () => {
    const docs = await Velzy.query("orders",{where: {email: "jill@test.com"}});
    assert(docs.length === 1, "No docs returned")
  })
})

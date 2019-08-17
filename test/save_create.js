describe("The basics", async () => {
  before(async () => {
    await Velzy.run("drop table if exists velzy.products");
    await Velzy.products.save({sku: "TEST", price: 10.00, description: "A test thing"});
  });

  it("creates the table and saves the doc and we can get at it", async () => {
    const doc = await Velzy.products.get(1);
    assert.equal(1, doc.id)
  });
})

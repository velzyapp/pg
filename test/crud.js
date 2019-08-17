describe("CRUD Ops", async () => {
  before(async () => {
    await Velzy.run("drop table if exists velzy.products");
    await Velzy.products.save({ id: 100, sku: "TEST2", price: 10.00, description: "Another test thing" });
  });

  it("updates the doc price with a quick, non-destructive modify", async () => {
    const doc = await Velzy.products.modify(100, {price: 50.00});
    const saved = await Velzy.products.get(100);
    assert.equal(50, saved.price)
  });

  it("says goodbye and deletes", async () => {
    await Velzy.products.delete(100);
    const found = await Velzy.products.get(100);
    assert(!found)
  })
})

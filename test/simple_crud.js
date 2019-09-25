describe("CRUD Ops", async () => {
  before(async () => {
    await Velzy.run("drop table if exists velzy.puppies");
    await Velzy.save("puppies", { id: 100, name: "Larry", goodBoy: false });
  });

  it("updates the doc price with a quick, non-destructive modify", async () => {
    const doc = await Velzy.modify("puppies",100, { goodBoy: true });
    const saved = await Velzy.get("puppies",100);
    assert.equal(true, saved.body.goodBoy)
  });

  it("says goodbye and deletes", async () => {
    await Velzy.delete("puppies",100);
    const found = await Velzy.get("puppies",100);
    assert(!found)
  })
})

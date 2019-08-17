describe("Table listing", async () => {
  before(async () => {
    await Velzy.run("drop table if exists velzy.puppies");
    await Velzy.puppies.save({ name: "skippy" });
  });

  it("there's at least one table with a row_count", async () => {
    const tables = await Velzy.tableList();
    assert(tables.length > 0);
    assert(tables.find(t => t.table_name === "puppies"))
  });
})

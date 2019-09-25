describe("Table listing and sample sets", async () => {
  before(async () => {
    await Velzy.run("drop table if exists puppies");
    await Velzy.save("puppies", { name: "skippy" });
  });

  it("there's at least one table with a row_count", async () => {
    const tables = await Velzy.tableList();
    assert(tables.length > 0);
    assert(tables.find(t => t.table_name === "puppies"))
  });

  // it("returns a sampling of data used on app spinup", async () => {
  //   const sample = await Velzy.getSampleSet();
  //   assert(sample.length > 0)
  // });
})

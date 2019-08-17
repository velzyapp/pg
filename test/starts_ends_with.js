describe("Starts and Ends with - I don't know if this is a good idea", async () => {
  let friend = null;
  before(async () => {
    await Velzy.run("drop table if exists velzy.friends");
    await Velzy.friends.save({ name: "Bippy" });
    friends = await Velzy.friends.startsWith("name", "Bi");
    friends2 = await Velzy.friends.endsWith("name", "py");
  });

  it("returns our friend using start", () => {
    assert(friends.length > 0)
  });
  it("returns our friend using end", () => {
    assert(friends2.length > 0)
  });
})

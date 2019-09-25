describe("Starts and Ends with - I don't know if this is a good idea", async () => {
  let friend = null;
  before(async () => {
    await Velzy.run("drop table if exists friends");
    await Velzy.save("friends", { name: "Bippy" });
    friends = await Velzy.startsWith("friends","name", "Bi");
    friends2 = await Velzy.endsWith("friends","name", "py");
  });

  it("returns our friend using start", () => {
    assert(friends.length > 0)
  });
  it("returns our friend using end", () => {
    assert(friends2.length > 0)
  });
})

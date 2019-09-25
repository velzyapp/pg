
describe("GraphQL bits", () => {
  it("It creates a root query", async () => {
    const schema = await Velzy.graphQLSchema();
    //this is kind of a lame assertion but I suppose I just want to be
    //sure that it works :) it's a visual thing, so a runtime error
    //might not make a difference
    assert(schema, "No schema returned");
  })
})

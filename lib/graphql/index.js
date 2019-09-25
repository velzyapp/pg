const {
  GraphQLObjectType,
  GraphQLID,
  GraphQLString,
  GraphQLBoolean,
  GraphQLFloat,
  GraphQLInt,
  GraphQLList,
  GraphQLSchema
} = require("graphql");
const {GraphQLDateTime} = require("graphql-iso-date");



const { GraphQLJSON } = require("graphql-type-json");
const SearchResultType = new GraphQLObjectType({
  name: "SearchResult",
  fields: () => ({
    result: { type: GraphQLJSON },
    rank: { type: GraphQLFloat }
  })
});

const RecordType = new GraphQLObjectType({
  name: "Record",
  fields: () => ({
    id: { type: GraphQLInt },
    body: { type: GraphQLJSON },
    created_at: { type: GraphQLDateTime },
    updated_at: { type: GraphQLDateTime },
  })
});


const getRootMutation = (db) => ({
  name: "RootMutation",
  type: "Mutation",
  fields: {
    save: {
      type: GraphQLJSON,
      description: "This is the main way to get data into Velzy as it will create a document table for you on the fly",
      args: {
        collection: { type: GraphQLString },
        body: { type: GraphQLJSON }
      },
      resolve(_, args) {
        return db.save(args.collection, args.body);
      }
    },
    modify: {
      type: GraphQLJSON,
      description: "Modifies a document with a non-destructive overwite. Specify your key and if it's present, it'll get written, otherwise added.",
      args: {
        collection: { type: GraphQLString },
        id : {type: GraphQLID},
        modification: { type: GraphQLJSON }
      },
      resolve(_, args) {
        return db.modify(args.collection, args.id, args.modification);
      }
    },
    delete : {
      type: GraphQLJSON,
      description: "Deletes a document using the passed in ID",
      args: {
        tableName: { type: GraphQLString },
        id: { type: GraphQLID }
      },
      resolve(_, args) {
        return db[args.tableName].delete(args.id);
      }
    }
  }
});

const getRootQuery = (db) => ({
  name: "RootQuery",
  type: "Query",
  fields: {
    tableList : {
      type: GraphQLJSON,
      description: "Get a list of all tables within Velzy",
      resolve(_, args){
        return db.tableList();
      }
    },
    query: {
      type: new GraphQLList(GraphQLJSON),
      description: `Basic filter query that allows paging and ordering`,
      args: {
        collection: {type: GraphQLString, required: true},
        pageSize: { type: GraphQLID, defaultValue: 100 },
        where: { type: GraphQLJSON },
        orderBy: { type: GraphQLString, defaultValue: "id" },
        orderDir: { type: GraphQLString, defaultValue: "asc" },
        page: { type: GraphQLInt, defaultValue: 0 }
      },
      async resolve(_, args) {
        const res = await  db.query(args.collection, {
          criteria: args.where,
          limit: args.pageSize,
          page: args.page,
          orderBy: args.orderBy,
          orderDir: args.orderDir
        });
        return res.map(x => x.body)
      }
    },
    topNRecords: {
      type: GraphQLJSON,
      description: "Returns the top n records (default being 100) for a given table, sorted by id descending",
      args: {
        tableName: {type: GraphQLString, required: true},
        limit: {type: GraphQLInt, defaultValue: 100}
      },
      async resolve(_, args){
        const res =  await db.query(args.tableName, {pageSize: args.limit, orderDir: "desc"});
        return res.map(x => x.body)
      }
    },
    search : {
      type: GraphQLJSON,
      description: "Full text search over a given table",
      args: {
        tableName: { type: GraphQLString, required: true },
        term: { type: GraphQLString, required: true }
      },
      resolve(_,args){
        return db.search(args.tableName, args.term);
      }
    },
    find_one : {
      type: GraphQLJSON,
      description: "Return a single record for the given criteria",
      args: {
        tableName: { type: GraphQLString, required: true },
        criteria: { type: GraphQLJSON, required: true }
      },
      resolve(_,args){
        return db.find_one(args.tableName, args.criteria);
      }
    },
    find_one : {
      type: GraphQLJSON,
      description: "Return a single record for the given criteria",
      args: {
        tableName: { type: GraphQLString, required: true },
        criteria: { type: GraphQLJSON, required: true }
      },
      resolve(_,args){
        return db.find_one(args.tableName, args.criteria);
      }
    },
    contains : {
      type: GraphQLJSON,
      description: "A fuzzy query that looks for a full wild-card value for a given key",
      args: {
        tableName: { type: GraphQLString, required: true },
        key: { type: GraphQLString, required: true },
        term: { type: GraphQLString, required: true }
      },
      resolve(_,args){
        return db.contains(args.tableName, args.key, args.term);
      }
    },
    startsWith : {
      type: GraphQLJSON,
      description: "This is a sargeable query that creates a field on the fly, indexing it for a faster query. USE IN DEV ONLY as it alters the structure of your table.",
      args: {
        tableName: { type: GraphQLString, required: true },
        key: { type: GraphQLString, required: true },
        term: { type: GraphQLString, required: true }
      },
      resolve(_,args){
        return db.startsWith(args.tableName, args.key, args.term);
      }
    },
    endsWith : {
      type: GraphQLJSON,
      description: "This is a sargeable query that creates a field on the fly, indexing it for a faster query. USE IN DEV ONLY as it alters the structure of your table.",
      args: {
        tableName: { type: GraphQLString, required: true },
        key: { type: GraphQLString, required: true },
        term: { type: GraphQLString, required: true }
      },
      resolve(_,args){
        return db.endsWith(args.tableName, args.key, args.term);
      }
    }
  }
});

exports.build = async function (db, cb = null){

  // const client = new Client({ connectionString: process.env.DATABASE_URL });
  // await client.connect();
  // const pubsub = new PostgresPubSub({ client });

  //const tables = await db.getSampleSet();
  let rootQuery = getRootQuery(db);
  let rootMutation = getRootMutation(db);
  // for (table of tables) {
  //   const type = generator.createTableType(table);
  //   const filterType = generator.createTableFilter(table);

  //   rootQuery = generator.createTableQueries(rootQuery, type, filterType, table, db);
  //   rootMutation = generator.createTableMutations(rootMutation, type, table, db);
  // }
  const properRootQuery = new GraphQLObjectType(rootQuery);
  const properRootMutation = new GraphQLObjectType(rootMutation);
  //const subRoot = new GraphQLObjectType(getRootSubs(db));

  if(cb)cb({ query: properRootQuery, mutation: properRootMutation })
  return new GraphQLSchema({ query: properRootQuery, mutation: properRootMutation });
}

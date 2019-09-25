const _ = require("underscore");
const Velzy = require("../../index");

const {
  GraphQLObjectType,
  GraphQLInputObjectType,
  GraphQLID,
  GraphQLString,
  GraphQLBoolean,
  GraphQLFloat,
  GraphQLInt,
  GraphQLList,
  GraphQLSchema
} = require("graphql");
const {
  GraphQLDate,
  GraphQLTime,
  GraphQLDateTime
} = require("graphql-iso-date");

const { GraphQLJSON, GraphQLJSONObject } = require("graphql-type-json");


const isInt = n => Number(n) === n && n % 1 === 0;
const isFloat = n => Number(n) === n && n % 1 !== 0;

const resolveType = ({key, val}) => {
  let out = {type: GraphQLString};

  if (key === "id") out = {type: GraphQLID};
  else if (_.isDate(val)) out = {type: GraphQLDateTime};
  else if (_.isBoolean(val)) out = {type: GraphQLBoolean};
  else if (isFloat(val)) out = {type: GraphQLFloat};
  else if (isInt(val)) out = { type: GraphQLInt };
  else if (_.isArray(val)) out = { type: GraphQLJSON};
  // uhhhh errrr
  else if (_.isObject(val)) out = {type: GraphQLJSON};
  //this is... damn. would need to figure out how to deal with this
  return out;
};

const getFields = (table) => {
  const fields = {
    id: { type: GraphQLID }
  }
  const keys = Object.keys(table.example);
  for (key of keys) {
    fields[key] = resolveType({ key: key, val: table.example[key] })
  }
  return fields;
}
exports.createTableType = function(table){
  //the type will be something like...
  const fields = getFields(table);
  return new GraphQLObjectType({
    name: `${table.formatted}Type`,
    fields: () => (fields)
  });
  return out;
}
exports.createTableFilter = function (table) {
  //the type will be something like...
  const fields = getFields(table);
  return new GraphQLInputObjectType({
    name: `${table.formatted}Filter`,
    fields: () => (fields)
  });
}

exports.createTableQueries = function (root, type, filterType, table, db){
  root.fields[`${table.formatted}Query`] = ({
    type: new GraphQLList(type),
    description: `Basic filter query that allows paging and ordering on ${table.formatted}`,
    args: {
      pageSize: { type: GraphQLID, defaultValue: 100 },
      where: { type: filterType },
      orderBy: { type: GraphQLString, defaultValue: "id" },
      orderDir: { type: GraphQLString, defaultValue: "asc" },
      page: { type: GraphQLInt, defaultValue: 0 }
    },
    resolve(_, args) {
      return db[table.table_name].query({
        criteria: args.where,
        limit: args.pageSize,
        page: args.page,
        orderBy: args.orderBy,
        orderDir: args.orderDir
      });
    }
  })

  root.fields[`${table.formatted}ById`] = ({
    type: type,
    description: `Primary key lookup on ${table.formatted}`,
    args: { id: { type: GraphQLInt } },
    async resolve(_, args) {
      const res = await db[table.table_name].get(args.id);
      return res ? res.body : null;
    }
  });

  root.fields[`${table.formatted}Contains`] = ({
    type: new GraphQLList(type),
    description: "This is a wildcard search which performs a full-table scan over the given key. Not ideal (and, in fact, bad) for larger dbs.",
    args: {
      key: { type: GraphQLString },
      term: { type: GraphQLString }
    },
    async resolve(_, args) {
      return db[table.table_name].fuzzy(args.key, args.term);
    }
  });
  root.fields[`${table.formatted}StartsWith`] = ({
    type: new GraphQLList(type),
    description: "This is a schema-modifying query that will create a separate column on your doc table. Only use in dev.",
    args: {
      key: { type: GraphQLString },
      term: { type: GraphQLString }
    },
    async resolve(_, args) {
      return db[table.table_name].startsWith(args.key, args.term);
    }
  });
  root.fields[`${table.formatted}EndsWith`] = ({
    type: new GraphQLList(type),
    description: "This is a schema-modifying query that will create a separate column on your doc table. Only use in dev.",
    args: {
      key: { type: GraphQLString },
      term: { type: GraphQLString }
    },
    async resolve(_, args) {
      return db[table.table_name].endsWith(args.key, args.term);
    }
  });

  root.fields[`${table.formatted}TextSearch`] = ({
    type: new GraphQLList(type),
    description: "This a full-text index search over specific columns in your documents which are auto-indexed according to a naming convention. Currently, the keys are 'name','email','first','first_name','last','last_name','description','title','city','state','address','street', and 'company'",
    args: {
      term: { type: GraphQLString }
    },
    async resolve(_, args) {
      return db[table.table_name].search(args.term);
    }
  });

  return root;
}

exports.createTableMutations = function(root, type, table, db){

  const fields = getFields(table);

  if(fields.id) delete(fields.id);
  if(fields.created_at) delete(fields.created_at);
  if(fields.updated_at) delete(fields.updated_at);

  root.fields[`${table.formatted}Save`] = {
    type: type,
    args: fields,
    description: `Saves a document doing a full replace if the document exists with {id: X} where X is whatever you pass in. If you want a partial update, use ${table.formatted}Modify`,
    resolve(_, args) {
      return db[table.table_name].save(args);
    }
  }
  root.fields[`${table.formatted}Modify`] = {
    type: type,
    description: "Updates *ONLY* the JSON bits that you add here using a merge routine, does not replace",
    args: {
      id : {type: GraphQLID},
      mod: {type: GraphQLJSON}
    },
    resolve(_, args) {
      console.log(args);
      return db[table.table_name].modify(args.id, args.mod);
    }
  }

  root.fields[`${table.formatted}Delete`] = {
    type: type,
    description: "Deletes based on ID",
    args: {
      id: {type: GraphQLID}
    },
    resolve(_, args) {
      return db[table.table_name].delete(args.id);
    }
  }
  return root;
}

exports.build = function(rootQuery, rootMutations, tables){

  for(table of tables){
    const type = this.createTableType(table);
    const filterType = this.createTableFilter(table);

    rootQuery = this.createTableQueries(rootQuery,type,filterType,table);
    rootMutations = this.createTableMutations(rootMutations,type,table);
  }

  return {query: rootQuery, mutations: rootMutations}
}

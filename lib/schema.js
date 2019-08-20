const { graphql, buildSchema, GraphQLSchema, GraphQLObjectType, GraphQLString, printSchema} = require('graphql');
const Velzy = require("../index");
const s = require("underscore.string");
const _ = require("underscore");

const isInt = (n) => Number(n) === n && n % 1 === 0;
const isFloat = (n) =>  Number(n) === n && n % 1 !== 0;

const resolveTypes = (data) => {
  const keys = _.keys(data);
  const out = [];
  for(const k of keys) {
    let val = data[k];
    if(k === "id") out.push(`\t${k}: ID!`)
    else if (_.isDate(val)) out.push(`\t${k}: Date`)
    else if (_.isBoolean(val)) out.push(`\t${k}: Boolean`)
    else if (isFloat(val)) out.push(`\t${k}: Float`)
    else if (isInt(val)) out.push(`\t${k}: Int`)
    else if (_.isArray(val)) out.push(`\t${k}: [${s.titleize(k)}]`) // uhhhh errrr
    else if (_.isObject(val)) out.push(`\t${k}: ${s.titleize(k)}`) //this is... damn. would need to figure out how to deal with this
    else out.push(`\t${k}: String`)
  }
  return out.join("\n")
}

const getTablesAndRecords = async () => {
  const tables = await Velzy.tableList();
  //eek! Executing in a loop seems kind of horrible but
  //we'll figure it out
  const out = [];
  for (t of tables) {
    const sql = `select body from velzy.${t.table_name} limit 1`
    const res = await Velzy.first(sql);
    out.push({
      table_name: t.table_name,
      formatted: s.titleize(t.table_name),
      example: res.body
    })
  }
  return out;
}

exports.build = async function () {
  //load the tables and a representative record?
  const tableSet = await getTablesAndRecords();
  const out = [];
  for(t of tableSet){
    const props = resolveTypes(t.example);
    out.push(`
type ${t.formatted} {
${props}
}
    `)
  }

  //not let's roll again, this time building queries
  for(t of tableSet){
    let props = _.keys(t.example).join("\n")
    out.push(`
query ${t.formatted}ById($id: ID!){
  ${t.table_name}(id: $id) {
    ${props}
  }
}
query ${t.formatted} {
  ${t.table_name}: [${t.formatted}]
}
    `)
  }
  return out.join("\n")
}


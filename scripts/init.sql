set client_min_messages TO WARNING;
drop schema if exists velzy cascade;
create schema if not exists velzy;
create extension pg_stat_statements with schema velzy;
create extension pgcrypto with schema velzy;

--add tables for users, permissions and possibly API keys

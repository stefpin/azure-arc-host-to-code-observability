-- MiniBank PostgreSQL 16 objects on APP-RHEL. Run as the postgres superuser with two psql variables:
--   read -rsp 'New minibank_app password: ' APP_PW; echo; read -rsp 'New postgres_exporter password: ' EXP_PW; echo
--   sudo -u postgres psql -v ON_ERROR_STOP=1 -v app_pw="$APP_PW" -v exp_pw="$EXP_PW" -d postgres < db/postgres/01-minibank-db.sql
--   unset APP_PW EXP_PW
-- Before: postgresql.conf must contain  shared_preload_libraries = 'pg_stat_statements'  (then restart PostgreSQL).
-- Safe to run again (it resets the two passwords).
\set ON_ERROR_STOP on

-- 1) roles: minibank_app (minibank-fraud) and postgres_exporter (Route B exporter + Route A dbsnap)
SELECT NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'minibank_app')       AS need_app,
       NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres_exporter') AS need_exp \gset
\if :need_app
CREATE ROLE minibank_app LOGIN;
\endif
\if :need_exp
CREATE ROLE postgres_exporter LOGIN;
\endif
ALTER ROLE minibank_app WITH LOGIN PASSWORD :'app_pw';
ALTER ROLE postgres_exporter WITH LOGIN PASSWORD :'exp_pw';
GRANT pg_monitor TO postgres_exporter;

-- 2) database minibank, owned by minibank_app
SELECT 'CREATE DATABASE minibank OWNER minibank_app'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'minibank') \gexec

-- 3) table and extension inside database minibank
\connect minibank
CREATE TABLE IF NOT EXISTS fraud_check (
    id           bigserial     PRIMARY KEY,
    reference_no varchar(20)   NOT NULL,
    channel      varchar(10)   NOT NULL,       -- TRANSFER or QRIS
    amount       numeric(18,2) NOT NULL,
    score        int           NOT NULL,
    decision     text          NOT NULL,       -- APPROVE or REVIEW
    created_at   timestamptz   NOT NULL DEFAULT now()
);
ALTER TABLE fraud_check OWNER TO minibank_app;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;   -- top SQL for Route A (pg-snap.sql)
GRANT CONNECT ON DATABASE minibank TO postgres_exporter;
\echo 'MiniBank PostgreSQL objects are ready.'

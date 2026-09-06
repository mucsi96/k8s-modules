\getenv app_user APP_SCHEMA
\getenv schema APP_SCHEMA
\getenv app_password APP_PASSWORD
\getenv database POSTGRES_DB

-- GRANT updates a shared database ACL; serialize parallel schema provisioning.
SELECT pg_advisory_xact_lock(hashtext('k8s-modules'), hashtext('setup_postgres_schema'));

SELECT format('CREATE ROLE %I LOGIN', :'app_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user')
\gexec
SELECT format(
  'DO $check$ BEGIN IF EXISTS (SELECT FROM pg_roles WHERE rolname = %L AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)) THEN RAISE EXCEPTION ''Refusing to reuse privileged role %%'', %L; END IF; END $check$',
  :'app_user', :'app_user'
) \gexec
SELECT format(
  'ALTER ROLE %I WITH LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
  :'app_user', :'app_password'
) \gexec
SELECT format('GRANT CONNECT, CREATE ON DATABASE %I TO %I', :'database', :'app_user') \gexec
SELECT format('CREATE SCHEMA IF NOT EXISTS %I AUTHORIZATION %I', :'schema', :'app_user') \gexec
SELECT format('REVOKE ALL ON SCHEMA %I FROM PUBLIC', :'schema') \gexec
SELECT format('ALTER ROLE %I IN DATABASE %I SET search_path TO %I, public', :'app_user', :'database', :'schema') \gexec

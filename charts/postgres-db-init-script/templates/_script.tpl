{{- define "postgres-db-init-script.script" -}}
#!/usr/bin/env bash

set -o errexit
set -o nounset

function parse_dsn {
    DSN="$1"
    DSN="${DSN#"postgresql://"}"
    DSN="${DSN#"postgres://"}"
    echo -n "$DSN" | sed -E 's/:|@|\/|\?/ /g'
}

function get_dsn_user {
    IFS=' ' read -ra DSN <<< "$(parse_dsn $1)"
    echo -n ${DSN[0]} | sed -E -e 's/%%/%/g' -e 's/%40/@/g'
}

function get_dsn_password {
    IFS=' ' read -ra DSN <<< "$(parse_dsn $1)"
    echo -n ${DSN[1]}
}

function get_dsn_host {
    IFS=' ' read -ra DSN <<< "$(parse_dsn $1)"
    echo -n ${DSN[2]}
}

function get_dsn_port {
    IFS=' ' read -ra DSN <<< "$(parse_dsn $1)"
    echo -n ${DSN[3]}
}

function get_dsn_db {
    IFS=' ' read -ra DSN <<< "$(parse_dsn $1)"
    echo -n ${DSN[4]}
}

function create_db {
    DB="$1"

    if [ "$(psql -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB';")" = "1" ]; then
        echo "Database $DB exists"
    else
        echo "Database $DB doesn't exist, creating..."
        psql -c "CREATE DATABASE $DB;"
        echo "Database $DB was created"
    fi
}

function create_user {
    DB="$1"
    USER="$2"
    PASSWORD="$3"

    if [ "$(psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$USER';")" = "1" ]; then
        echo "User $USER exists"
    else
        echo "User $USER doesn't exist, creating..."
        psql -c "CREATE USER $USER WITH PASSWORD '$PASSWORD';"
        echo "User $USER was created"
    fi

    psql -o /dev/null -ac "GRANT CONNECT ON DATABASE $DB TO $USER"
}

: ${NP_ADMIN_DSN:=""}
: ${NP_MIGRATIONS_RUNNER_DSN:=""}
: ${NP_MIGRATIONS_RUNNER_USER:=""}
: ${NP_MIGRATIONS_RUNNER_PASSWORD:=""}
: ${NP_SERVICE_DSN:=""}
: ${NP_SERVICE_USER:=""}
: ${NP_SERVICE_PASSWORD:=""}

if [ ! -z "$NP_ADMIN_DSN" ]; then
    export PGUSER="$(get_dsn_user "$NP_ADMIN_DSN")"
    export PGPASSWORD="$(get_dsn_password "$NP_ADMIN_DSN")"
    export PGHOST="$(get_dsn_host "$NP_ADMIN_DSN")"
    export PGPORT="$(get_dsn_port "$NP_ADMIN_DSN")"
    export PGDATABASE="$(get_dsn_db "$NP_ADMIN_DSN")"
else
    export PGUSER="${NP_ADMIN_USER:-"postgres"}"
    export PGPASSWORD="$NP_ADMIN_PASSWORD"
    export PGHOST="$NP_POSTGRES_HOST"
    export PGPORT="$NP_POSTGRES_PORT"
    export PGDATABASE="${NP_POSTGRES_DATABASE:-"postgres"}"
fi

NP_SCHEMA="${NP_SCHEMA:-"public"}"

if [ ! -z "$NP_MIGRATIONS_RUNNER_DSN" ]; then
    NP_DATABASE="$(get_dsn_db "$NP_MIGRATIONS_RUNNER_DSN")"
    NP_MIGRATIONS_RUNNER_USER="$(get_dsn_user "$NP_MIGRATIONS_RUNNER_DSN")"
    NP_MIGRATIONS_RUNNER_PASSWORD="$(get_dsn_password "$NP_MIGRATIONS_RUNNER_DSN")"
fi

create_db "$NP_DATABASE"

export PGDATABASE="$NP_DATABASE"

if [ ! -z "$NP_MIGRATIONS_RUNNER_USER" ] && [ ! -z "$NP_MIGRATIONS_RUNNER_PASSWORD" ]; then
    NP_MIGRATIONS_RUNNER_USER="${NP_MIGRATIONS_RUNNER_USER%@*}"

    create_user "$NP_DATABASE" "$NP_MIGRATIONS_RUNNER_USER" "$NP_MIGRATIONS_RUNNER_PASSWORD"

    psql -tA <<EOF | psql -o /dev/null -a
SELECT format(
'ALTER TABLE %I.%I OWNER TO %I;',
table_schema,
table_name,
'$NP_MIGRATIONS_RUNNER_USER'
)
FROM information_schema.tables
WHERE table_schema = '$NP_SCHEMA' AND table_type = 'BASE TABLE';
EOF
fi

if [ ! -z "$NP_SERVICE_DSN" ]; then
    NP_SERVICE_USER="$(get_dsn_user "$NP_SERVICE_DSN")"
    NP_SERVICE_PASSWORD="$(get_dsn_password "$NP_SERVICE_DSN")"
fi

if [ ! -z "$NP_SERVICE_USER" ] && [ ! -z "$NP_SERVICE_PASSWORD" ]; then
    NP_SERVICE_USER="${NP_SERVICE_USER%@*}"

    create_user "$NP_DATABASE" "$NP_SERVICE_USER" "$NP_SERVICE_PASSWORD"

    psql -o /dev/null -a <<EOF
GRANT SELECT,INSERT,UPDATE,DELETE,TRUNCATE ON ALL TABLES IN SCHEMA $NP_SCHEMA TO $NP_SERVICE_USER;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA $NP_SCHEMA TO $NP_SERVICE_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA $NP_SCHEMA GRANT SELECT,INSERT,UPDATE,DELETE,TRUNCATE ON TABLES TO $NP_SERVICE_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA $NP_SCHEMA GRANT USAGE, SELECT ON SEQUENCES TO $NP_SERVICE_USER;
EOF
fi
{{- end -}}

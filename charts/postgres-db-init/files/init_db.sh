#!/usr/bin/env bash

set -o errexit
set -o nounset

function print_usage {
    SCRIPT_NAME="$(basename "$0")"
    echo "Usage:"
    echo "  $SCRIPT_NAME [OPTIONS]"
    echo
    echo "Options:"
    echo "  --help"
    echo "  -a, --admin-dsn DSN"
    echo "  -m, --migrations-runner-dsn DSN"
    echo "  -s, --service-dsn DSN"
    echo "  --schema SCHEMA (default: public)"
}

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

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--admin-dsn)
            ADMIN_DSN="$2"
            shift # past argument
            shift # past value
            ;;
        -m|--migrations-runner-dsn)
            MIGRATIONS_RUNNER_DSN="$2"
            shift # past argument
            shift # past value
            ;;
        -s|--service-dsn)
            SERVICE_DSN="$2"
            shift # past argument
            shift # past value
            ;;
        --schema)
            SCHEMA="$2"
            shift # past argument
            shift # past value
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)    # unknown option
            print_usage
            exit 1
            ;;
    esac
done

: ${MIGRATIONS_RUNNER_DSN:=""}
: ${SERVICE_DSN:=""}

export PGUSER="$(get_dsn_user "$ADMIN_DSN")"
export PGPASSWORD="$(get_dsn_password "$ADMIN_DSN")"
export PGHOST="$(get_dsn_host "$ADMIN_DSN")"
export PGPORT="$(get_dsn_port "$ADMIN_DSN")"
export PGDATABASE="$(get_dsn_db "$ADMIN_DSN")"

DB="$(get_dsn_db "$MIGRATIONS_RUNNER_DSN")"
SCHEMA="${SCHEMA:-"public"}"

create_db "$DB"

export PGDATABASE="$DB"

if [ ! -z "$MIGRATIONS_RUNNER_DSN" ]; then
    MIGRATIONS_RUNNER_CONN_USER="$(get_dsn_user "$MIGRATIONS_RUNNER_DSN")"
    MIGRATIONS_RUNNER_USER="${MIGRATIONS_RUNNER_CONN_USER%@*}"
    MIGRATIONS_RUNNER_USER_PASSWORD="$(get_dsn_password "$MIGRATIONS_RUNNER_DSN")"

    create_user "$DB" "$MIGRATIONS_RUNNER_USER" "$MIGRATIONS_RUNNER_USER_PASSWORD"

    psql -tA <<EOF | psql -o /dev/null -a
SELECT format(
'ALTER TABLE %I.%I OWNER TO %I;',
table_schema,
table_name,
'$MIGRATIONS_RUNNER_USER'
)
FROM information_schema.tables
WHERE table_schema = '$SCHEMA' AND table_type = 'BASE TABLE';
EOF
fi

if [ ! -z "$SERVICE_DSN" ]; then
    SERVICE_CONN_USER="$(get_dsn_user "$SERVICE_DSN")"
    SERVICE_USER="${SERVICE_CONN_USER%@*}"
    SERVICE_USER_PASSWORD="$(get_dsn_password "$SERVICE_DSN")"

    create_user "$DB" "$SERVICE_USER" "$SERVICE_USER_PASSWORD"

    psql -o /dev/null -a <<EOF
GRANT SELECT,INSERT,UPDATE,DELETE,TRUNCATE ON ALL TABLES IN SCHEMA $SCHEMA TO $SERVICE_USER;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA $SCHEMA TO $SERVICE_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA $SCHEMA GRANT SELECT,INSERT,UPDATE,DELETE,TRUNCATE ON TABLES TO $SERVICE_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA $SCHEMA GRANT USAGE, SELECT ON SEQUENCES TO $SERVICE_USER;
EOF
fi

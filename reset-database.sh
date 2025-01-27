#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

init_variables
drop_dspace_user_and_databases
setup_postgres
create_dspace_administrator

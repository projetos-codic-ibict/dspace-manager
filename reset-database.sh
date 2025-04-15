#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

init_variables
check_postgres
drop_dspace_user_and_databases
setup_postgres
create_dspace_administrator

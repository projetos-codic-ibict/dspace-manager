#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir
init_variables

"${EDITOR:-vim}" "$SCRIPT_DIR/.env"

exit

#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

init_variables
. "$SCRIPT_DIR/stop.sh"
. "$SCRIPT_DIR/start.sh"

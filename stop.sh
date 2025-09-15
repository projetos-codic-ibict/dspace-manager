#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

init_variables &&
stop_tomcat

#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

check_current_dir

. "$SCRIPT_DIR/uninstall.sh"
. "$SCRIPT_DIR/install.sh"

#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath "$0"))

. "$SCRIPT_DIR/_shared.sh"

init_variables

echo_info "Re-indexando"

if [ "$1" = "" ]; then
  "$DSPACE_INSTALLATION_DIR/bin/dspace" index-discovery -b
else
  "$DSPACE_INSTALLATION_DIR/bin/dspace" index-discovery -i "$1"
fi

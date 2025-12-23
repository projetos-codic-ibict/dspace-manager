#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

init_variables

if [ -d "$DSPACE_INSTALLATION_DIR" ] && [ ! -z "$(ls -A "$DSPACE_INSTALLATION_DIR")" ]; then
  echo "DSpace instalado? Sim"
else
  echo "DSpace instalado? Não"
fi

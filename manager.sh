#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath "$0"))

. "$SCRIPT_DIR/_shared.sh"

runner="$SCRIPT_DIR/$1.sh"

if [ -f "$runner" -a $(echo $1 | grep -v "^_") ]; then
  shift
  "$runner" "$@"
else
  echo_error "Comando inválido. Os comandos disponíveis são: install, uninstall, reinstall, build, dev, restart, start, stop, reindex, reset-database, monitor-logs"
fi

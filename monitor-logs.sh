#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

init_variables

cd "$DSPACE_INSTALLATION_DIR/log"

if [ -z "$1" ]; then
  TARGET="dspace"
else
  TARGET="$1"
fi

case "$TARGET" in
  checker ) LOGFILE_NAME="$TARGET.log.$(date +'%Y-%m-%d')";;
  cocoon ) LOGFILE_NAME="$TARGET.log.$(date +'%Y-%m-%d')";;
  dspace ) LOGFILE_NAME="$TARGET.log.$(date +'%Y-%m-%d')";;
  solr ) LOGFILE_NAME="$TARGET.log";;
  * ) echo_error "argumento inválido!"; exit 1;;
esac

if [ -f "$LOGFILE_NAME" ]; then
  tail -f "$LOGFILE_NAME" -n 0
else
  echo_error "Arquivo de log $LOGFILE_NAME não existe!"
fi

#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

init_variables

echo_info "Re-indexando"

if [ "$1" = "" ]; then
  "$DSPACE_INSTALLATION_DIR/bin/dspace" index-discovery -c >/dev/null 2>&1 &
  "$DSPACE_INSTALLATION_DIR/bin/dspace" index-discovery -f >/dev/null 2>&1 &
else
  "$DSPACE_INSTALLATION_DIR/bin/dspace" index-discovery -i "$1" >/dev/null 2>&1 &
fi

REINDEX_PID=$!

"$SCRIPT_DIR/monitor-logs.sh" &
MONITOR_PID=$!

wait $REINDEX_PID
kill $MONITOR_PID

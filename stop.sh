#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

init_variables &&
stop_tomcat && {
  if [ -z "$(echo_dspace_major_version)" ] || [ "$(echo_dspace_major_version)" -gt 6 ]; then
    stop_solr
  fi
}

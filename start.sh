#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

on_sigint() {
  . "$SCRIPT_DIR/stop.sh"
}

trap on_sigint SIGINT

init_variables
if [ -z "$JAVA_HOME" ]; then
  check_java_version
fi
if [ -z "$(echo_dspace_major_version)" ] || [ "$(echo_dspace_major_version)" -gt 6 ]; then
  start_solr
fi
start_tomcat

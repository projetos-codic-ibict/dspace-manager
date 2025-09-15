#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

on_sigint() {
  . "$SCRIPT_DIR/stop.sh"
}

trap on_sigint SIGINT

init_variables
check_java_version
start_solr
start_tomcat

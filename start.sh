#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath "$0"))

. "$SCRIPT_DIR/_shared.sh"

on_sigint() {
  . "$SCRIPT_DIR/stop.sh"
}

trap on_sigint SIGINT

init_variables
start_solr
start_tomcat

#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

remove_log_files() {
  echo_info "Removendo arquivos de log na instalação do DSpace"
  rm -f $DSPACE_INSTALLATION_DIR/log/*
}

update_installation() {
  echo_info "Atualizando instalação"
  cd "$DSPACE_SOURCE_DIR/dspace/target/dspace-installer"
  ant update
}

init_variables
. "$SCRIPT_DIR/stop.sh"
remove_target
install_maven_dependencies
remove_log_files
update_installation
remove_bak_files
add_webapps_to_tomcat

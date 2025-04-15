#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

remove_directories() {
  local dir_var_names="SOLR_DIR MAVEN_DIR TOMCAT_DIR DSPACE_INSTALLATION_DIR"

  if [ "$UNINSTALL_SHOULD_REMOVE_DSPACE_SOURCE_DIR" = "true" ]; then
    dir_var_names="$dir_var_names DSPACE_SOURCE_DIR"
  fi

  echo_info "Removendo diretórios"

  for dir_var_name in $dir_var_names; do
    eval local dir="\$$dir_var_name"

    if [ -d "$dir" ]; then
      echo_info "Removendo $dir"
      rm -rf "$dir"
    fi
  done
}

remove_dependencies() {
  local asset_var_names="SOLR_ZIP MAVEN_ZIP TOMCAT_ZIP"

  echo_info "Removendo assets"

  for asset_var_name in $asset_var_names; do
    eval local asset="\$$asset_var_name"

    if [ -e "$asset" ]; then
      echo_info "Removendo $asset"
      rm "$asset"
    fi
  done
}

init_variables
. "$SCRIPT_DIR/stop.sh"
check_postgres
drop_dspace_user_and_databases
remove_directories
if [ "$UNINSTALL_SHOULD_REMOVE_DEPENDENCIES" != false ]; then
  remove_dependencies
fi

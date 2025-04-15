#!/usr/bin/bash

SCRIPT_DIR="$(dirname $(realpath "$0"))"

. "$SCRIPT_DIR/_shared.sh"

check_current_dir

check_dir() {
  local target_dir="$1"

  echo_info "Checando diretório: $target_dir"

  if [ -e "$target_dir" -a ! -d "$target_dir" ]; then
    echo_error "Caminho $target_dir existe e não é um diretório"
    return 1
  elif [ -d "$target_dir" ]; then
    if [ ! -z "$(ls -A "$target_dir")" ]; then
      echo_warn "$target_dir não está vazio. Pulando..."
    fi
  fi

  return 0
}

extract_zip() {
  local zip_file="$1"
  local target_dir="$2"
  local temp_dir="$(mktemp -d)"

  check_dir "$target_dir" || return 1
  echo_info "Extraindo arquivo zip $zip_file"
  unzip "$zip_file" -d "$temp_dir"
  mv "$temp_dir"/* "$target_dir"
  rmdir "$temp_dir"

  return 0
}

download_asset() {
  local url="$1"
  local path="$2"

  curl -L "$url" -o "$path"

  return 0
}

download_and_or_extract_zip() {
  local download_url="$1"
  local zip_path="$2"
  local dir="$3"

  if [ ! -f "$zip_path" ]; then
    download_asset "$download_url" "$zip_path"
  fi

  extract_zip "$zip_path" "$dir" || return 1

  return 0
}

setup_requirements() {
  echo_info "Extraindo arquivos zip do Maven e Tomcat"

  if [ ! -d "$MAVEN_DIR" ]; then
    download_and_or_extract_zip "$MAVEN_ZIP_URL" "$MAVEN_ZIP" "$MAVEN_DIR" || return 1
  fi

  if [ ! -d "$TOMCAT_DIR" ]; then
    download_and_or_extract_zip "$TOMCAT_ZIP_URL" "$TOMCAT_ZIP" "$TOMCAT_DIR" || return 1
  fi

  if ( [ -z "$(echo_dspace_major_version)" ] || [ "$(echo_dspace_major_version)" -gt 6 ] ) && [ ! -d "$SOLR_DIR" ]; then
    download_and_or_extract_zip "$SOLR_ZIP_URL" "$SOLR_ZIP" "$SOLR_DIR" || return 1
  fi

  echo_info "Tornando scripts do Tomcat em executáveis"
  chmod u+x "$TOMCAT_DIR/bin"/*.sh
  check_ant
  check_java_version
  check_javac_version
}

clone_repository() {
  echo_info "Clonando repositório do DSpace"

  if [ -d "$DSPACE_SOURCE_DIR" ]; then
    if [ ! -z "$(ls -A "$DSPACE_SOURCE_DIR")" ]; then
      echo_info "$DSPACE_SOURCE_DIR não está vazio. Pulando git clone..."
      return
    fi
  fi

  if [ -z "$DSPACE_GIT_BRANCH" ]; then
    git clone "$DSPACE_GIT_REPOSITORY" "$DSPACE_SOURCE_DIR"
  else
    git clone "$DSPACE_GIT_REPOSITORY" "$DSPACE_SOURCE_DIR" -b "$DSPACE_GIT_BRANCH"
  fi

  return 0
}

edit_config_file() {
  if [ "$COPY_CONFIG_FILE" = true ]; then
    local config_template_file

    if [ -n "$CONFIG_EXAMPLE_FILE" ]; then
      config_template_file="$CONFIG_EXAMPLE_FILE"
    else
      config_template_file="$DSPACE_SOURCE_DIR/dspace/config/local.cfg.EXAMPLE"
    fi

    cp "$config_template_file" "$DSPACE_SOURCE_DIR/dspace/config/local.cfg"
  fi

  echo_info "Editando arquivo de configuração"
  echo_info "Edições necessárias:"
  echo "dspace.dir = $DSPACE_INSTALLATION_DIR"
  echo "db.url = jdbc:postgresql://localhost:5432/$DSPACE_DB_NAME"
  echo "db.username = $DSPACE_DB_USERNAME"
  echo "db.password = $DSPACE_DB_PASSWORD"
  local answer
  printf "%s" "Press enter to continue" && read answer
  "$EDITOR" "$DSPACE_SOURCE_DIR/dspace/config/local.cfg"

  return 0
}

install_dspace() {
  echo_info "Instalando o DSpace"
  mkdir -p "$DSPACE_INSTALLATION_DIR"
  cd "$DSPACE_SOURCE_DIR/dspace/target/dspace-installer"
  ant fresh_install

  return 0
}

copy_solr_cores() {
  # [solr] is the location where Solr is installed.
  # NOTE: On Debian systems the configsets may be under /var/solr/data/configsets
  cp -R "$DSPACE_INSTALLATION_DIR/solr"/* "$SOLR_DIR/server/solr/configsets"

  # Make sure everything is owned by the system user who owns Solr
  # Usually this is a 'solr' user account
  # See https://solr.apache.org/guide/8_1/taking-solr-to-production.html#create-the-solr-user
  # chown -R solr:solr [solr]/server/solr/configsets

  return 0
}

init_variables &&
setup_requirements &&
clone_repository &&
setup_postgres && {
  if [ "$EDIT_CONFIG_FILE" = true ]; then
    edit_config_file
  fi
} &&
install_maven_dependencies &&
install_dspace && {
  if [ -z "$(echo_dspace_major_version)" ] || [ "$(echo_dspace_major_version)" -gt 6 ]; then
    copy_solr_cores
  fi
} &&
remove_bak_files &&
add_webapps_to_tomcat &&
create_dspace_administrator && {
  if [ "$INSTALL_SHOULD_REINDEX" != true ]; then
    exit 0
  fi

  if [ -z "$(echo_dspace_major_version)" ] || [ "$(echo_dspace_major_version)" -gt 6 ]; then
    start_solr
  fi

  "$TOMCAT_DIR/bin/catalina.sh" start

  tail -f -n 0 "$TOMCAT_DIR/logs/catalina.$(date +"%Y-%m-%d").log" 2>/dev/null | while read -r line; do
      echo "$line"

      if echo "$line" | grep -q "Server startup in [0-9]\+ ms"; then
          break
      fi
  done

  "$SCRIPT_DIR/reindex.sh"
  "$SCRIPT_DIR/stop.sh"
}

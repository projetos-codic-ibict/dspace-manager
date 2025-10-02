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

extract_archive() {
  local archive="$1"
  local target_dir="$2"
  local temp_dir="$(mktemp -d)"

  check_dir "$target_dir" || return 1
  echo_info "Extraindo $archive"

  case "$archive" in
    *.zip)
      unzip "$archive" -d "$temp_dir"
            ;;
    *.tgz)
      tar -C "$temp_dir" -xvzf "$archive"
            ;;
    *.tar.gz)
      tar -C "$temp_dir" -xvf "$archive"
            ;;
    *)
      echo_error "Tipo de arquivo desconhecido"
      return 1
            ;;
  esac

  mv "$temp_dir"/* "$target_dir"
  rmdir "$temp_dir"

  return 0
}

download_asset() {
  local url="$1"
  local path="$2"

  if [ -n "$path" ]; then
    curl -L "$url" -o "$path"
  else
    curl -L "$url" -O
  fi

  return 0
}

handle_dep() {
  local dep_name="$1"
  local dep_name_upper="$(echo "$dep_name" | tr "[:lower:]" "[:upper:]")"
  eval local dep_dir="\$${dep_name_upper}_DIR"
  eval local dep_archive="\$${dep_name_upper}_ARCHIVE"
  eval local dep_archive_url="\$${dep_name_upper}_ARCHIVE_URL"
  local dep_archive_temp_dir

  if [ ! -d "$dep_dir" ] ; then
    if [ -z "$dep_archive_url" ]; then
      local dep_download_cmd="echo_${dep_name}_download_url"
      eval dep_archive_url="\$(${dep_download_cmd})"
    fi

    if [ -z "$dep_archive" ]; then
      dep_archive_temp_dir="$(mktemp -d "dspace-manager.XXXXXXXXXX" -p "${TMPDIR:/tmp}")"
      (cd "$dep_archive_temp_dir" && download_asset "$dep_archive_url")
      dep_archive="${dep_archive_temp_dir}/$(ls "$dep_archive_temp_dir")"
    elif [ ! -f "$dep_archive" ]; then
      download_asset "$dep_archive_url" "$dep_archive"
    fi

    extract_archive "$dep_archive" "$dep_dir" || return 1

    if [ -n "dep_archive_temp_dir" ]; then
      rm -r "$dep_archive_temp_dir"
    fi

    return 0
  fi

  return 0
}

setup_requirements() {
  echo_info "Extraindo arquivos compactados do Maven e Tomcat"

  handle_dep "maven" || return 1
  handle_dep "tomcat" || return 1
  handle_dep "solr" || return 1

  echo_info "Tornando scripts do Tomcat em executáveis"
  chmod u+x "$TOMCAT_DIR/bin"/*.sh
  check_ant
  check_postgres
  check_java_version
  check_javac_version
  check_tomcat_version
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
  export_dspace_vars
  ant -Ddspace.dir="$DSPACE_INSTALLATION_DIR" fresh_install

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
build &&
install_dspace &&
copy_solr_cores &&
remove_bak_files &&
add_webapps_to_tomcat &&
create_dspace_administrator && {
  if [ "$INSTALL_SHOULD_REINDEX" != true ]; then
    exit 0
  fi

  start_solr

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

#!/usr/bin/bash

echo_info() {
  echo "Info:" $@
}

echo_error() {
  echo "Erro:" $@ >&2
}

echo_warn() {
  echo "Aviso:" $@
}

check_current_dir() {
  if [ ! -d "$PWD" ]; then
    echo_error "O diretório atual não existe"
    exit 1
  fi
}

init_variables() {
  SCRIPT_DIR="$(dirname $(realpath "$0"))"

  . "$SCRIPT_DIR/.env"

  return 0
}

echo_java_version() {
  echo "$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')"
}

echo_java_major_version() {
  local version="$(echo_java_version)"

  if echo "$version" | grep "^1\.[1-9]\+\." >/dev/null 2>&1; then
    version="$(echo "$version" | cut -d "." -f 2)"
  else
    version="$(echo "$version" | cut -d "." -f 1)"
  fi

  echo "$version"
}

echo_javac_version() {
  echo "$(javac -version 2>&1 | awk '{print $2}')"
}

echo_javac_major_version() {
  local version="$(echo_javac_version)"

  if echo "$version" | grep "^1\.[1-9]\+\." >/dev/null 2>&1; then
    version="$(echo "$version" | cut -d "." -f 2)"
  else
    version="$(echo "$version" | cut -d "." -f 1)"
  fi

  echo "$version"
}

echo_dspace_major_version() {
  echo "$(echo "$DSPACE_VERSION" | cut -d "." -f 1)"
}

check_java_tool_version() {
  local tool="$1"
  local version_func="echo_${tool}_major_version"
  local has_update_alternatives="$(which update-alternatives >/dev/null 2>&1 && echo true || echo false)"
  local must_change_version=false

  if [ -z "$(echo_dspace_major_version)" ] || [ "$(echo_dspace_major_version)" -gt 6 ]; then
    if [ "$($version_func)" -lt 17 ]; then
      must_change_version=true
      echo_info "Você deve mudar a versão padrão do ${tool} para a versão 17 ou superior"
    fi
  else
    if [ "$($version_func)" != 8 ]; then
      must_change_version=true
      echo_info "Você deve mudar a versão padrão do ${tool} para a versão 8"
    fi
  fi

  if [ "$must_change_version" = false ]; then
    return
  fi

  if [ $has_update_alternatives ]; then
    sudo update-alternatives --config "${tool}"
  else
    exit 1
  fi
}

check_java_version() {
  check_java_tool_version "java"
}

check_javac_version() {
  check_java_tool_version "javac"
}

check_ant() {
  if ! which ant >/dev/null 2>&1; then
    echo_error "ant não foi encontrado"
    exit 1
  fi
}

check_postgres() {
  if ! sudo -iu postgres which psql >/dev/null 2>&1; then
    echo_error "psql não foi encontrado"
    exit 1
  fi
}

remove_bak_files() {
  echo_info "Removendo arquivos .bak"
  if [ -n "$DSPACE_INSTALLATION_DIR" ]; then
    rm -rf "$DSPACE_INSTALLATION_DIR/"*.bak*
  fi
}

add_webapps_to_tomcat() {
  echo_info "Adicionando webapps ao Tomcat"

  local webapps_dir="$DSPACE_INSTALLATION_DIR/webapps"
  local webapps="$(ls -Adp -1 "$webapps_dir"/* | grep "/$")"

  if [ ! -d "$TOMCAT_DIR/webapps/" ]; then
    mkdir "$TOMCAT_DIR/webapps/"
  fi

  echo "${webapps}" | while read -r webapp; do
    if [ ! -e "$TOMCAT_DIR/webapps/$(basename $webapp)" ]; then
      ln -s "$webapp" "$TOMCAT_DIR/webapps/"
    fi
  done

  # TODO: deixar isto customizável
  if [ "$(echo_dspace_major_version)" = "6" ]; then
    rm -rf "$TOMCAT_DIR/webapps/ROOT"
    ln -s "$webapps_dir/jspui" "$TOMCAT_DIR/webapps/ROOT"
  fi

  return 0
}

build() {
  cd "$DSPACE_SOURCE_DIR"
  echo_info "Instalando dependências maven"
  echo_info "Você precisa manualmente editar o arquivo de configuração do maven para para preveni-lo de bloquear http, veja: https://stackoverflow.com/a/67295342"

  export JAVA_HOME

  if [ "$(echo_dspace_major_version)" = "6" ]; then
    if [ "$1" = "clean" ]; then
      "$MAVEN_DIR/bin/mvn" clean package -P !dspace-sword,!dspace-swordv2,!dspace-oai
    else
      "$MAVEN_DIR/bin/mvn" package -P !dspace-sword,!dspace-swordv2,!dspace-oai
    fi
  else
    if [ "$1" = "clean" ]; then
      "$MAVEN_DIR/bin/mvn" clean package
    else
      "$MAVEN_DIR/bin/mvn" package
    fi
  fi

  return 0
}

stop_tomcat() {
  echo_info "Parando execução do tomcat, se já estiver rodando"
  export JAVA_HOME
  "$TOMCAT_DIR/bin/shutdown.sh" 2> /dev/null
}

stop_solr() {
  echo_info "Parando execução do solr"
  export JAVA_HOME
  "$SOLR_DIR/bin/solr" stop --all
}

start_tomcat() {
  echo_info "Iniciando execução do tomcat"
  export JAVA_HOME
  "$TOMCAT_DIR/bin/catalina.sh" run
}

start_solr() {
  echo_info "Iniciando execução do solr"

  export JAVA_HOME

  if [ -z "$(echo_dspace_major_version)" ] || [ "$(echo_dspace_major_version)" -ge 9 ]; then
    "$SOLR_DIR/bin/solr" start -Dsolr.config.lib.enabled=true
  else
    "$SOLR_DIR/bin/solr" start
  fi
}

drop_dspace_user_and_databases() {
  echo_info "Fazendo drop do usuário do DSpace e seus bancos de dados"
  sudo -iu postgres psql -c "DROP OWNED BY $DSPACE_DB_USERNAME;"
  sudo -iu postgres psql -c "DROP DATABASE $DSPACE_DB_NAME;"
  sudo -iu postgres psql -c "DROP USER $DSPACE_DB_USERNAME;"
}

setup_postgres() {
  local change_postgres_password

  echo_info "Preparando postgres"

  echo_info "Você precisa definir uma senha do postgres caso não fez ainda, senão os próximos comandos vão falhar depois de pedir a senha"
  read -p "Mudar senha do postgres? [y/N] " change_postgres_password
  case "$change_postgres_password" in
    [Yy]* ) sudo passwd postgres; break;;
  esac

  echo_info "Criando usuário postgres: $DSPACE_DB_USERNAME"
  sudo -iu postgres psql -c "create role $DSPACE_DB_USERNAME with login password '$DSPACE_DB_PASSWORD';"

  echo_info "Criando banco de dados $DSPACE_DB_NAME para o usuário $DSPACE_DB_USERNAME"
  sudo -iu postgres createdb --owner="$DSPACE_DB_USERNAME" --encoding=UNICODE "$DSPACE_DB_NAME"

  if [ -z "$(echo_dspace_major_version)" ] || [ "$(echo_dspace_major_version)" -gt 4 ]; then
    echo_info "Criando extensão pgcrypto no banco $DSPACE_DB_USERNAME"
    # BUG: Por algum motivo isso ainda deu erro de "peer authentication"
    # sudo -iu postgres psql "$DSPACE_DB_NAME" "$DSPACE_DB_USERNAME" -c "CREATE EXTENSION pgcrypto;"
    # sudo -iu postgres psql -d "$DSPACE_DB_NAME" -U "$DSPACE_DB_USERNAME" -c "CREATE EXTENSION pgcrypto;"
    sudo -iu postgres psql -d "$DSPACE_DB_NAME" -c "CREATE EXTENSION pgcrypto;"
  fi

  if [ -n "$DSPACE_DB_DUMP_FILE" ]; then
    echo_info "Importando o dump do banco de dados"

    if [ ! -f "$DSPACE_DB_DUMP_FILE" ]; then
      echo_error "$DSPACE_DB_DUMP_FILE não é um arquivo válido!"
    else
      # Importar o dump dessa forma evita o problema de "peer authentication" sem
      # ter que editar o arquivo pg_hba.conf. https://stackoverflow.com/a/66664893
      sudo -iu postgres psql "postgresql://$DSPACE_DB_USERNAME:$DSPACE_DB_PASSWORD@localhost:5432/$DSPACE_DB_NAME" < "$DSPACE_DB_DUMP_FILE"
    fi
  fi

  return 0
}

create_dspace_administrator() {
  echo_info "Criando administrador do DSpace"
  "$DSPACE_INSTALLATION_DIR/bin/dspace" create-administrator \
    --email "$DSPACE_ADMIN_EMAIL" \
    --first "$DSPACE_ADMIN_FIRST_NAME" \
    --last "$DSPACE_ADMIN_LAST_NAME" \
    --language "$DSPACE_ADMIN_LANGUAGE" \
    --password "$DSPACE_ADMIN_PASSWORD"

  return 0
}

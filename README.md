# DSpace Manager

Este repositório contém scripts para facilitar o desenvolvimento de projetos
baseados em DSpace.

## Configuração

Você deve criar um arquivo de configuração chamado `.env` na raíz deste
diretório. Veja o arquivo [.env.EXAMPLE](./.env.EXAMPLE) para conhecer as
configurações possíveis.

## Como usar

O script entrypoint é o [manager.sh](./manager.sh), você pode rodar qualquer um
dos outros scripts a partir dele, por exemplo:

```sh
# roda o ./uninstall.sh
$ ./manager.sh uninstall

# roda o ./install.sh
$ ./manager.sh install
```

Dica: você pode criar um link simbólico para não precisar executar o manager.sh
a partir do diretório deste projeto, por exemplo:

```sh
# Rode isso no diretório deste projeto, ou substitua $PWD pelo diretório correto.
sudo ln -s $PWD/manager.sh /usr/local/bin/dm
```

Isso te permite rodar os scripts simplesmente usando `dm uninstall`, `dm
install`, etc... a partir de qualquer diretório.

## Funcionalidades

- `install`: Instala o DSpace.
- `uninstall`: Desinstala o DSpace.
- `build`: Faz (ou refaz) o build do DSpace a partir do código fonte.
- `dev`: Equivalente a rodar `stop -> build -> start`.
- `manager`: Entrypoint para os outros scripts.
- `monitor-logs`: Monitora os logs no terminal. Por padrão monitora logs do
  DSpace, mas você pode passar um argumento para qualquer tipo de log em
  [dspace-installation]/log, por exemplo: `./manager.sh monitor-logs solr` para
  monitorar logs do solr.
- `reindex`: Re-indexa todos os itens do sistema. Você pode passar um handle como
  argumento para re-indexar somente o item que tem esse handle.
- `reinstall`: Equivalente a rodar `uninstall -> install`.
- `reset-database`: Apaga o banco de dados e cria de novo, incluindo o usuário administrador.
- `restart`: Equivalente a rodar `stop -> start`.
- `start`: Inicia o sistema (requer instalação e build para funcionar).
- `stop`: Interrompe a execução do sistema se estiver rodando no momento.

## Compatibilidade

Os scripts foram testados com as versões 6, 7 e 8 do DSpace.

### Utilizando com a versão 6

Edite o arquivo `pom.xml` com a seguinte alteração:
```diff
@@ -1609,9 +1609,8 @@
         </repository>
         <!-- Add mirror for restlet - maven-default-http-blocker fix -->
         <repository>
-            <id>maven-restlet</id>
-            <name>Public online Restlet repository</name>
-            <url>https://maven.restlet.com</url>
+            <id>restlet-mirror</id>
+            <url>https://maven.restlet.talend.com</url>
         </repository>
     </repositories>
```

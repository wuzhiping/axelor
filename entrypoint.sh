#!/bin/bash
set -e

APP_USER=admin
APP_PASS=admin

PG_USER=axelor
PG_PASS=axelor
PG_DATABASE_NAME=axelor

APP_LANGUAGE="${APP_LANGUAGE:-en}"
APP_DEMO_DATA="${APP_DEMO_DATA:-true}"
APP_LOAD_APPS="${APP_LOAD_APPS:-true}"
DEV_MODE="${DEV_MODE:-false}"

APP_DATA_BASE_DIR="/app/data"
APP_DATA_EXPORTS_DIR="${APP_DATA_EXPORTS_DIR:-$APP_DATA_BASE_DIR/exports}"
APP_DATA_ATTACHMENTS_DIR="${APP_DATA_ATTACHMENTS_DIR:-$APP_DATA_BASE_DIR/attachments}"

PG_HOME="/var/lib/postgresql"
PG_DATADIR=${PG_HOME}/${PG_VERSION}/main

mkdir -p {$APP_DATA_EXPORTS_DIR,$APP_DATA_ATTACHMENTS_DIR}

# Start postgres
start_postgres() {
  find ${PG_DATADIR} -type f -exec chmod 0600 {} \;
  find ${PG_DATADIR} -type d -exec chmod 0700 {} \;
  chown -R postgres:postgres ${PG_HOME}

  service postgresql start
}

# Initialize tomcat
init_tomcat() {
  echo "Configuring app:tomcat"

  local TOMCAT_ENV_PATH=${CATALINA_HOME}/bin/setenv.sh
  local TOMCAT_SERVER_PATH=${CATALINA_HOME}/conf/server.xml

  # Add setenv.sh
  cat > ${TOMCAT_ENV_PATH} <<EOF
export CATALINA_PID="\$CATALINA_BASE/tomcat.pid"
export JAVA_OPTS="\$JAVA_OPTS -Xmx2048m -server"
EOF

  # Remove localhost_access_log
  sed -i -E ':a;N;$!ba;s/<Valve className=\"org.apache.catalina.valves.AccessLogValve\"(.|\n)*\/>//' $TOMCAT_SERVER_PATH
}

# Initialize database
init_postgres() {
  echo "Configuring app:database"

  # Create db user if not exist
  if [[ -z $(gosu postgres psql -Atc "SELECT 1 FROM pg_catalog.pg_user WHERE usename = '${PG_USER}'";) ]]; then
    gosu postgres psql --command "CREATE USER ${PG_USER} WITH SUPERUSER PASSWORD '${PG_PASS}'" >/dev/null
  fi

  # Create database and unnaccent extension if not exist
  if [[ -z $(gosu postgres psql -Atc "SELECT 1 FROM pg_catalog.pg_database WHERE datname = '${PG_DATABASE_NAME}'";) ]]; then
    gosu postgres psql --command "CREATE DATABASE ${PG_DATABASE_NAME} WITH OWNER '${PG_USER}'" >/dev/null
    gosu postgres psql --command "CREATE EXTENSION IF NOT EXISTS unaccent" >/dev/null
  fi
}

# Update app properties
update_properties() {
  echo "Configuring app:properties"

  local APP_PROP_FILE_PATH="${CATALINA_HOME}/application.properties"
  #local APP_PROP_FILE_PATH="${CATALINA_HOME}/webapps/ROOT/WEB-INF/classes/application.properties"
  local APP_MODE="prod"
  local LOG_LEVEL="INFO"
  if [[ ${DEV_MODE} == true ]]; then
    APP_MODE="dev"
    LOG_LEVEL="DEBUG"
  fi

  findAndReplace "db.default.dialect" "org.hibernate.dialect.PostgreSQLDialect" ${APP_PROP_FILE_PATH}
  findAndReplace "db.default.driver" "org.postgresql.Driver" ${APP_PROP_FILE_PATH}
  findAndReplace "db.default.ddl" "update" ${APP_PROP_FILE_PATH}
  findAndReplace "db.default.url" "jdbc:postgresql://localhost:5432/$PG_DATABASE_NAME" ${APP_PROP_FILE_PATH}
  findAndReplace "db.default.user" "${PG_USER}" ${APP_PROP_FILE_PATH}
  findAndReplace "db.default.password" "${PG_PASS}" ${APP_PROP_FILE_PATH}
  findAndReplace "file.upload.dir" "${APP_DATA_ATTACHMENTS_DIR}" ${APP_PROP_FILE_PATH}
  findAndReplace "data.export.dir" "${APP_DATA_EXPORTS_DIR}" ${APP_PROP_FILE_PATH}
  findAndReplace "application.mode" "${APP_MODE}" ${APP_PROP_FILE_PATH}
  findAndReplace "quartz.enable" "false" ${APP_PROP_FILE_PATH}
  findAndReplace "data.import.demo-data" "${APP_DEMO_DATA}" ${APP_PROP_FILE_PATH}
  findAndReplace "temp.dir" "{java.io.tmpdir}" ${APP_PROP_FILE_PATH}
  findAndReplace "logging.level.com.axelor" "${LOG_LEVEL}" ${APP_PROP_FILE_PATH}
  findAndReplace "hibernate.search.default.directory_provider" "none" ${APP_PROP_FILE_PATH}
  findAndReplace "hibernate.hikari.minimumIdle" "1" ${APP_PROP_FILE_PATH}
  findAndReplace "hibernate.hikari.maximumPoolSize" "10" ${APP_PROP_FILE_PATH}
}

# Start Tomcat
start_tomcat() {
  echo "Initializing app... please wait"

  #${CATALINA_HOME}/bin/catalina.sh start >/dev/null &
  ${CATALINA_HOME}/bin/catalina.sh start &

  if [[ ${DEV_MODE} == true ]]; then
    sleep 2 # Wait tomcat.pid to be written
    tail --pid $(cat ${CATALINA_HOME}/tomcat.pid) -F ${CATALINA_HOME}/logs/catalina.out &
  fi

  sleep 5

  check_tomcat_app_available
}

# Run Tomcat in foreground
run_tomcat() {
  echo "Starting app..."

  ${CATALINA_HOME}/bin/catalina.sh run
}

# Stop Tomcat
stop_tomcat() {
  echo "Stopping app..."

  ${CATALINA_HOME}/bin/catalina.sh stop 15 -force >/dev/null
  sleep 5
}

# Install all apps
install_apps() {
  if [[ ${APP_LOAD_APPS} == true ]]; then

    echo "Loading demo data... please wait"

    # Login
    curl -sS --cookie-jar /tmp/cookies.txt -X POST -H "Content-Type:application/json" \
      -d '{"username":"'"${APP_USER}"'","password":"'"${APP_PASS}"'"}' \
      http://localhost:8080/callback

    # Get all apps with id and version
    local APPS=$(curl -sS --cookie /tmp/cookies.txt -X GET -H "Content-Type: application/json" \
      http://localhost:8080/ws/rest/com.axelor.apps.base.db.App | jq '[.data[] | {id: .id, version: .version}]')

    local DATA=$(cat <<EOF
{"action": "action-app-method-bulk-install",
  "data": {
    "context": {
    "languageSelect": "${APP_LANGUAGE}",
    "importDemoData": ${APP_DEMO_DATA},
    "_model": "com.axelor.apps.base.db.App",
    "appsSet": ${APPS}
  }
},
"model": "com.axelor.apps.base.db.App"}
EOF
)

    # Execute action
    curl -sS --cookie /tmp/cookies.txt --max-time 1800 -X POST -H "Content-Type: application/json" \
      -d ''"${DATA}"'' \
      http://localhost:8080/ws/action >/dev/null

    rm /tmp/cookies.txt

  fi
}

# Wait until app is started and available
check_tomcat_app_available() {
  local counter=0
  local command="curl --silent --show-error --connect-timeout 1 -I http://localhost:8080/ | grep '/login.jsp'"
  until [ "`eval ${command}`" != "" ] || [ "${counter}" -gt 30 ];
  do
    sleep 20
    counter=$((counter+1))
  done

  local finalCheck="curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/login.jsp"
  if [[ $(${finalCheck}) != 200 ]]; then
    echo
     echo "ERROR: "
     echo "  Unable to fetch login.jsp."
     echo "  Seems app has not starting or still loading."
     echo "  Aborting..."
     echo
   exit 1
  fi
}

# Update a property
findAndReplace() {
  local PROP=$1
  local VALUE=$2
  local FILE=$3

  if grep -q "${PROP}" ${FILE}; then
    sed -i "s/^${PROP}.*/${PROP} = $(echo "${VALUE}" | sed 's/\//\\\//g')/" ${FILE}
  else
    echo -e "\n${PROP} = ${VALUE}" >> ${FILE}
  fi
}

if [ "$1" = "start" ]; then
	shift

  update_properties
  start_postgres

  if [[ ! -f ${PG_DATADIR}/.first_start_completed ]]; then
    init_postgres
    init_tomcat
    start_tomcat
    install_apps
    stop_tomcat
    touch ${PG_DATADIR}/.first_start_completed
  fi

	run_tomcat
fi

exec "$@"

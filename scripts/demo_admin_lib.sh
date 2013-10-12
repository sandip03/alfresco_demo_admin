#!/bin/bash
# Start services that are required to run an Alfresco Demo

PGHBA_PATH="/var/lib/pgsql/data/pg_hba.conf"
POSTGRES_INIT="postgresql.service"
ALFS_DIR="/opt"
USER="richard" # used to chown so we don't have to be root all the time


# Database commands need to be run as user postgres
function su_postgres {
  CMD=$1
  sudo su - postgres -c "${CMD}"
}

function run_psql_cmd {
  CMD=$1
  su_postgres "psql -c \"${CMD}\""
}

function check_psql_for_project {
  CMD=$1
  PROJECT_NAME=$2
  run_psql_cmd "${CMD}" | grep " ${PROJECT_NAME} "
}

function start_postgres_if_needed {
  echo "Making sure that PostgreSQL is running . . ."
  if ! sudo systemctl status $POSTGRES_INIT | grep running; then
    sudo systemctl start $POSTGRES_INIT
  fi
}

function setup_database_user {
  PROJECT_NAME=$1
  # could use "select * from pg_user"
  if ! check_psql_for_project "\\du" ${PROJECT_NAME}; then
    echo "Creating user"
    su_postgres "createuser -S -D -R ${PROJECT_NAME}"
    run_psql_cmd "alter user ${PROJECT_NAME} with password '${PROJECT_NAME}';"
  else
    echo "Database user exists"
  fi
}

function setup_database_db {
  PROJECT_NAME=$1
  createdb=false
  if ! check_psql_for_project "\\l" ${PROJECT_NAME}; then
    echo "Creating database"
    su_postgres "createdb ${PROJECT_NAME} -O ${PROJECT_NAME}"
    createdb=true
  else
    echo "Database exists"
  fi

  if ! su_postgres "grep \" ${PROJECT_NAME} \" ${PGHBA_PATH}"; then
    echo "Adding to pg_hba.conf"
    # I can't get this to only affect the first occurance, so watch out for
    # multiple "Alfresco_Demos" in the file.
    sudo sed -i "/Alfresco_Demos/a \
# For ${PROJECT_NAME} \\
local  ${PROJECT_NAME}       ${PROJECT_NAME}                                    md5"\
      ${PGHBA_PATH}
    sudo systemctl reload $POSTGRES_INIT
  else
    echo "pg_hba.conf already has ${PROJECT_NAME} info"
  fi

  if $createdb; then
    return 0 # 0=true--db was created
  else
    return 1
  fi
}

function setup_database {
  PROJECT_NAME=$1
  echo "Setting up Database . . ."
  setup_database_user ${PROJECT_NAME}
  if setup_database_db ${PROJECT_NAME}; then
    return 0 # 0=true--db was created
  else
    return 1
  fi
} 

function cleanup_database {
  PROJECT_NAME=$1
  echo "Cleaning up Database . . ."
  echo "Dropping database"
  su_postgres "dropdb ${PROJECT_NAME}"

  echo "Dropping user"
  su_postgres "dropuser ${PROJECT_NAME}"

  echo "Cleaning pg_hba.conf"
  sudo sed -i /\ ${PROJECT_NAME}\ /d ${PGHBA_PATH}
  sudo systemctl reload $POSTGRES_INIT
}


function extract_war {
  WAR_FILE=$1
  WAR_NAME=`basename ${WAR_FILE}`
  WAR_NAME=${WAR_NAME%%.*}
  WAR_DIR=`dirname ${WAR_FILE}`/${WAR_NAME}

  mkdir ${WAR_DIR}
  old_dir=`pwd`
  cd ${WAR_DIR}
  jar -xf ${WAR_FILE}
  cd ${old_dir}
}


function copy_if_exists {
  FILE=$1
  DEST=$2
  if [ -e "${FILE}" ]; then
    cp "${FILE}" "${DEST}"
  else echo "No ${FILE} to copy."
  fi
}


function exit_if_alf_running {
  # Check that Alfresco isn't running
  if ps aux | grep alfresco | grep -v grep > /dev/null; then
    echo "It looks like Alfresco is running . . . "
    exit
  fi
}

function backup_demo_data {
  PROJECT_NAME=$1
  ALF_RELEASE_DIR=$2
  ALF_DIR=$3
  ALF_DEMO_DATA="${ALF_RELEASE_DIR}/demo_data-${PROJECT_NAME}"
  ALF_DEMO_DB_DUMP="${ALF_RELEASE_DIR}/demo_db/${PROJECT_NAME}.psql"

  exit_if_alf_running
  confirm_cleanup_or_exit ${PROJECT_NAME}

  echo "Backing up demo project . . ."
  echo PROJECT_NAME=${PROJECT_NAME}
  echo ALF_DIR=${ALF_DIR}
  echo
  echo "Backing up database"
  rm ${ALF_DEMO_DB_DUMP}
  # Wrap pg_dump with expect to supply password
  expect -c "spawn pg_dump -U ${PROJECT_NAME} ${PROJECT_NAME}; match_max 1000; expect '*? assword:*'; send -- ${PROJECT_NAME}\r; expect eof" > ${ALF_DEMO_DB_DUMP}.tmp
  # Remove expect output from top of file
  tail -n +3  ${ALF_DEMO_DB_DUMP}.tmp > ${ALF_DEMO_DB_DUMP}
  rm ${ALF_DEMO_DB_DUMP}.tmp

  echo "Backing up content"
  rm -r ${ALF_DEMO_DATA}
  mkdir ${ALF_DEMO_DATA}
  sudo cp -pr ${ALF_DIR}/alf_data/* ${ALF_DEMO_DATA}
  sudo chown -R ${USER} ${ALF_DEMO_DATA}
}

function populate_demo_data {
  ## Right now this is done by loading in a known state from a backup
  ## Better would be to create a database and load an AMP+ACP

  PROJECT_NAME=$1
  ALF_RELEASE_DIR=$2
  ALF_DIR=$3
  ALF_DEMO_DATA="${ALF_RELEASE_DIR}/demo_data-${PROJECT_NAME}"
  ALF_DEMO_DB_DUMP="${ALF_RELEASE_DIR}/demo_db/${PROJECT_NAME}.psql"

  if [ -d ${ALF_DEMO_DATA} ] && [ -f ${ALF_DEMO_DB_DUMP} ]; then
    echo "Copying in data"
    # The installer sometimes creates the data directory
    if [ -d ${ALF_DIR}/alf_data ]; then
      rm -rf ${ALF_DIR}/alf_data
    fi
    cp -pr ${ALF_DEMO_DATA} ${ALF_DIR}/alf_data

    echo "Populating database"
    # TODO--I can't get expect to send the password
    # Wrap pg_restore with expect to supply password
#    expect -c "spawn psql -U ${PROJECT_NAME} -f ${ALF_DEMO_DB_DUMP} ${PROJECT_NAME}; match_max 1000; expect '*assword*:'; send -- '${PROJECT_NAME}\r'; expect eof"
    echo "Password is ${PROJECT_NAME}"
    psql -U ${PROJECT_NAME} -f ${ALF_DEMO_DB_DUMP} ${PROJECT_NAME}
  else
    echo "Missing data to restore."
  fi
}


function start_alfresco {
  PROJECT_NAME=$1
  ALF_DIR="${ALFS_DIR}/${PROJECT_NAME}"
  echo "Starting Alfresco . . ."
  if ps aux | grep alfresco | grep -v grep > /dev/null; then
    echo "It looks like Alfresco is already running . . . "
    exit
  fi

  old_dir=`pwd`
  cd ${ALF_DIR}
  sudo ${ALF_DIR}/alfresco.sh start
  cd ${old_dir}
}


function setup_demo {
  # Setup a standard environment for demos of Alfresco DM / Share
  PROJECT_NAME=$1
  ALF_RELEASE_DIR=$2
  ALF_INSTALLER_NAME=$3
  INSTALL_OPT_FILE_NAME=$4
  LICENSE_FILE_NAME=$5

  ALF_DEMO_CONFIGS="${ALF_RELEASE_DIR}/demo_confs"
  ALF_DIR="${ALFS_DIR}/${PROJECT_NAME}"
  INSTALLER="${ALF_RELEASE_DIR}/${ALF_INSTALLER_NAME}"
  INSTALL_OPT_FILE="${ALF_RELEASE_DIR}/${INSTALL_OPT_FILE_NAME}"
  LICENSE_FILE="${ALF_RELEASE_DIR}/${LICENSE_FILE_NAME}"

  # Make sure everything is ready for setup 
  exit_if_alf_running
  start_postgres_if_needed

  if setup_database ${PROJECT_NAME}; then
    db_created=true
  else
    db_created=false
  fi

  echo "Setting up the Alfresco demo directory . . ."

  dir_created=false
  if ! [ -d "${ALF_DIR}" ]; then
    echo "Creating clean Alfresco directory"
    dir_created=true
    sudo mkdir -p "${ALF_DIR}"
    sudo chown -R ${USER} "${ALF_DIR}"
    # Lay down the application
    echo "Running BitRock installer"
    #  Prep the option file
    temp_install_opts=/tmp/alf_temp_install_options
    cp -i "${INSTALL_OPT_FILE}" "${temp_install_opts}"
    sed -i "s/alfresco_demo/${PROJECT_NAME}/" "${temp_install_opts}"
    #  Use the BitRock installer with an option file
    set +e # early verisons of the bitrock installer generates inocuous errors
    ${INSTALLER} --optionfile ${temp_install_opts}
    set -e
    #  Clean up
    rm ${temp_install_opts}
    rm /tmp/bitrock*
    echo "Copying in config files"
#    ln -s /usr/share/java/postgresql-jdbc3-8.4.jar ${ALF_DIR}/tomcat/lib
    copy_if_exists "${ALF_DEMO_CONFIGS}/alfresco.sh" "${ALF_DIR}"
    copy_if_exists "${ALF_DEMO_CONFIGS}/alfresco-global.properties" "${ALF_DIR}/tomcat/shared/classes/"
    sed -i "s/alfresco_demo/${PROJECT_NAME}/" "${ALF_DIR}/tomcat/shared/classes/alfresco-global.properties"
    copy_if_exists "${ALF_DEMO_CONFIGS}/share-config-custom.xml" "${ALF_DIR}/tomcat/shared/classes/alfresco/web-extension"
    if [ -f "${LICENSE_FILE}" ]; then
      echo "Installing license"
      mkdir "${ALF_DIR}/tomcat/shared/classes/alfresco/extension/license"
      cp "${LICENSE_FILE}" "${ALF_DIR}/tomcat/shared/classes/alfresco/extension/license"
    else echo "License file ${LICENSE_FILE} missing."
    fi
  else
    echo "Alfresco directory exists"
  fi

  if $db_created && $dir_created; then
    populate_demo_data ${PROJECT_NAME} ${ALF_RELEASE_DIR} ${ALF_DIR}
  fi
}


function confirm_cleanup_or_exit {
  # Cleanup everything related to an Alfresco Demo
  PROJECT_NAME=$1
  ALF_DIR="${ALFS_DIR}/${PROJECT_NAME}"

  echo PROJECT_NAME=${PROJECT_NAME}
  echo ALF_DIR=${ALF_DIR}
  echo
  echo "We will now delete all information in the above listed database."
  echo "Are you sure you want to do this? Type \"yes\" to proceed."
 
  read confirmation

  if ! [ "$confirmation" == "yes" ]; then
    exit
  fi
}

function cleanup_demo {
  # Cleanup everything related to an Alfresco Demo
  # Alternative method is to call the BitRock uninstaller
  #   but since we don't let BitRock install anything outside of /opt,
  #   we can just clean it up manually
  PROJECT_NAME=$1

  # Make sure everything is ready for cleanup
  exit_if_alf_running
  confirm_cleanup_or_exit ${PROJECT_NAME}
  start_postgres_if_needed

  cleanup_database ${PROJECT_NAME}

  echo "Deleting directory"
  sudo rm -rf ${ALF_DIR}
}

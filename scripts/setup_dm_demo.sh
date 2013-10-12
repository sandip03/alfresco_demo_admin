#!/bin/bash
# Setup a standard environment for Alfresco demos
# Right now this is done by loading in a known state from a backup
# Better would be to create a database and load an AMP+ACP

PROJECT_NAME="alfresco_demo"

ALF_RELEASE_DIR="../releases/4.2.d"
ALF_INSTALLER_NAME="alfresco-community-4.2.d-installer-linux-x64.bin"
INSTALL_OPT_FILE_NAME="install_opts"
LICENSE_FILE_NAME="" # License file isn't needed for community edition

. ./demo_admin_lib.sh

set -e

setup_demo "${PROJECT_NAME}" "${ALF_RELEASE_DIR}" "${ALF_INSTALLER_NAME}" \
           "${INSTALL_OPT_FILE_NAME}" "${LICENSE_FILE_NAME}"

echo "All Done"

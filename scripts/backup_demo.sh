#!/bin/bash
# Backup the data from the alfresco_demo

PROJECT_NAME="alfresco_demo"
ALF_RELEASE_DIR="../releases/4.2.d"
ALF_DIR="/opt/${PROJECT_NAME}"

. ./demo_admin_lib.sh

backup_demo_data "${PROJECT_NAME}" "${ALF_RELEASE_DIR}" "${ALF_DIR}"

echo "All Done"

#!/bin/bash
# Start services that are required to run an Alfresco Demo

ALF_NAME="alfresco_demo"

. ./demo_admin_lib.sh

start_postgres_if_needed

start_alfresco $ALF_NAME

tail -f /opt/${ALF_NAME}/tomcat/logs/catalina.out

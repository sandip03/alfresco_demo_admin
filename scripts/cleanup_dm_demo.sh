#!/bin/bash
# Cleanup everything related to an Alfresco Demo

PROJECT_NAME="alfresco_demo"

. ./demo_admin_lib.sh

set -e

cleanup_demo "${PROJECT_NAME}"

echo "All Done"

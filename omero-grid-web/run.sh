#!/bin/bash

set -eu

if [ $# -gt 0 ]; then
    echo "ERROR: Expected 0 args"
    exit 2
fi

omero=/home/omero/OMERO.server/bin/omero

MASTER_ADDR=${MASTER_ADDR:-}
if [ -z "$MASTER_ADDR" ]; then
    MASTER_ADDR=${MASTER_PORT_4064_TCP_ADDR:-}
fi
if [ -n "$MASTER_ADDR" ]; then
    $omero config set omero.web.server_list "[[\"$MASTER_ADDR\", 4064, \"omero\"]]"
else
    echo "WARNING: Master address not found"
    # Assume it'll be set in /config/*
fi

if stat -t /config/* > /dev/null 2>&1; then
    for f in /config/*; do
        echo "Loading $f"
        $omero load "$f"
    done
fi

mkdir -p /home/omero/nginx/cache /home/omero/nginx/log /home/omero/nginx/temp
NGINX_OMERO=/etc/nginx/conf.d/omero-web.conf
if [ ! -f $NGINX_OMERO ]; then
    echo "Creating $NGINX_OMERO"
    $omero web config --http 8080 nginx > $NGINX_OMERO
fi

echo "Add the figure app to OMERO.web"
$omero   config append omero.web.apps '"omero_figure"'

echo "Display a link to 'Figure' at the top of the webclient"
$omero config append omero.web.ui.top_links '["Figure", "figure_index", {"title": "Open Figure in new tab", "target": "_blank"}]'

echo  "Add 'Figure' to the 'Open with' options, available from context menu on the webclient tree"
$omero  config append omero.web.open_with '["omero_figure", "new_figure", {"supported_objects":["images"], "target": "_blank", "label": "OMERO.figure"}]'

echo "Disable Version Checking from Omero Server"
$omero config set omero.web.check_version false

echo "Starting OMERO.web"
$omero web start
echo "Starting nginx"
exec nginx -g "daemon off;" -c /etc/nginx/nginx.conf

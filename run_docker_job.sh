#!/bin/bash

if [ -n "$1" ]; then
docker run --rm --network host  -v /home/stgwe/etl:/home/stgwe/etl  --env-file /home/stgwe/.env-pdi -e TZ="America/Chicago" filemover:latest "$1"
else
exit 1
fi

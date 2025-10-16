#!/bin/bash
if [ -z "$1" ]; then set -- /app/bin/server "$@"; fi
exec "$@"
